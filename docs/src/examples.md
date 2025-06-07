# Sentinel-3 zarr products


```@setup env
include("setup.jl")
```

## OLCI Level-1
```@example env
olci_path = joinpath(PRODUCT_PATH, OLCEFR) # hide
olci_path # hide
```

```@example env
local_path = joinpath(tempdir(),OLCEFR)
Downloads.download(olci_path, local_path)
efr = open_datatree(local_path)
efr
```

The product is represented by a hierarchical tree structure `YAXTrees.YAXTree`


### Opening measurements data

```@example env
rad = efr.measurements.oa01_radiance
rad
```

The nodes of the `YAXTree` are `YAXArrays.YAXArray` or `YAXArrays.Dataset`

```@example env
rad.data
```

The underlying data is a `CFDiskArray`

### Plot data

We use `Makie.jl` to plot the data.

```@example env
lat=efr.measurements.latitude.data
lon=efr.measurements.longitude.data
val=replace(rad.data, missing => 0.0)

step=10 # hide
lon=lon[1:step:end,1:step:end] # hide
lat=lat[1:step:end,1:step:end] # hide
val=val[1:step:end,1:step:end] # hide
min,max = minimum(val), maximum(val)

fig=Figure(size=(1200,600))
ax1=Axis(fig[1, 1], title=rad.properties["long_name"],
     xlabel="Longitude", ylabel="Latitude")
s=surface!(ax1,lon, lat, zeros(size(lon));
     color=val,colorrange=(min,max),colormap=:rainbow, shading=NoShading)
     Colorbar(fig[1, 2], s)
ax2=Axis(fig[1, 3], title=rad.properties["long_name"],
     xlabel="Columns", ylabel="Rows")
heatmap!(ax2, val, colormap=:rainbow, colorrange=(min,max))
fig
```

### Open meteorological conditions
```@example env
meteo = efr.conditions.meteorology
```

### Interpolate the atmospheric temperature at p=832.2 hPa
```@example env
tp = linear_interpolation(meteo, "atmospheric_temperature_profile", dims="pressure_level", value=832.2)
fig=Figure(size=(800,600))
ax=Axis(fig[1, 1], title="atmospheric_temperature_profile @ 832.2 hPa",
     xlabel="tp_columns", ylabel="tp_rows")
heatmap!(ax,tp.data)
fig
```

## SLSTR Level-2 FRP

```@example env
frp_path = joinpath(PRODUCT_PATH, SLSFRP) # hide
frp_path # hide
```

```@example env
local_path = joinpath(tempdir(),SLSFRP)
Downloads.download(frp_path, local_path)
frp = open_datatree(local_path)
frp
```

The product is represented by a hierarchical tree structure `YAXTrees.YAXTree`

### Opening measurements data (1D)

```@example env
meas = frp.measurements.inadir
meas
```

### Plot Active Fire Pixel on a Plate-Carrée grid

```@example env
using CairoMakie, GeoMakie

frp_vals = Int64.(round.(frp.measurements.inadir.frp_mwir.data))
fig = Figure(size=(800,600))
ax = GeoAxis(fig[1,1]; dest = "+proj=merc")
GeoMakie.xlims!(ax, -125, -114)
GeoMakie.ylims!(ax, 40, 50)
lines!(ax, GeoMakie.coastlines(50), color=:black)
s=GeoMakie.scatter!(ax, 
    frp.measurements.inadir.longitude.data,
    frp.measurements.inadir.latitude.data,
    color=frp_vals,
    colormap=:thermal,
    markersize=15,
    colorrange=(0, 100),
    )
Colorbar(fig[1,2],s, ticks=0:20:100)
fig
```
