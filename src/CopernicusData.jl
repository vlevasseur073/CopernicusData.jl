module CopernicusData

include("aws.jl")
export get_AWS_config, s3_list_bucket, s3_get_object

include("utils.jl")
export unzip_zarr_to_tempdir, upload_zarr_to_s3, upload_to_s3

include("EOProducts.jl")
include("YAXTrees.jl")
include("EOTriggering.jl")
include("ExampleProcessor.jl")

using Reexport: @reexport

@reexport using .EOProducts
@reexport using .EOTriggering
@reexport using .YAXTrees

@reexport using .ExampleProcessor

end # module CopernicusData
