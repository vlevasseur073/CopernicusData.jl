module YAXTrees

export YAXTree, open_datatree, map_over_subtrees, add_children!

using YAXArrays, Zarr
using Dagger
using JSON3
using Mmap
# using Graphs, GraphPlot, Colors
import ..CopernicusData: get_AWS_config, s3_get_object, NotImplementedError


mutable struct YAXTree
    name::String
    path::String
    properties::Dict{String, Any}
    parent::Union{Nothing, YAXTree}
    children::Dict{String, YAXTree}
    data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}
end

function Base.getindex(tree::YAXTree,path::String)::YAXTree
    return tree.children[path]
end

function Base.getproperty(tree::YAXTree, name::Symbol)
    if hasfield(YAXTree, name)
        return getfield(tree, name)
    elseif haskey(tree.children, String(name))
        return tree.children[String(name)]
    elseif hasproperty(tree.data, name)
        return getproperty(tree.data,name)
    elseif name == :scalar
        return tree.data[1]
    else
        throw(KeyError("No child name '$name'"))
    end
end

function Base.setproperty!(tree::YAXTree, name::Symbol, value)
    if hasfield(YAXTree, name)
        setfield!(tree, name, value)
    elseif isa(value, YAXTree)
        tree.children[String(name)] = value
        tree.children[String(name)].path = joinpath(tree.path, String(name))
        tree.children[String(name)].parent = tree
    elseif isa(value, AbstractArray)
        tree.children[String(name)] =  YAXTree(
                                                String(name),
                                                joinpath(tree.path, String(name)),
                                                Dict(),
                                                tree,
                                                Dict(),
                                                value
                                            )
    else
        throw(ArgumentError("Can only assign a YAXTree to a child node"))
    end
end

function YAXTree()
    YAXTree("root",".",Dict(),nothing,Dict(),nothing)
end

function YAXTree(name::String;parent=nothing,data=nothing)
    path=""
    properties=Dict()
    parent=parent
    children=Dict()
    data=data
    YAXTree(name,path,properties,parent,children,data)
end

function YAXTree(zgroup::ZGroup)
    tree = YAXTree()
    iter_groups!(tree,zgroup)
    tree.properties = zgroup.attrs
    return tree
end

function add_children!(tree::YAXTree,name::Union{String,Symbol},data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}=nothing)
    if length(split(name,"/")) > 1
        @error "The name of a tree node could not contains '/' " name
        throw(ArgumentError("The name of a tree node could not contains '/': $name "))
    end

    if haskey(tree.children,name)
        @error "$name already exists in tree"
        throw(ArgumentError("$name already exists in tree"))
    end

    current = tree
    if isnothing(data)
        properties = Dict()
    else
        properties = data.properties
    end
    current.children[name] = YAXTree(name, joinpath(current.path,name), properties, current, Dict(), data)
end

function add_children_full_path!(tree::YAXTree, path::String, data::YAXArray)
    parts = split(path,"/")
    current = tree
    for p in parts
        if !haskey(current.children,p)
            current.children[p] = YAXTree(p, joinpath(current.path,p), data.properties, current, Dict(), data)
        end
        current = current.children[p]
    end
end

"""
    open_datatree(path::String, driver::Union{Nothing,Symbol}=nothing; name::String="root")::YAXTree

Open a Copernicus product
returns YAXTree


# Examples
```julia-repl
julia> dt = open_datatree("S03SLSLST_20191227T124111_0179_A109_T921.zarr")
```
"""
function open_datatree(path::String, driver::Union{Nothing,Symbol}=nothing;name::String="root")::YAXTree
    tmp_path, ext = splitext(rstrip(path,'/'))
    archive = false
    if ext == ".zip"
        nozip_path = tmp_path
        archive = true
    else
        nozip_path = path
    end

    -, ext = splitext(rstrip(nozip_path,'/'))
    if isnothing(driver)
        if ext == ".zarr" || ext == ".zarr"
            driver = :zarr
        elseif ext == ".SEN3"
            driver = :sen3
        elseif ext == ".json"
            driver = :json
        else
            @error "Cannot find backend with extension. Available backends are ['.zarr','.SEN3']"
            throw(Exception)
        end
    end
    if driver == :zarr
        return open_zarr_datatree(path,name=name, archive=archive)
    elseif driver == :sen3
        return open_sen3_datatree(path)
    elseif driver == :json
        return open_json_datatree(path,name=name)
    else
        @error "Driver $driver is not implemented. Available backends are [:zarr,:sen3]"
        throw(Exception)
    end
