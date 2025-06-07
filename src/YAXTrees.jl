module YAXTrees

export YAXTree, open_datatree, map_over_subtrees, add_children!, add_children_full_path!,
       select_vars, exclude_vars, show_tree, to_zarr, path_exists

using YAXArrays, Zarr
using Dagger
using JSON3
using Mmap
# using Graphs, GraphPlot, Colors
import ..CopernicusData: get_AWS_config, s3_get_object, NotImplementedError


"""
    YAXTree

A tree data structure for representing hierarchical data with optional data arrays.

# Fields
- `name::String`: The name of the node
- `path::String`: The full path to this node in the tree
- `properties::Dict{String, Any}`: Additional properties/metadata for the node
- `parent::Union{Nothing, YAXTree}`: Reference to parent node, or nothing for root
- `children::Dict{String, YAXTree}`: Dictionary of child nodes
- `data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}`: Optional data associated with the node
"""
mutable struct YAXTree
    name::String
    path::String
    properties::Dict{String, Any}
    parent::Union{Nothing, YAXTree}
    children::Dict{String, YAXTree}
    data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}
end

"""
    getindex(tree::YAXTree, path::String)::YAXTree

Access a node in the tree using a path string, where path components are separated by "/".

# Arguments
- `tree::YAXTree`: The tree to search in
- `path::String`: Path to the desired node, components separated by "/"

# Returns
- `YAXTree`: The node at the specified path

# Throws
- `KeyError`: If any component of the path does not exist in the tree

# Examples
```julia
node = tree["data/temperature/daily"]  # Get node at path "data/temperature/daily"
```
"""
function Base.getindex(tree::YAXTree,path::String)::YAXTree
    # Handle empty path
    if isempty(path)
        return tree
    end
    
    # Split path into components
    parts = split(path, "/")
    deleteat!(parts, findall(x-> isempty(x) || x==".", parts))
    current = tree
    
    # Traverse the tree following each path component
    for part in parts
        if haskey(current.children, part)
            current = current.children[part]
        else
            throw(KeyError("Path component '$part' not found in tree at '$(current.path)'"))
        end
    end
    
    return current
end

"""
    path_exists(tree::YAXTree, path::String)::Bool

Check if a path exists in the tree.

# Arguments
- `tree::YAXTree`: The tree to search in
- `path::String`: Path to check, components separated by "/"

# Returns
- `Bool`: true if path exists, false otherwise

# Examples
```julia
if is_path_exists(tree, "data/temperature/daily")
    node = tree["data/temperature/daily"]
end
```
"""
function path_exists(tree::YAXTree, path::String)::Bool
    # Handle empty path
    if isempty(path)
        return true
    end
    
    # Split path into components
    parts = split(path, "/")
    deleteat!(parts, findall(x-> isempty(x) || x==".", parts))
    current = tree
    
    # Traverse the tree following each path component
    for part in parts
        if !haskey(current.children, part)
            return false
        end
        current = current.children[part]
    end
    
    return true
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

"""
    YAXTree()

Create a new empty YAXTree with default root node.

# Returns
- `YAXTree`: A new tree with root node named "root"
"""
function YAXTree()
    YAXTree("root",".",Dict(),nothing,Dict(),nothing)
end

"""
    YAXTree(name::String; parent=nothing, data=nothing)

Create a new YAXTree node with the specified name and optional parent and data.

# Arguments
- `name::String`: The name of the node
- `parent=nothing`: Optional parent node
- `data=nothing`: Optional data to associate with the node

# Returns
- `YAXTree`: A new tree node
"""
function YAXTree(name::String;parent=nothing,data=nothing)
    path=""
    properties=Dict()
    parent=parent
    children=Dict()
    data=data
    YAXTree(name,path,properties,parent,children,data)
end

"""
    YAXTree(zgroup::ZGroup)

Create a YAXTree from a Zarr group structure.

# Arguments
- `zgroup::ZGroup`: The Zarr group to convert to a tree

# Returns
- `YAXTree`: A new tree representing the Zarr group hierarchy
"""
function YAXTree(zgroup::ZGroup)
    tree = YAXTree()
    iter_groups!(tree,zgroup)
    tree.properties = zgroup.attrs
    return tree
end

