module CopernicusData

struct NotImplementedError <: Exception
    msg::String
    NotImplementedError(msg="This functionality is not implemented yet.") = new(msg)
end

export NotImplementedError

include("aws.jl")
export get_AWS_config, s3_list_bucket, s3_get_object

include("utils.jl")
export unzip_zarr_to_tempdir, upload_zarr_to_s3, upload_to_s3

include("EOProducts.jl")
include("YAXTrees.jl")
include("interpolation.jl")
export linear_interpolation
include("EOTriggering.jl")
include("ExampleProcessor.jl")

using Reexport: @reexport

@reexport using .EOProducts
@reexport using .EOTriggering
@reexport using .YAXTrees

@reexport using .ExampleProcessor

end # module CopernicusData