end

function iter_groups!(tree::YAXTree, z::ZGroup; remove_zarr_path=false)
    if !remove_zarr_path
        zgroup_name = splitpath(z.path)[end]
    else 
        zgroup_name = ""
    end
    current = tree
    if !isempty(z.arrays)
        for arr in z.arrays
            zdata = arr.second
            if haskey(zdata.attrs,"fill_value")
                zdata.attrs["missing_value"] = zdata.attrs["fill_value"]
            else
                zdata.attrs["missing_value"] = zdata.metadata.fill_value
            end
        end
        ds = Dataset()
        try
            ds = open_dataset(z)
        catch e
            @warn e
            @warn "Problem encountered for dataset $zgroup_name"
            @warn z
        else
            @debug "Add Datasets in " zgroup_name
            if isempty(zgroup_name)
                tree.data = ds
            else
                add_children!(tree,zgroup_name,ds)
            end
        end
    else
        if !isempty(zgroup_name)
            @debug "Add Group " zgroup_name
            add_children!(tree,zgroup_name)
            current = tree[zgroup_name]
        end
    end
    for g in z.groups
        if isa(g.second,ZGroup)
            if isempty(zgroup_name)
                current = tree
            else
                @debug "Add Group " zgroup_name
                # add_children!(tree,zgroup_name)
                current = tree[zgroup_name]
            end
            iter_groups!(current,g.second)
        end
    end
end


function open_zarr_datatree(path::String;name::String="root", archive::Bool=false)::YAXTree
    # Check path exist
    if !startswith(path,"s3://") && !isdir(path) && (!isfile(path) || !archive)
        @error "Product Path does not exist ", path
        throw(Exception)
    end
    
    remove_zarr_path = false
    if startswith(path, "s3://")
        remove_zarr_path = true
    end
    if archive
        zprod = zopen(Zarr.ZipStore(mmap(path)), consolidated=true)
    else
        zprod = zopen(path, consolidated=true)
    end
    
    tree = YAXTree(name)
    iter_groups!(tree, zprod;remove_zarr_path=remove_zarr_path)
    tree.properties = zprod.attrs
    
    return tree
end


function from_dict(data)::YAXTree
    function _build_tree(root, data)
        for (k,v) in data
            if isa(k,Symbol)
                k = String(k)
            end
            if v isa String 
                root.properties[k] = v
            elseif v isa Number
                # add_children!(root,"scalar",YAXArray(Array{typeof(v)}([v])))
                root.data=YAXArray(Array{typeof(v)}([v]))
            elseif v isa AbstractDict
                # @info "New node: $k"
                add_children!(root, k)
                _build_tree(root[k],v)
            elseif v isa AbstractArray
                @info "New array: $k"
                add_children!(root, k, YAXArray(v))
            end
        end
        return root
    end

    root=YAXTree()
    _build_tree(root, data)
    return root

end
function open_json_datatree(path::String;name::String="root")::YAXTree
    # Check if path exist
    if !startswith(path,"s3://") && !isfile(path)
        @error "Product Path does not exist ", path
        throw(Exception)
    end

    if startswith(path, "s3://")
        json = s3_get_object(path)
    else
        json = JSON3.read(read(path,String))
    end

    return from_dict(json)

end

function open_sen3_datatree(path)
    throw(NotImplementedError("This feature will be implemented in the future."))
end

# Iterator state:  Keeps track of the current node and the order of visiting
struct YAXTreeIteratorState
    node::YAXTree
    visited_children::Vector{String} # Avoid infinite loops in cyclic graphs
    # visited_self::Bool # track if the current node has already been visited
end

# Define the iterator type
struct YAXTreeIterator
    root::YAXTree
end

"""
    Base.iterate(tree::YAXTree)

Creates an iterator that traverses the `YAXTree` in a depth-first, pre-order fashion.

This iterator yields each node in the tree, ensuring that no node is visited twice,
even if children share the same name. The path of each node is used as a unique
identifier.

# Examples

```julia
# Assuming a YAXTree 'my_tree' is defined:
for node in my_tree
    println(node.name, " at path ", node.path)
end
```
"""
Base.iterate(tree::YAXTree) = iterate(tree, YAXTreeIteratorState(tree, String[]))  # Start at the root.

