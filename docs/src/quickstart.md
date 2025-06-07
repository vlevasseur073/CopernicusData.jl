# QuickStart

## Installation

Install the latest version of CopernicusData.jl using the Julia's built-in package manager
(accessed by pressing `]` in the Julia REPL command prompt):

```julia
julia> ]
(v1.10) pkg> add CopernicusData
```

The package can be updated via the package manager by

```julia
(v1.10) pkg> update CopernicusData
```

!!! warn "Use Julia 1.10 or newer"
    
## Open Sentinel-3 SLSTR Level-2 LST product

```@example env
using CopernicusData
using CairoMakie
using Downloads

const PRODUCT_PATH = "https://common.s3.sbg.perf.cloud.ovh.net/eoproducts"
const SLSLST="S03SLSLST_20191227T124111_0179_A109_T883.zarr.zip"

slstr_path = joinpath(PRODUCT_PATH, SLSLST)
local_path = joinpath(tempdir(),SLSLST)
Downloads.download(slstr_path, local_path)

yaxt = open_datatree(local_path)
yaxt
```

```@example env
lat=yaxt.measurements.latitude.data
lon=yaxt.measurements.longitude.data
lst=yaxt.measurements.lst.data
min,max = minimum(skipmissing(lst)), maximum(skipmissing(lst))
val=replace(lst, missing => 0.0)

step=2 # hide
lon=lon[1:step:end,1:step:end] # hide
lat=lat[1:step:end,1:step:end] # hide
val=val[1:step:end,1:step:end] # hide

fig=Figure(size=(800,600))
ax1=Axis(fig[1, 1], title=yaxt.measurements.lst.properties["long_name"],
     xlabel="Longitude", ylabel="Latitude")
s=surface!(ax1,lon, lat, zeros(size(lon));
     color=val,colorrange=(min,max),colormap=:rainbow, shading=NoShading)
     Colorbar(fig[1, 2], s)
fig
```
