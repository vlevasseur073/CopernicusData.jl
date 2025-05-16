[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://vlevasseur073.github.io/CopernicusData.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://vlevasseur073.github.io/CopernicusData.jl/dev/)
[![Build Status](https://github.com/vlevasseur073/CopernicusData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/vlevasseur073/CopernicusData.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/vlevasseur073/CopernicusData.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/vlevasseur073/CopernicusData.jl)

# CopernicusData.jl

CopernicusData (*Earth Observation Processing Framework*) is a framework to be used for Earth Observation satelite data processors.
It defines a data structure for managing, storing EO data and a light orchestration framework to implement and chain processing steps.

## Data Structure

The data structure used in `CopernicusData.jl` is mostly focused on zarr format, 
using [`Zarr.jl`](https://github.com/JuliaIO/Zarr.jl) package.
The data representation is based on [`YAXArrays.jl`](https://github.com/JuliaDataCubes/YAXArrays.jl).

### `YAXTrees` module

 The `YAXTrees` module provide a hierarchical tree structure of `YAXArrays` or `Datasets`.

Using Zarr backend, a recursive zarr structure representing Copernicus product can be accessed with the `open_datatree`
function.
Using the feature from YAXArrays.jl, based on DiskArrays.jl, the data is lazy loaded.

### `EOProduct` module

***deprecated***

## Orchestration

A light orchestration is providing by the ̀`EOTriggering` module.