"""
    Base.iterate(tree::YAXTree, state::YAXTreeIteratorState)
"""
function Base.iterate(tree::YAXTree, state::YAXTreeIteratorState)
    node = state.node

    # if !state.visited_self
    #     #First visit of this node
    #     next_state = YAXTreeIteratorState(node, state.visited_children, true)
    #     return (node, next_state)
    # end

    # Compute the *next* state for the next iteration: traverse the tree and keep track of the "visited nodes"
    #   Check if the tree has children:
    if !isempty(node.children)
        #   a. Get the names of the children
        child_names = collect(keys(node.children))

        #   b. Filter out the children that have been visited
        unvisited_children = filter(x -> !(joinpath(node.path,x) in state.visited_children), child_names)

        if !isempty(unvisited_children)
            #   c. Chose the child to visit
            next_child_name = unvisited_children[1]
            next_child = node.children[next_child_name]

            # d. Update the state for the next iteration
            new_visited_children = copy(state.visited_children)
            push!(new_visited_children, joinpath(node.path,next_child_name))
            next_state = YAXTreeIteratorState(next_child, new_visited_children)

            # e. Return the next node and the updated state
            # return (node, next_state)
            return (next_child, next_state)
        else
             # If all children were visited, go up to the parent
             if !isnothing(node.parent)
                next_state = YAXTreeIteratorState(node.parent, state.visited_children)
                return (node.parent, next_state)
             else
                # we reached the root: the tree is finished
                return nothing
             end
        end
    else
        # If all children were visited, go up to the parent
        if !isnothing(node.parent)
            next_state = YAXTreeIteratorState(node.parent, state.visited_children)
            return (node.parent, next_state)
        else
            # we reached the root: the tree is finished
            return nothing
        end
    end
end

# Make the iterator type iterable.  `start`, `next`, `done` are required.
Base.IteratorSize(::Type{YAXTreeIterator}) = Base.SizeUnknown()

# Define the iterator type
Base.eltype(::Type{YAXTreeIterator}) = YAXTree


# --- Macro ---
"""
    macro map_over_subtrees(func, tree)

Map a function `func` over all the nodes of a YAXTree structure which contains a YAXArray or YAXArrays.Datasets.Dataset

# Examples

```julia
# Assuming a YAXTree 'my_tree' is defined:
f(tree::YAXTree) = @show tree.name
YAXTrees.@map_over_subtrees f my_tree
```
"""
macro map_over_subtrees(func, tree)
    quote
        for node in $(esc(tree))
            if !isnothing(node.data)
                $(esc(func))(node)
            end
        end
    end
end

macro map_over_all_subtrees(func, tree)
    quote
        for node in $(esc(tree))
            $(esc(func))(node)
        end
    end
end

function to_zarr(tree::YAXTree, path::String; compressor=Zarr.BloscCompressor())
    if isdir(path)
        throw(ErrorException("$(path) already exists"))
    end
    if !isnothing(tree.data)
        if isa(tree.data, YAXArray)
            savecube(tree.data, path; compressor=compressor, append = true, driver=:zarr)
        else
            savedataset(tree.data; path=path, compressor=compressor, append = true, driver=:zarr)
        end
    end
    function yax_to_zarr(tree)
        node_path = joinpath(path,tree.path)
        if !isdir(node_path)
            println("Save ",node_path)
            # default compressor
            # compressor = Zarr.BloscCompressor(;blocksize=0,clevel=3,cname="zstd",shuffle=2)
            if isa(tree.data, YAXArray)
                savecube(tree.data, node_path; compressor=compressor, append = true, driver=:zarr)
            else
                savedataset(tree.data; path=node_path, compressor=compressor, append = true, driver=:zarr)
            end
        end
    end
    @map_over_subtrees yax_to_zarr tree
end

function where(cond::YAXArray{Bool}, val1, val2)::YAXArray
    function apply_where(c, v1, v2)
        return c ? v1 : v2
    end

    return apply_where.(cond, val1, val2)
end

function where(cond::YAXArray{Union{Missing,Bool}}, val1, val2)::YAXArray
    return where(coalesce.(cond,false), val1, val2)
end

