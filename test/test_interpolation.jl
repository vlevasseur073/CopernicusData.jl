using YAXArrays
using DimensionalData

@testset "Interpolation Tests" begin
    # Create a sample YAXArray for testing
    data = Float64.(collect(1:5))  # Reshape to match dimension
    dim = Dim{:x}(data)
    da = YAXArray((dim,), data)

    # Test linear_interpolation with YAXArray
    @testset "YAXArray interpolation" begin
        # Test interpolation at a point within the range
        result = linear_interpolation(da; dims="x", value=2.5)
        @test result[1] ≈ 2.5

        # Test interpolation at endpoints
        @test linear_interpolation(da; dims="x", value=1.0)[1] ≈ 1.0
        @test linear_interpolation(da; dims="x", value=5.0)[1] ≈ 5.0
    end

    # Test with reversed order data
    @testset "Reversed order interpolation" begin
        dim_rev = Dim{:x}(reverse(data), order=YAXArrays.DD.Dimensions.Lookups.ReverseOrdered())
        data_rev = reverse(data)
        da_rev = YAXArray((dim_rev,), data_rev)

        result_rev = linear_interpolation(da_rev; dims="x", value=2.5)
        @test result_rev[1] ≈ 2.5
    end

    # Test with YAXTree
    @testset "YAXTree interpolation" begin
        # Create a YAXTree with the test data using the proper constructor
        tree = YAXTrees.YAXTree("test_layer"; data=da)

        # Test interpolation through YAXTree interface
        result_tree = linear_interpolation(tree, "test_layer"; dims="x", value=2.5)
        @test result_tree[1] ≈ 2.5

        # Test error for tree without data - using default constructor
        empty_tree = YAXTrees.YAXTree()
        @test_throws ArgumentError linear_interpolation(empty_tree, "layer"; dims="x", value=2.5)
    end

    # Test with multidimensional array
    @testset "Multidimensional interpolation" begin
        # Create 2D array
        dim_x = Dim{:x}(Float64.(collect(1:3)))
        dim_y = Dim{:y}(Float64.(collect(1:4)))
        data_2d = Float64.([i + j for i in 1:3, j in 1:4])
        da_2d = YAXArray((dim_x, dim_y), data_2d)

        # Test interpolation along x dimension
        result_2d = linear_interpolation(da_2d; dims="x", value=2.0)
        @test size(result_2d) == (4,)  # Should return a vector along y dimension
        @test all(result_2d .≈ [3.0, 4.0, 5.0, 6.0])
    end
end
