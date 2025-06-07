# Release notes

**Version:**
```@example env
using CopernicusData # hide
pkgversion(CopernicusData) # hide
```

## Current release overview
* Export YAXTrees.to_zarr function

## History

### v0.2.0

* Add `YAXTree` filtering feature based on variable selection. See [`YAXTrees.select_vars`](@ref) and [`YAXTrees.exclude_vars`](@ref)
* Add `YAXTree` isomorphic check. Two `YAXTree` are isomorphic if they have the exact same tree structure and if the data contained in equivalent node
is the same type (`YAXArrays.YAXArray` or `YAXArrays.Datasets.Dataset`) and have the same variables and same dimensions. 
It does not compare the content of the arrays itself. See [`YAXTrees.isomorphic`](@ref)
* Improve documentation. Use `Makie.jl` for visualization

### v0.1.0

* Implementation of data structure to hold the new CopernicusData zarr Sentinels products from the Copernicus mission
    * `YAXTrees` module implements f hierarchical tree structure of `YAXArrays` or `Datasets` from `YAXArrays.jl` package
* Implementation of a light orchestrator to run any kind of processing module from a input payload file: 
    * read the inputs products
    * run the provided workflows
    * store the output products

## Status of the package

This is a beta release

## Known problems or limitations
 * Reading zipped zarr is not fully handled. Feature to be requested to Zarr.jl package [https://github.com/JuliaIO/Zarr.jl/issues/189](https://github.com/JuliaIO/Zarr.jl/issues/189). The current Zarrl.ZipStore handles files on the local filesystem not yet files on a cloud storage.
 * Basic interpolations are implementations. To be improved in the future releases, in connection with upcoming improvements of `YAXArrays.jl`
 * Handling the legacy SAFE format for few missions to come. (Likely Sentinle-3 at first)

