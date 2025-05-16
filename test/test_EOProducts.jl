# test_EOProducts.jl
using YAXArrays
using Zarr

@testset "EOProducts Tests" begin
    # Test EOProduct struct initialization
    @testset "EOProduct Struct" begin
        manifest = Dict("key" => "value")
        datasets = Dict("dataset1" => Dataset())
        mapping = Dict("var1" => "mapped_var1")
        product = EOProduct("TestProduct", "/path/to/product", manifest, datasets, "TestType", mapping)

        @test product.name == "TestProduct"
        @test product.path == "/path/to/product"
        @test product.manifest == manifest
        @test product.datasets == datasets
        @test product.type == "TestType"
        @test product.mapping == mapping
    end

    # Test Base.getindex
    @testset "Base.getindex" begin
        datasets = Dict("dataset1" => Dataset())
        product = EOProduct("TestProduct", "/path/to/product", Dict(), datasets, "TestType", Dict())
        @test product["dataset1"] == datasets["dataset1"]
    end

    # Test EOProduct constructor from path
    @testset "EOProduct constructor from path" begin
        zarr_path = joinpath(dirname(@__FILE__),"resources/yax.zarr")
        product = EOProduct("test_product",zarr_path)

        @test product.name == "test_product"
        @test product.path == zarr_path
        @test !isempty(product.datasets)
        @test product["grp1"] isa Dataset
        @test product["root"] isa Dataset
        @test product["root"].layer isa YAXArray
        @test product["root"].Dim_1 isa Dim
    end

    # Test open_eoproduct
    @testset "open_eoproduct" begin
        using CopernicusData.EOProducts: EOProducts as EOP
        zarr_path = joinpath(dirname(@__FILE__),"resources/yax.zarr")
        vars = EOP.open_eoproduct(zarr_path)
        @test haskey(vars, "layer")
        @test haskey(vars, "Dim_1")
        @test vars["layer"] isa ZArray
        @test vars["Dim_1"] isa ZArray
    end

    # Test eoproduct_dataset
    @testset "eoproduct_dataset" begin
        zarr_path = joinpath(dirname(@__FILE__),"resources/yax.zarr")
        datasets = eoproduct_dataset(zarr_path, driver=:zarr)
        @test haskey(datasets, "root")
        @test datasets["root"] isa Dataset
        @test datasets["root"].layer isa YAXArray
        @test datasets["root"].Dim_1 isa Dim

        # Test unsupported driver
        @test_throws DataType eoproduct_dataset("/invalid/path", driver=:unsupported)
    end

    # Test eoproduct_zarr_dataset
    @testset "eoproduct_zarr_dataset" begin
        zarr_path = joinpath(dirname(@__FILE__),"resources/yax.zarr")
        datasets = EOP.eoproduct_zarr_dataset(zarr_path)
        @test haskey(datasets, "root")
        @test datasets["root"] isa Dataset
        @test datasets["root"].layer isa YAXArray
        @test datasets["root"].Dim_1 isa Dim
    end

    # Test eoproduct_sen3_dataset
    # @testset "eoproduct_sen3_dataset" begin
    #     sen3_path = joinpath(tempdir(), "test.SEN3")
    #     mkpath(sen3_path)
    #     open(joinpath(sen3_path, "file1.nc"), "w") do f
    #         write(f, "dummy")
    #     end
    #     datasets = eoproduct_sen3_dataset(sen3_path)
    #     @test haskey(datasets, "test")
    #     rm(sen3_path, recursive=true)
    # end

    # Test error handling
    @testset "Error Handling" begin
        @test_throws Exception open_eoproduct("/invalid/path")
        @test_throws Exception eoproduct_zarr_dataset("/invalid/path")
        @test_throws Exception eoproduct_sen3_dataset("/invalid/path")
    end
end