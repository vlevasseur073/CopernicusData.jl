@testset "Testing aws functions" begin
    # Initialize Minio server
    server, store = initialize_minio_server()

    try
        # Populate the bucket with test data
        test_resources = "resources"
        upload_zarr_to_s3(joinpath(test_resources,"yax.zarr"),store,"test/yax.zarr")
        upload_to_s3(joinpath(test_resources,"adf.json"),store.bucket,"test/adf.json";content_type="application/json")

        # Open the product from S3 bucket
        c = get_AWS_config("minio-test")

        @test !isnothing(c)

        d = s3_list_bucket("s3://test-bucket/")
        @test !isempty(d["Contents"])

        pp = s3_get_object("s3://test-bucket/test/adf.json")
        @test pp["title"] == "SL2 Processing Control Parameter File"

    finally
        kill_minio_server(server)
    end

end