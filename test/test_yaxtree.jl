@testset "Testing YAXTree" begin
    root = YAXTree()
    root.childA = YAXTree("childA")
    root.childB = YAXTree("childB")
    root.childA.grandchild = YAXTree("grandchild")

    @test haskey(root.children,"childA")
    @test haskey(root.children,"childB")
    @test haskey(root.childA.children,"grandchild")

    @test root.childA.parent == root

    root.childC = YAXTree("childC",parent=root)
    @test root.childC.parent == root

    root.childA.childAA=YAXTree("childAA")
    root.childA.childAB=YAXTree("childAB")
    root.childB.childBA=YAXTree("childBA")
    root.childB.childAB=YAXTree("childAB")

    global cptr = 0
    function f(tree)
        global cptr
        cptr = cptr+1
    end
    YAXTrees.@map_over_all_subtrees f root
    @test cptr == 16

end

@testset "Testing YAXTree Constructors" begin
    using YAXArrays
    using Zarr
    # Test default constructor
    tree1 = YAXTree()
    @test tree1.name == "root"
    @test isnothing(tree1.parent)
    @test isnothing(tree1.data)
    @test isempty(tree1.children)

    # Test constructor with name and data
    data = YAXArray((Dim{:x}(1:10),), rand(10))
    tree2 = YAXTree("tree2", data=data)
    @test tree2.name == "tree2"
    @test tree2.data == data
    @test isempty(tree2.children)

    # test constructor with zgroup
    zgroup = Zarr.zopen("resources/yax.zarr")
    tree3 = YAXTree(zgroup)
    @test tree3.Dim_1 isa Dim
    @test tree3.layer isa YAXArray
    @test tree3.data isa Dataset
    @test !isempty(tree3.children)
    @test tree3.grp1 isa YAXTree
    @test tree3.grp1.a1 isa YAXArray
end

@testset "Testing YAXTree from local zip file" begin
    using YAXArrays
    path = joinpath(dirname(@__FILE__), "resources/yax.zarr.zip")
    tree = open_datatree(path)

    @test tree.Dim_1 isa Dim
    @test tree.layer isa YAXArray
    @test tree.data isa Dataset
    @test !isempty(tree.children)
    @test tree.grp1 isa YAXTree
    @test tree.grp1.a1 isa YAXArray
    
end

@testset "Testing YAXTree with Minio S3 storage" begin
    # Initialize Minio server
    server, store = initialize_minio_server()

    try
        # Populate the bucket with test data
        test_resources = "resources"
        upload_zarr_to_s3(joinpath(test_resources,"yax.zarr"),store,"test/yax.zarr")
    
        # Open the product from S3 bucket
        path = "s3://$(store.bucket)/test/yax.zarr"
        c = get_AWS_config("minio-test")
        d = s3_list_bucket("s3://$(store.bucket)/")

        tree = open_datatree(path)

        @test tree.Dim_1 isa Dim
        @test tree.layer isa YAXArray
        @test tree.data isa Dataset
        @test !isempty(tree.children)
        @test tree.grp1 isa YAXTree
        @test tree.grp1.a1 isa YAXArray

    finally
        kill_minio_server(server)
    end
end

@testset "Testing YAXTree from SEN3" begin
    path = joinpath(dirname(@__FILE__), "resources/safe.SEN3")
    @test_throws NotImplementedError open_datatree(path) 
end

