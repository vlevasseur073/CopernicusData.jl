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

        # Populate the bucket with zarr test data
        test_resources = "resources"
        upload_zarr_to_s3(joinpath(test_resources,"yax.zarr"),store,"test/yax.zarr")

        # Try to access the uploaded data
        AWS.global_aws_config(store.aws)
        z = zopen("s3://$(store.bucket)/test/yax.zarr")
        @test z isa ZGroup
        @test z.arrays["layer"] isa ZArray


        # Test different file types
        test_files = Dict(
            "test.txt" => ("Hello, text!", "text/plain"),
            "test.jpg" => ([0xff, 0xd8, 0xff], "image/jpeg"),
            "test.png" => ([0x89, 0x50, 0x4E, 0x47], "image/png"),
            "test.pdf" => ("%PDF-1.5", "application/pdf"),
            "test.unknown" => ("Some data", "application/octet-stream")
        )

        for (filename, (content, expected_type)) in test_files
            # Create temporary file
            tmpfile = tempname() * filename
            write(tmpfile, content)

            # Upload file
            bucket = store.bucket
            key = "test/$filename"
            upload_to_s3(tmpfile, bucket, key)

            # Verify content and content type
            AWS.global_aws_config(store.aws)
            response = S3.head_object(bucket, key)
            @test response["Content-Type"] == expected_type

            # Check content
            obj = S3.get_object(bucket, key)
            # @test obj == content
            if typeof(content) == String
                @test String(obj) == content
            else
                @test obj == content
            end

            # Clean up temporary file
            rm(tmpfile)
        end

        # Test explicit content type override
        # tmpfile = tempname() * ".txt"
        # write(tmpfile, "Custom content type")
        # upload_to_s3(tmpfile, store.bucket, "test/custom.txt"; 
        #             content_type="application/custom")
        
        # response = S3.head_object(store.bucket, "test/custom.txt")
        # @test response["Content-Type"] == "application/custom"
        # rm(tmpfile)
        

    finally
        kill_minio_server(server)
    end
end