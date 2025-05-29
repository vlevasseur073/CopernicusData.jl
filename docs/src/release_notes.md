# Release notes

**Version:**
```@example env
using CopernicusData # hide
pkgversion(CopernicusData) # hide
```

## Current release overview
* Export YAXTrees.to_zarr function

## History

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