@testset "Testing YAXTrees.where" begin
    using YAXArrays
    using YAXArrays: YAXArrays as YAX
    using Dates # To generate the dates of the time axis
    using DimensionalData # To use the "Between" selector for selecting data
    using Dagger
    using CopernicusData: YAXTree
    
    t = Date("2020-01-01"):Month(1):Date("2022-12-31")
    common_axis = Dim{:points}(1:100)
    time_axis =   YAX.Time(t)
    
    # Note that longitudes and latitudes are not dimensions, but YAXArrays
    longitudes = YAXArray((common_axis,), collect(range(0,360,100))) # 100 random values taken from 1 to 359
    latitudes  = YAXArray((common_axis,), collect(range(0,90, 100)) ) # 100 random values taken from 0 to 90
    temperature = YAXArray((common_axis, time_axis), rand(-40:40, (100, 36)))
    
    ds = Dataset(; longitudes=longitudes, latitudes=latitudes, temperature=temperature)
    
    ds_subset = ds[points = Where(p-> ds["latitudes"][p]  >= 20 && ds["latitudes"][p]  <= 80 &&
                                 ds["longitudes"][p] >= 0  && ds["longitudes"][p] <= 180
                                 ) # Where
                  ] # ds
    
    mask = YAXArray((common_axis, time_axis), rand(Bool,(100,36)))
    ds_masked = YAXTrees.where(mask,ds.temperature,missing)

    @test isa(ds_masked, YAXArray{Union{Int64,Missing}})

    # Test pwhere(mask,temperature,missing,Blocks())
    rows = Dim{:rows}(1:100)
    columns = Dim{:columns}(1:100)
    temperature = YAXArray((rows,columns), rand(-40:40,(100,100)))
    mask = YAXArray((rows,columns),rand(Bool,(100,100)))
    res=YAXTrees.pwhere(mask,temperature,missing,(50,50))
    @test isa(res, YAXArray{Union{Missing, Int64}})

    #Test pwhere(mask,temperature,-1,Blocks()) with temperature is YAXArray{Union{Int64,missing}}
    res2=YAXTrees.pwhere(mask,res,-1,(50,50))
    @test isa(res2, YAXArray{Union{Int64}})

    #Test pwhere(mask,temperature,temperature.*10,Blocks()) aka default val2 is another array
    res = YAXTrees.pwhere(mask,temperature,temperature.*10,(50,50))
    @test isa(res, YAXArray{Int64})

    #Test pwhere(mask,temperature,missing) with mask including missing
    mask2 = YAXArray((rows,columns),Array{Union{Missing,Bool}}(missing,(100,100)))
    mask2.data .= mask.data
    mask2[1,:] .= missing
    res = YAXTrees.pwhere(mask2, temperature, missing, (50,50))
    @test isa(res, YAXArray{Union{Missing,Int64}})

end

@testset "Testing YAXTree Iterator" begin
    using CopernicusData: YAXTree
    
    # Create a test tree
    root = YAXTree()
    root.childA = YAXTree("childA")
    root.childB = YAXTree("childB")
    root.childA.grandchild1 = YAXTree("grandchild1")
    root.childA.grandchild2 = YAXTree("grandchild2")
    
    # Test iteration
    nodes = []
    for node in root
        push!(nodes, node.name)
    end
    
    # Check that all nodes were visited
    # @test length(nodes) == 5
    @test "root" in nodes
    @test "childA" in nodes
    @test "childB" in nodes
    @test "grandchild1" in nodes
    @test "grandchild2" in nodes
    
    # Test depth-first order
    idx_root = findfirst(x -> x == "root", nodes)
    idx_childA = findfirst(x -> x == "childA", nodes)
    idx_grandchild1 = findfirst(x -> x == "grandchild1", nodes)
    idx_grandchild2 = findfirst(x -> x == "grandchild2", nodes)
    
    # Ensure grandchildren come after childA
    @test idx_childA < idx_grandchild1
    @test idx_childA < idx_grandchild2
end

