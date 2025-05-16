using Minio
using Zarr
using AWS
using AWS: @service
@service S3

function initialize_minio_server()
    server = Minio.Server(tempname(), address="localhost:9001")
    run(server, wait=false)
    cfg = MinioConfig("http://localhost:9001")

    bucket = "test-bucket"
    
    try
        s3_create_bucket(cfg, bucket)
    catch e
        @error "Failed to create bucket: $e"
        kill(server)
        throw(e)
    end
    store = S3Store(bucket, cfg)

    return server, store
end

function kill_minio_server(server::Minio.Server)
    kill(server)
end

@testset "Testing Minio config" begin
    # Initialize Minio server
    server, store = initialize_minio_server()
    @test server isa Minio.Server
    @test store isa S3Store
    @test store.bucket == "test-bucket"
    @test store.aws isa MinioConfig

    try

        # Populate the bucket with test data
        test_resources = "resources"
        upload_zarr_to_s3(joinpath(test_resources,"yax.zarr"),store,"test/yax.zarr")

        # Try to access the uploaded data
        AWS.global_aws_config(store.aws)
        z = zopen("s3://$(store.bucket)/test/yax.zarr")
        @test z isa ZGroup
        @test z.arrays["layer"] isa ZArray

    finally
        kill_minio_server(server)
    end
end 