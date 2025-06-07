# CopernicusData.jl



Documentation for [CopernicusData.jl](https://github.com/vlevasseur073/CopernicusData.jl)

CopernicusData is a framework to be used for Earth Observation satellite data processing from the EU Copernicus program,
especially the Sentinels Missions.
It defines a data structure for managing, storing EO data and a light orchestration framework to implement and chain processing steps.

```@setup env
include("setup.jl")
lst_path = joinpath(PRODUCT_PATH, SLSLST)
local_path = joinpath(tempdir(),SLSLST)
Downloads.download(lst_path, local_path)
tree = open_datatree(local_path)             
```

```@example env
# lst_data = reverse(permutedims(tree.measurements.lst.data),dims=1) # hide
lst_data = reverse(tree.measurements.lst.data,dims=2) # hide
# heatmap(lst_data, title="Land Surface Temperature over Brazil (Sentinel-3 A)", c=:rainbow, xlabel="columns", ylabel="rows") # hide
fig=Figure(size=(800,600)) # hide
ax=Axis(fig[1, 1], title="Land Surface Temperature over Brazil (Sentinel-3 A)", # hide
     xlabel="columns", ylabel="rows") # hide
heatmap!(ax,lst_data, colormap=:rainbow) # hide
fig # hide
```

## The Data structure

The data structure used in `CopernicusData.jl` is mostly focused on zarr format, 
using [`Zarr.jl`](https://github.com/JuliaIO/Zarr.jl) package.
The data representation is based on [`YAXArrays.jl`](https://github.com/JuliaDataCubes/YAXArrays.jl).
Though it is designed to handle the Sentinels new EOPF product format,
it remains fully generic and can represent any kind of hierarchical data tree structure.
Please visit [https://eopf.copernicus.eu/eopf/](https://eopf.copernicus.eu/eopf/) to have further details about the EOPF data format.

### `YAXTrees` module

 The `YAXTrees` module provide a hierarchical tree structure of `YAXArrays` or `Datasets`.

Below is a basic usage to construct a tree structure

 ```@example env
root = YAXTree()
root.childA = YAXTree("childA")
root.childB = YAXTree("childB")
root.childA.grandchild = YAXTree("grandchild")
root
```

Using Zarr backend, a recursive zarr structure representing Copernicus product can be accessed with the `open_datatree`
function.
Using the feature from YAXArrays.jl, based on DiskArrays.jl, the data is lazy loaded.

 ```@example env
tree = open_datatree(local_path)
```

A more detailed view can be displayed

 ```@example env
YAXTrees.show_tree(tree; details=true)
```

You can use dictionary or the traditional dot indexing to access any node of the tree structure
 ```@example env
tree["measurements"].data
```

 ```@example env
tree.conditions.geometry.solar_zenith_tn
```

### `EOProduct` module

***deprecated*** 

## Orchestration

A light orchestration is providing by the ̀`EOTriggering` module.

```@example
include("utils.jl") # hide
include_toml_in_markdown("../resources/payload.toml") #hide
```

```@example env
payload_file_path="../resources/payload.toml"
EOTriggering.run(payload_file_path)
```