@testset "Testing add_children! functions" begin
    using CopernicusData: YAXTree
    using YAXArrays
    
    # Test add_children!
    root = YAXTree()
    
    # Add child without data
    add_children!(root, "child1")
    @test haskey(root.children, "child1")
    @test root.children["child1"].name == "child1"
    @test root.children["child1"].parent == root
    @test isnothing(root.children["child1"].data)
    
    # Add child with data
    rows = Dim{:rows}(1:10)
    test_data = YAXArray((rows,), collect(1:10))
    add_children!(root, "child2", test_data)
    @test haskey(root.children, "child2")
    @test root.children["child2"].data == test_data
    
    # Test error on duplicate name
    @test_throws ArgumentError add_children!(root, "child1")
    
    # Test error on name with slash
    @test_throws ArgumentError add_children!(root, "invalid/name")
    
    # Test add_children_full_path!
    test_data2 = YAXArray((rows,), collect(11:20))
    YAXTrees.add_children_full_path!(root, "path/to/deep/child", test_data2)
    
    # Check the path was created
    @test haskey(root.children, "path")
    @test haskey(root.children["path"].children, "to")
    @test haskey(root.children["path"].children["to"].children, "deep")
    @test haskey(root.children["path"].children["to"].children["deep"].children, "child")
    
    # Check the data was assigned to the deepest node
    @test root.children["path"].children["to"].children["deep"].children["child"].data == test_data2
    
    # Test parent-child relationships are correctly set
    @test root.children["path"].parent == root
    @test root.children["path"].children["to"].parent == root.children["path"]
end

@testset "Testing from_dict and JSON functionality" begin
    using CopernicusData: YAXTree
    using YAXArrays
    using JSON3
    
    # Test from_dict with simple dictionary
    test_dict = Dict(
        "name" => "root",
        "property1" => "value1",
        "child1" => Dict(
            "subprop" => "subvalue",
            "grandchild" => Dict()
        ),
        "child2" => Dict(
            "array_data" => [1, 2, 3, 4, 5]
        )
    )
    
    tree = YAXTrees.from_dict(test_dict)
    
    # Test tree structure
    @test haskey(tree.properties, "name")
    @test tree.properties["name"] == "root"
    @test haskey(tree.properties, "property1") 
    @test tree.properties["property1"] == "value1"
    
    # Test children
    @test haskey(tree.children, "child1")
    @test haskey(tree.children["child1"].properties, "subprop")
    @test haskey(tree.children["child1"].children, "grandchild")
    
    # Test array data
    @test haskey(tree.children, "child2")
    @test haskey(tree.children["child2"].children, "array_data")
    
    # Create a temporary JSON file for testing
    test_json_path = joinpath(tempdir(), "test_yaxtree.json")
    open(test_json_path, "w") do io
        JSON3.write(io, test_dict)
    end
    
    # Test open_json_datatree
    json_tree = open_datatree(test_json_path)
    
    # Basic validation
    @test haskey(json_tree.properties, "name")
    @test json_tree.properties["name"] == "root"
    @test haskey(json_tree.children, "child1")
    
    # Clean up
    rm(test_json_path)
end

@testset "Testing display and show methods" begin
    using CopernicusData: YAXTree
    using YAXArrays
    
    # Create a test tree for display
    root = YAXTree("display_root")
    root.childA = YAXTree("childA")
    root.childB = YAXTree("childB")
    
    # Add data to one node
    rows = Dim{:rows}(1:10)
    test_data = YAXArray((rows,), collect(1:10))
    test_data.properties["name"] = "test_array"
    add_children!(root, "data_child", test_data)
    
    # Test show_tree function (basic)
    output = IOBuffer()
    YAXTrees.show_tree(output, root)
    output_str = String(take!(output))
    
    # Check basic formatting
    @test occursin("📂 display_root", output_str)
    @test occursin("📂 childA", output_str)
    @test occursin("📂 childB", output_str)
    @test occursin("📂 data_child", output_str)
    
    # Test show_tree with details
    output = IOBuffer()
    YAXTrees.show_tree(output, root, details=true)
    details_output = String(take!(output))
    
    # Check detailed output includes data type info
    @test occursin("📊 YAXArray: test_array", details_output)
    
    # Test Base.show
    output = IOBuffer()
    show(output, root)
    show_output = String(take!(output))
    
    # Base.show should produce the same output as show_tree without details
    @test occursin("📂 display_root", show_output)
end

