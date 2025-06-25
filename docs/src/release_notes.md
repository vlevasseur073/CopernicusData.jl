# Release notes

**Version:**
```@example env
using CopernicusData # hide
pkgversion(CopernicusData) # hide
```

## Current release overview

**YAXTrees:**

* Common entrypoint `open_datatree` function to open Zarr, Sentinel-3 SAFE, json (used for Auxiliary Data Files) products.
* Iterate on the nodes of a `YAXTree` with `map_over_subtrees`
* Filtering/Selection features
* Export YAXTrees.to_zarr function
* isomorphic comparison of two `YAXTree`s

**EOTriggering:**

* Light orchestrator to run processing workflows from a TOML payload file
* Support for configurable logging levels (Debug, Info)
* Processing workflow configuration with:
  * Module and processing unit specification
  * Input product configuration
  * Parameter handling for processing units
  * Support for auxiliary data files
* Simple error handling and reporting
* Modular processing unit execution through function calls
* Support for multiple input products as YAXTrees

**utils:**

* Utilities for uploading Zarr datasets and files to S3-compatible object storage
* Functions for walking Zarr directory structures and uploading all contents with correct content types
* Support for custom S3 object metadata and content type inference
* Error handling and logging for upload operations
* AWS configuration helpers:
  * Read AWS credentials and config from INI files or environment variables
  * Support for custom endpoints and regions (e.g., for on-prem/cloud S3)
  * Custom AWS config struct for flexible service URL generation
* S3 helper functions:
  * List objects in a bucket or prefix
  * Retrieve objects from S3 by full path

## History

### v0.2.0

* Add `YAXTree` filtering feature based on variable selection. See [`YAXTrees.select_vars`](@ref) and [`YAXTrees.exclude_vars`](@ref)
* Add `YAXTree` isomorphic check. Two `YAXTree` are isomorphic if they have the exact same tree structure and if the data contained in equivalent node
is the same type (`YAXArrays.YAXArray` or `YAXArrays.Datasets.Dataset`) and have the same variables and same dimensions. 
It does not compare the content of the arrays itself. See [`YAXTrees.isomorphic`](@ref)
* Implement a direct access to YAXArray or Dataset field (cubes and axes)
* Implement reading Sentinel-3 SAFE products (OLCI and SLSTR), and converting it in-memory into EOPF-like `YAXTree` product structure
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
 * Basic interpolations are implemented. To be improved in the future releases, in connection with upcoming improvements of `YAXArrays.jl`
 * Limited support of Sentinel-3 SAFE format (OLCI, SLSTR L1, L2 LST and L2 FRP). SYN are currently missing. Other missions to come.

