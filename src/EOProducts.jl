module EOProducts

export eoproduct_dataset,EOProduct

using YAXArrays, Zarr

mutable struct EOProduct
    name::String
    path::String
    manifest::Dict{String,Any}
    datasets::Dict{String,YAXArrays.Datasets.Dataset}
    type::String
    mapping::Dict{String,String}
end

# function Base.get(prod::EOProduct, key::String)
#     prod.datasets[key]
# end

function Base.getindex(product::EOProduct,path::String)::Dataset
    return product.datasets[path]
end

function iter_groups!(vars::Dict{String,ZArray},z::ZGroup)
    # if isempty(z.groups)
    #     println(z)
        for var in z.arrays
            vars[var.first]=var.second
        end
    # end
    for g in z.groups
        if isa(g.second,ZGroup)
            iter_groups!(vars,g.second)
        end
    end

end

"""
    open_eoproduct(path::String)

Open a Copernicus Zarr product
returns a Dict{String,ZArray} containing all the Variables stored in the product


# Examples
```julia-repl
julia> d = open_eoproduct("S3SLSLST_20191227T124111_0179_A109_T921.zarr")
```
"""
function open_eoproduct(path::String)
    z = zopen(path,consolidated=true)
    vars = Dict{String,ZArray}()
    iter_groups!(vars,z)
    return vars
end


"""
    eoproduct_dataset(path::String)::Dict{String, Dataset}

Open a Copernicus product
returns a Dict{String,Dataset} containing all the Variables stored in the product


# Examples
```julia-repl
julia> d = open_eoproduct("S3SLSLST_20191227T124111_0179_A109_T921.zarr")
```
"""
function eoproduct_dataset(path::String;driver::Union{Nothing,Symbol}=nothing)::Dict{String, Dataset}
    -,ext = splitext(rstrip(path,'/'))
    if isnothing(driver)
        if ext == ".zarr"
            driver = :zarr
        elseif ext == ".SEN3"
            driver = :sen3
        else
            @error "Cannot find backend with extension. Available backends are ['.zarr','.SEN3']"
            throw(Exception)
        end
    end
    if driver == :zarr
        return eoproduct_zarr_dataset(path)
    elseif driver == :sen3
        return eoproduct_sen3_dataset(path)
    else
        @error "Driver $driver is not implemented. Available backends are [:zarr,:sen3]"
        throw(Exception)
    end
end

function eoproduct_sen3_dataset(path::String)::Dict{String, Dataset}
    println("HELLO")
    # Check path exist
    if !isdir(path)
        @error "Product Path does not exist ", path
        throw(Exception)
    end
    eo_product = Dict{String,Dataset}()
    for file in readdir(path,join=true)
        println("Setting dataset from",file)
        ds=open_dataset(file)
        eo_product["test"] = ds
    end

    return eo_product
end

function eoproduct_zarr_dataset(path::String)::Dict{String, Dataset}
    # Check path exist
    if !isdir(path)
        @error "Product Path does not exist ", path
        throw(Exception)
    end

    # Get leaf groups of the product
    variables = [ d[1] for d in walkdir(path) if isempty(d[2]) ]
    leaf_groups = unique(dirname.(variables))

    zprod = zopen(path, consolidated=true)
    leaf_groups = replace.(leaf_groups, path=>"")
    leaf_groups=replace.(leaf_groups,r"^/"=>"")
    eo_product = Dict{String,Dataset}()
    for p in leaf_groups
        ds = Dataset()
        # zgroup = zopen(p,consolidated=true)
        zgroup = zprod

        if !isempty(p)
            for g in splitpath(p)
                zgroup = zgroup[g]
            end
            for zarray in zgroup.arrays
                if haskey(zarray.second.attrs,"fill_value")
                    zarray.second.attrs["missing_value"] = zarray.second.attrs["fill_value"]
                    # zarray.second.attrs=delete!(zarray.second.attrs,"_FillValue")
                else
                    zarray.second.attrs["missing_value"] = zarray.second.metadata.fill_value
                end
            end
        end
        try
            ds = open_dataset(zgroup)
        catch e
            @warn e
            @warn "Problem encountered for $p"
            @warn zgroup
            continue
        end
        key = basename(p)
        if isempty(key)
            key = "root"
        else
            key = replace(p,path=>"")
            if key[1] == '/'
                key=key[2:end]
            end
        end
        eo_product[key] = ds
    end
    return eo_product
end


function EOProduct(name::String,path::String)
    manifest = zopen(path).attrs
    datasets = eoproduct_dataset(path)
    type = splitpath(path)[end][1:8]
    mapping = Dict{String,String}()
    EOProduct(name,path,manifest,datasets,type,mapping)
end

end # module EOProducts
