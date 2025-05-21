# CopernicusData.jl



Documentation for [CopernicusData.jl](https://github.com/vlevasseur073/CopernicusData.jl)

CopernicusData is a framework to be used for Earth Observation satellite data processing from the EU Copernicus program,
especially the Sentinels Missions.
It defines a data structure for managing, storing EO data and a light orchestration framework to implement and chain processing steps.

```@example env
using CopernicusData # hide
using Plots # hide
path=joinpath(dirname(dirname(pathof(CopernicusData))), "docs/resources/S03SLSLST_20191227T124111_0179_A109_T883.zarr.zip") # hide
tree = open_datatree(path) # hide
return nothing # hide
```

```@example env
heatmap(tree.measurements.lst.data, title="Land Surface Temperature over Brazil seen by Sentinel-3 A") # hide
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
tree = open_datatree(path)
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