"""
    add_children!(tree::YAXTree, name::Union{String,Symbol}, data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}=nothing)

Add a child node to the tree with the given name and optional data.

# Arguments
- `tree::YAXTree`: The parent tree node
- `name::Union{String,Symbol}`: Name of the new child node (must not contain '/')
- `data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}=nothing`: Optional data to associate with the node

# Throws
- `ArgumentError`: If the name contains '/' or if a child with the same name already exists

# Examples
```julia
add_children!(tree, "temperature", temperature_data)
add_children!(tree, :pressure)  # Add empty node
```
"""
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

"""
    add_children_full_path!(tree::YAXTree, path::String, data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}=nothing)

Add nodes to the tree following a full path, creating intermediate nodes as needed.

# Arguments
- `tree::YAXTree`: The root tree node
- `path::String`: Full path of nodes to create, components separated by "/"
- `data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}=nothing`: Optional data to associate with the leaf node

# Examples
```julia
# Creates nodes "data", "temperature", and "daily" if they don't exist
add_children_full_path!(tree, "data/temperature/daily", temp_data)
```
"""
function add_children_full_path!(tree::YAXTree, path::String, data::Union{Nothing, YAXArray, YAXArrays.Datasets.Dataset}=nothing)
    parts = split(path,"/")
    deleteat!(parts, findall(x-> isempty(x) || x==".", parts))
    current = tree
    if isnothing(data)
        properties=Dict()
    else
        properties = data.properties
    end
    for p in parts
        if !haskey(current.children,p)
            current.children[p] = YAXTree(p, joinpath(current.path,p), properties, current, Dict(), data)
        end
        current = current.children[p]
    end
end

"""
    open_datatree(path::String, driver::Union{Nothing,Symbol}=nothing; name::String="root")::YAXTree

Open a data product and create a YAXTree representation of its structure. The driver is automatically detected from the file extension
or can be specified manually.

# Arguments
- `path::String`: Path to the data product, can be local file/directory or S3 URL
- `driver::Union{Nothing,Symbol}=nothing`: Optional driver specification. Supported values:
  - `:zarr`: For Zarr format files/directories
  - `:sen3`: For Sentinel-3 SEN3 format
  - `:json`: For JSON files
- `name::String="root"`: Name for the root node of the tree

# Returns
- `YAXTree`: A tree representation of the data product structure

# Throws
- `Exception`: If the file doesn't exist or the driver is not supported

# Examples
```julia
# Auto-detect driver from extension
dt = open_datatree("S03SLSLST_20191227T124111_0179_A109_T921.zarr")

# Explicitly specify driver
dt = open_datatree("data.SEN3", :sen3)

# Open from S3
dt = open_datatree("s3://bucket/path/data.zarr")
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


"""
    open_zarr_datatree(path::String; name::String="root", archive::Bool=false)::YAXTree

Open a Zarr format file/directory and create a YAXTree representation. Supports both local and S3 paths, and
optionally handles ZIP archives containing Zarr data.

# Arguments
- `path::String`: Path to Zarr file/directory, can be local or S3 URL
- `name::String="root"`: Name for the root node of the tree
- `archive::Bool=false`: Set to true if path points to a ZIP archive containing Zarr data

# Returns
- `YAXTree`: A tree representation of the Zarr data structure

# Throws
- `Exception`: If the file/directory doesn't exist

# Examples
```julia
# Open local Zarr directory
tree = open_zarr_datatree("data.zarr")

# Open Zarr from ZIP archive
tree = open_zarr_datatree("data.zarr.zip", archive=true)

# Open from S3
tree = open_zarr_datatree("s3://bucket/data.zarr")
```
"""
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
        # Check if there is data in the root node
        data = $(esc(tree)).data
        if !isnothing(data)
            $(esc(func))($(esc(tree)))
        end
        # Iterate over all nodes in the tree
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

"""
    where(cond::YAXArray{Bool}, val1, val2)::YAXArray

Element-wise conditional selection between two values based on a boolean condition array.

# Arguments
- `cond::YAXArray{Bool}`: Boolean condition array
- `val1`: Value to select when condition is true
- `val2`: Value to select when condition is false

# Returns
- `YAXArray`: Array where each element is val1 where cond is true, val2 otherwise