@testset "Testing to_zarr functionality" begin
    using CopernicusData: YAXTree
    using YAXArrays
    using Zarr
    
    # Create a test tree with YAXArrays
    root = YAXTree("root")
    
    # Add data to nodes
    rows = Dim{:rows}(1:10)
    cols = Dim{:cols}(1:5)
    
    data1 = YAXArray((rows,), collect(1:10))
    data1.properties["name"] = "array1"
    
    data2 = YAXArray((rows, cols), reshape(collect(1:50), 10, 5))
    data2.properties["name"] = "array2"
    
    add_children!(root, "node1", data1)
    add_children!(root, "node2", data2)
    
    # Create a temporary directory for zarr output
    zarr_path = joinpath(tempdir(), "test_yaxtree.zarr")
    
    # Test that exception is thrown if directory exists
    mkpath(zarr_path)
    @test_throws ErrorException YAXTrees.to_zarr(root, zarr_path)
    rm(zarr_path, recursive=true)
    
    # Test actual zarr creation
    YAXTrees.to_zarr(root, zarr_path)
    
    # Verify the zarr structure
    @test isdir(zarr_path)
    @test isdir(joinpath(zarr_path, "node1"))
    @test isdir(joinpath(zarr_path, "node2"))
    
    # Try to open the zarr and verify contents
    # reopened_tree = open_datatree(zarr_path)
    
    # @test haskey(reopened_tree.children, "node1")
    # @test haskey(reopened_tree.children, "node2")
    
    # Check data dimensions
    # @test size(reopened_tree.node1.data) == (10,)
    # @test size(reopened_tree.node2.data) == (10, 5)
    
    # Check actual data values
    # @test reopened_tree.node1.data[:] == collect(1:10)
    
    # Clean up
    rm(zarr_path, recursive=true)
end

@testset "Testing path_exists" begin
    # Create a test tree
    root = YAXTree()
    root.childA = YAXTree("childA")
    root.childB = YAXTree("childB")
    root.childA.grandchild = YAXTree("grandchild")
    
    # Test existing paths
    @test path_exists(root, "childA")
    @test path_exists(root, "childB")
    @test path_exists(root, "childA/grandchild")
    
    # Test non-existing paths
    @test !path_exists(root, "childC")
    @test !path_exists(root, "childA/nonexistent")
    @test !path_exists(root, "childB/grandchild")
    
    # Test empty path (should return true as it represents the root)
    @test path_exists(root, "")
    
    # Test path with multiple slashes
    @test path_exists(root, "childA//grandchild")
    @test path_exists(root, "/childA/grandchild/")
end

@testset "Testing select_vars" begin
    # Create a test tree with datasets
    root = YAXTree()
    
    # Create test datasets
    ds1 = Dataset(
        temperature = YAXArray((Dim{:x}(1:3),), [20.0, 21.0, 22.0]),
        pressure = YAXArray((Dim{:x}(1:3),), [1000.0, 1001.0, 1002.0]),
        humidity = YAXArray((Dim{:x}(1:3),), [0.6, 0.7, 0.8])
        )
        
        ds2 = Dataset(
            temperature = YAXArray((Dim{:x}(1:3),), [25.0, 26.0, 27.0]),
            wind_speed = YAXArray((Dim{:x}(1:3),), [5.0, 6.0, 7.0])
            )
            
        ds3 = Dataset(
            humidity = YAXArray((Dim{:x}(1:3),), [0.6, 0.7, 0.8]),
            wind_speed = YAXArray((Dim{:x}(1:3),), [5.0, 6.0, 7.0])
    )
    
    # Add datasets to tree
    root.data = ds1
    root.childA = YAXTree("childA", data=ds2)
    root.childB = YAXTree("childB", data=ds3)
    
    # Test selecting existing variables
    selected_tree = select_vars(root, ["temperature", "pressure"])
    @test haskey(selected_tree.data.cubes, :temperature)
    @test haskey(selected_tree.data.cubes, :pressure)
    @test !haskey(selected_tree.data.cubes, :humidity)
    @test path_exists(selected_tree, "childB") == true
    @test haskey(selected_tree.childB.data.cubes, :humidity)
    @test haskey(selected_tree.childB.data.cubes, :wind_speed)
    
    # Test selecting variables with Symbol array
    selected_tree = select_vars(root, [:temperature, :pressure])
    @test haskey(selected_tree.data.cubes, :temperature)
    @test haskey(selected_tree.data.cubes, :pressure)
    
    # Test exclusive mode
    selected_tree = select_vars(root, ["temperature"], exclusive=true)
    @test haskey(selected_tree.data.cubes, :temperature)
    @test !haskey(selected_tree.data.cubes, :pressure)
    @test !haskey(selected_tree.data.cubes, :humidity)
    @test path_exists(selected_tree, "childB") == false
    
    # Test selecting non-existent variables (should keep original data when not exclusive)
    selected_tree = select_vars(root, ["nonexistent"])
    @test !isnothing(selected_tree.data)
    @test haskey(selected_tree.data.cubes, :temperature)
    
    # Test selecting non-existent variables in exclusive mode
    selected_tree = select_vars(root, ["nonexistent"], exclusive=true)
    @test path_exists(selected_tree, "childA") == false
    @test path_exists(selected_tree, "childB") == false
    @test isnothing(selected_tree.data)
