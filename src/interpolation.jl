using Interpolations
using YAXArrays
import ..YAXTrees: YAXTrees as YAXT

function linear_interp(y, x, val)
    itp = Interpolations.linear_interpolation(x,y)
    return itp(val)
end

function linear_interpolation(da::YAXArray; dims::String, value::Number)
    dim = getproperty(da, Symbol(dims))
    x = dim.val.data
    
    # Check if reverse ordered
    if dim.val.order isa YAXArrays.DD.Dimensions.Lookups.ReverseOrdered
        da_check = reverse(da, dims=dim)
        x_check = reverse(x)
    else
        da_check = da
        x_check = x
    end
    mapslices(linear_interp, da_check, x_check, value, dims=dims)

end

function linear_interpolation(dt::YAXT.YAXTree, variable::String; dims::String, value)
    if isnothing(dt.data)
        throw(ArgumentError("YAXTree $dt has no data"))
    end
    if dt.data isa YAXArrays.Dataset
        da = getproperty(dt.data, Symbol(variable))
    else
        da = dt.data
    end
    linear_interpolation(da; dims=dims, value=value)
end