# Examples
```julia
# Create array with values from a where condition is true, b otherwise
result = where(condition_array, a, b)
```
"""
function where(cond::YAXArray{Bool}, val1, val2)::YAXArray
    function apply_where(c, v1, v2)
        return c ? v1 : v2
    end

    return apply_where.(cond, val1, val2)
end

function where(cond::YAXArray{Union{Missing,Bool}}, val1, val2)::YAXArray
    return where(coalesce.(cond,false), val1, val2)
end

"""
    pwhere(cond::YAXArray{Bool}, val1, val2, chunks)

Parallel version of `where` that operates on chunked arrays for improved performance with large datasets.

# Arguments
- `cond::YAXArray{Bool}`: Boolean condition array
- `val1`: Value to select when condition is true
- `val2`: Value to select when condition is false
- `chunks`: Chunk specification for parallel processing

# Returns
- `YAXArray`: Chunked array where each element is val1 where cond is true, val2 otherwise

# Examples
```julia
# Process large array in parallel chunks
result = pwhere(large_condition, a, b, (1000, 1000))
```
"""
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

"""
    show_tree(tree::YAXTree, prefix::String = ""; details::Bool=false)

Display a tree structure in a hierarchical format with optional detailed information.

# Arguments
- `tree::YAXTree`: The tree to display
- `prefix::String=""`: Prefix string for indentation
- `details::Bool=false`: Whether to show detailed information about data nodes

# Examples
```julia
show_tree(my_tree)  # Basic display
show_tree(my_tree, details=true)  # Show with data details
```
"""
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

"""
    show_tree(io::IO, tree::YAXTree, prefix::String = ""; details::Bool = false)

Display a tree structure to an IO stream in a hierarchical format with optional detailed information.

# Arguments
- `io::IO`: The IO stream to write to
- `tree::YAXTree`: The tree to display
- `prefix::String=""`: Prefix string for indentation
- `details::Bool=false`: Whether to show detailed information about data nodes

# Examples
```julia
buf = IOBuffer()
show_tree(buf, my_tree, details=true)
```
"""
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

function remove_subset(
    x::YAXArrays.Datasets.Dataset,
    varnames::Vector{T};
    )::Union{YAXArrays.Datasets.Dataset, Nothing} where T <: Union{String,Symbol}
    available_vars = collect(keys(x.cubes))
    if T == String
        available_vars = string.(available_vars)
    end
    selected_vars = filter(v -> !(v in varnames), available_vars)

    if isempty(selected_vars)
        return nothing
    else
        return x[selected_vars]
    end
end

"""
    copy_subset(x::YAXArrays.Datasets.Dataset, varnames::Vector{T}; error::Bool=false, verbose::Bool=true)::YAXArrays.Datasets.Dataset
Create a copy of a dataset containing only the specified variables.
# Arguments
- `x::YAXArrays.Datasets.Dataset`: The source dataset to copy from
- `varnames::Vector{T}`: List of variable names to include in the copy, where `T` is either `String` or `Symbol`
# Keyword Arguments
- `error::Bool=false`: If true, raises an error if any variable in `varnames` is not present in the dataset
- `verbose::Bool=true`: If true, logs warnings for variables that are not found in the dataset
# Returns
- `YAXArrays.Datasets.Dataset`: A new dataset containing only the specified variables
# Examples
```julia
new_dataset = copy_subset(original_dataset, ["temperature", "pressure"])
# or
new_dataset = copy_subset(original_dataset, [:temperature, :pressure])
```
"""
function copy_subset(
    x::YAXArrays.Datasets.Dataset,
    varnames::Vector{T};
    error::Bool = false,
    verbose::Bool = true
    )::YAXArrays.Datasets.Dataset where T <: Union{String,Symbol}
    selected_vars = varnames
    if !error
        # Get the intersection of available and requested variables
        available_vars = collect(keys(x.cubes))
        if T == String
            available_vars = string.(available_vars)
        end
        selected_vars = filter(v -> v in available_vars, varnames)
        @debug selected_vars
        if !issubset(varnames, available_vars) && verbose
            @warn "Some variables in varnames are not present in the dataset: $(setdiff(varnames, available_vars))"
            @warn "It will be ignored."
        end
    end

    if isempty(selected_vars)
        return x
    else
        # Create a new dataset with only the selected variables
        # Note: Based on Dataset implementation, this raises a KeyError if the variable is not present
        return x[selected_vars]
    end
end

"""
    select_vars(tree::YAXTree, varnames::Vector{T})::YAXTree where T <: Union{String,Symbol}