end

@testset "Testing exclude_vars functionality" begin
    # Create a test tree with nested datasets
    root = YAXTree()
    
    # Create datasets with test data
    main_ds = Dataset(
        temperature = YAXArray((Dim{:x}(1:3),), [20.0, 21.0, 22.0]),
        pressure = YAXArray((Dim{:x}(1:3),), [1000.0, 1001.0, 1002.0]),
        humidity = YAXArray((Dim{:x}(1:3),), [0.6, 0.7, 0.8])
    )
    
    weather_ds = Dataset(
        wind_speed = YAXArray((Dim{:x}(1:3),), [5.0, 6.0, 7.0]),
        humidity = YAXArray((Dim{:x}(1:3),), [0.5, 0.6, 0.7])
    )
    
    # Build tree structure
    root.data = main_ds
    root.weather = YAXTree("weather", data=weather_ds)
    
    # Test excluding a single variable
    filtered = exclude_vars(root, ["humidity"])
    @test haskey(filtered.data.cubes, :temperature)
    @test haskey(filtered.data.cubes, :pressure)
    @test !haskey(filtered.data.cubes, :humidity)
    @test haskey(filtered.weather.data.cubes, :wind_speed)
    @test !haskey(filtered.weather.data.cubes, :humidity)
    
    # Test excluding multiple variables
    filtered = exclude_vars(root, ["humidity", "pressure"])
    @test haskey(filtered.data.cubes, :temperature)
    @test !haskey(filtered.data.cubes, :pressure)
    @test !haskey(filtered.data.cubes, :humidity)
    @test haskey(filtered.weather.data.cubes, :wind_speed)
    @test !haskey(filtered.weather.data.cubes, :humidity)
    
    # Test excluding all variables from a node
    filtered = exclude_vars(root, ["wind_speed", "humidity"])
    @test haskey(filtered.data.cubes, :temperature)
    @test haskey(filtered.data.cubes, :pressure)
    @test !haskey(filtered.data.cubes, :humidity)
    @test isnothing(filtered.weather.data)  # Node should have no data when all variables are excluded
    
    # Test excluding all variables from a node
    filtered = exclude_vars(root, ["wind_speed", "humidity"], drop=true)
    @test haskey(filtered.data.cubes, :temperature)
    @test haskey(filtered.data.cubes, :pressure)
    @test !haskey(filtered.data.cubes, :humidity)
    @test isempty(filtered.children)  # Node is fully removed

    # Test with symbol input
    filtered = exclude_vars(root, [:humidity, :pressure])
    @test haskey(filtered.data.cubes, :temperature)
    @test !haskey(filtered.data.cubes, :pressure)
    @test !haskey(filtered.data.cubes, :humidity)
    
    # Test excluding non-existent variables
    filtered = exclude_vars(root, ["non_existent"])
    @test haskey(filtered.data.cubes, :temperature)
    @test haskey(filtered.data.cubes, :pressure)
    @test haskey(filtered.data.cubes, :humidity)
    @test haskey(filtered.weather.data.cubes, :wind_speed)
    @test haskey(filtered.weather.data.cubes, :humidity)
end