function pwhere(cond::YAXArray{Bool}, val1, val2, chunks)#::Blocks)
    apply_where(c, v1, v2) = c ? v1 : v2
    
    # d_cond = DArray(cond, chunks)
    d_cond = setchunks(cond, chunks)
    # d_val1 = DArray(val1, chunks)
    d_val1 = setchunks(val1,chunks)
    if isa(val2, AbstractArray)
        # d_val2 = DArray(val2, chunks)
        d_val2 = setchunks(val2, chunks)
    else
        d_val2 = val2
    end
    res = apply_where.(d_cond,d_val1,d_val2)

    # return fetch(res)
    # return collect(res)
    return res
end

function pwhere(cond::YAXArray{Union{Missing,Bool}}, val1, val2, chunks)#::Blocks)
    return pwhere(coalesce.(cond,false), val1, val2, chunks)
end

function pwhere(cond::DArray, val1, val2)
    apply_where(c, v1, v2) = c ? v1 : v2
    res = apply_where.(c,v1,v2)
    return fetch(res)
end

function show_tree(tree::YAXTree, prefix::String = ""; details=false)
    println(prefix * "📂 " * tree.name)

    # Show data if present
    if !isnothing(tree.data) && details
        if isa(tree.data, YAXArray)
            type = "YAXArray"
        elseif isa(tree.data, YAXArrays.Datasets.Dataset)
            type = "Dataset"
        else
            type = ""
        end
        if haskey(tree.data.properties, "name")
            name = tree.data.properties["name"]
            println(prefix * "  📊 $type: $name")
        else
            println(prefix * "  📊 $type")
        end
        # @show tree.data
    end
    
    # Recursively print children
    child_prefix = prefix * "  │ "
    child_keys = keys(tree.children) |> collect |> sort
    for (i, key) in enumerate(child_keys)
        is_last = (i == length(child_keys))
        branch = (is_last ? "└─" : "├─")
        show_tree(tree.children[key], prefix * branch * " ";details=details)
    end
end

function show_tree(io::IO, tree::YAXTree, prefix::String = ""; details::Bool = false)
    println(io, prefix * "📂 " * tree.name)
    
    # Show data if present
    if !isnothing(tree.data) && details
        if isa(tree.data, YAXArray)
            type = "YAXArray"
        elseif isa(tree.data, YAXArrays.Datasets.Dataset)
            type = "Dataset"
        else
            type = ""
        end
        if haskey(tree.data.properties, "name")
            name = tree.data.properties["name"]
            println(io, prefix * "  📊 $type: $name")
        else
            println(io, prefix * "  📊 $type")
        end
        # display(tree.data)
        println(io)
    end
    
    # Recursively print children
    child_prefix = prefix * "  │ "
    child_keys = keys(tree.children) |> collect |> sort
    for (i, key) in enumerate(child_keys)
        is_last = (i == length(child_keys))
        branch = (is_last ? "└─" : "├─")
        show_tree(io,tree.children[key], prefix * branch * " ";details=details)
    end
end

function Base.show(io::IO, tree::YAXTree)
    show_tree(io, tree, details=false)
end


# function tree_to_graph(tree::YAXTree, g::Graph=Graph(), node_map=Dict(), parent=nothing)
#     # Create a node index for this tree if not present
#     if !haskey(node_map, tree)
#         node_map[tree] = nv(g) + 1  # Assign new node index
#         add_vertex!(g)
#     end

#     # Connect parent-child in graph
#     if !isnothing(parent)
#         add_edge!(g, node_map[parent], node_map[tree])
#     end

#     # Recursively add children
#     for (_, child) in tree.children
#         tree_to_graph(child, g, node_map, tree)
#     end

#     return g, node_map
# end

# function plot_tree(tree::YAXTree)
#     g, node_map = tree_to_graph(tree)

#     node_labels = [t.name for t in keys(node_map)]

#     # ordered_indices = [node_map[t] for t in keys(node_map)]

#     # sorted_labels = Dict(ordered_indices[i] => node_labels[i] for i in 1:length(node_labels))
#     # Extract labels
#     # labels = Dict(i => t.name for (t, i) in node_map)

#     # Plot with GraphPlot
#     # gplot(g, nodelabel=sorted_labels, nodefillc=RGBA(0.4, 0.6, 0.8, 0.8), edgestrokec=:black)
#     gplot(g, nodelabel = node_labels)
# end


end # module YAXTree