Create a new YAXTree containing only the specified variables.

# Arguments
- `tree::YAXTree`: The source tree
- `varnames::Vector{String}` or `Vector{Symbol}`: List of variable names to select
# Keyword Arguments
- `exclusive::Bool=false`: If true, only include the specified variables and remove all others. 
In the case when a node has only variable different from the specified ones, the node is removed.
If false, keep only the specified variables from nodes which contains all or some of them, but do not
affect nodes that do not contain any of the specified variables.

# Returns
- `YAXTree`: A new tree containing only the selected variables

# Examples
```julia
new_tree = select_vars(tree, ["temperature", "pressure"])
# or
new_tree = select_vars(tree, [:temperature, :pressure])
```
"""
function select_vars(
    tree::YAXTree,
    varnames::Vector{T};
    exclusive=false
    )::YAXTree where T <: Union{String,Symbol}
    # Create a new root node
    new_tree = YAXTree(tree.name, tree.path, copy(tree.properties), nothing, Dict(), nothing)
    
    function select_vars_from_node(node::YAXTree)
        # If the node has data, filter it
        if !isnothing(node.data) && (!path_exists(new_tree,node.path) || node.path == tree.path)
            @debug node.name, node.path
            if isa(node.data, YAXArrays.Datasets.Dataset)
                new_data::Union{Nothing, YAXArrays.Datasets.Dataset} = nothing
                try
                    new_data = copy_subset(node.data, varnames;error=true,verbose=false)
                catch e
                    if isa(e, KeyError)
                        tmp_data = copy_subset(node.data, varnames;error=false,verbose=false)
                        
                        var_list_ref = collect(keys(node.data.cubes))
                        var_list = collect(keys(tmp_data.cubes))
                        
                        if var_list_ref == var_list && exclusive # No selection and exclusive is true: remove the node
                            return
                        else
                            new_data = tmp_data
                        end
                    else
                        @show e
                        @error "Error copying subset for node $(node.path): $e"
                        return
                    end
                end
                if node.path == tree.path # when there is data in the root node
                    new_tree.data = new_data
                else
                    add_children_full_path!(new_tree, node.path, new_data)
                end
            end
        end
    end
    @map_over_subtrees select_vars_from_node tree
    return new_tree
end

"""
    exclude_vars(tree::YAXTree, varnames::Vector{T}; drop::Bool=false)::YAXTree where T <: Union{String,Symbol}
Create a new YAXTree excluding the specified variables.
# Arguments
- `tree::YAXTree`: The source tree
- `varnames::Vector{String}` or `Vector{Symbol}`: List of variable names to exclude
# Keyword Arguments
- `drop::Bool=false`: If true, remove nodes that do not contain any of the specified variables.
If false, keep nodes even with empty dataset, to preserve the tree structure
# Returns
- `YAXTree`: A new tree excluding the specified variables
# Examples
```julia
new_tree = exclude_vars(tree, ["temperature", "pressure"])
# or
new_tree = exclude_vars(tree, [:temperature, :pressure])
```
"""
function exclude_vars(
    tree::YAXTree,
    varnames::Vector{T};
    drop::Bool=false
    )::YAXTree where T <: Union{String,Symbol}
    # Create a new root node
    new_tree = YAXTree(tree.name, tree.path, copy(tree.properties), nothing, Dict(), nothing)
    
    function exclude_vars_from_node(node::YAXTree)
        # If the node has data, filter it
        if !isnothing(node.data) && (!path_exists(new_tree,node.path) || node.path == tree.path)
            @debug node.name, node.path
            if isa(node.data, YAXArrays.Datasets.Dataset)
                new_data = remove_subset(node.data, varnames)
                if isnothing(new_data) && drop # If no data left and drop==true, remove the node
                    return
                end
                if node.path == tree.path # when there is data in the root node
                    new_tree.data = new_data
                else
                    add_children_full_path!(new_tree, node.path, new_data)
                end
            end
        end
    end

    @map_over_subtrees exclude_vars_from_node tree

    return new_tree
end

end # module YAXTree
