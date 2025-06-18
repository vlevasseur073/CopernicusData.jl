# YAXTrees

The `YAXTree` module provides a hierarchical data structure for working with nested data arrays and datasets. It's particularly useful for handling complex data structures like Zarr groups or JSON hierarchies.

## Creating Trees

### Basic Tree Creation

```julia
# Create an empty root node
root = YAXTree()

# Create a node with a specific name
node = YAXTree("mynode")

# Create a node with data
using YAXArrays
data = YAXArray((Dim{:rows}(1:10),), collect(1:10))
data_node = YAXTree("data_node", data=data)
```

### Adding Children

```julia
# Add children to a tree
root = YAXTree()
add_children!(root, "child1")  # Add empty child
add_children!(root, "child2", data)  # Add child with data

# Add nested children using a path
add_children_full_path!(root, "path/to/deep/child", data)
```

## Tree Navigation and Access

### Accessing Nodes

```julia
# Access children using property syntax
child1 = root.child1
grandchild = root.child1.grandchild

# Access using string paths
node = root["path/to/node"]

# Check if a path exists
if path_exists(root, "path/to/node")
    # Do something
end
```

### Iterating Over Trees

```julia
# Iterate over all nodes in the tree (depth-first)
for node in root
    println(node.name)
end

# Using the map_over_subtrees macro
function process_node(tree::YAXTree)
    if !isnothing(tree.data)
        # Process data
    end
end

YAXTrees.@map_over_subtrees process_node root
```

## Working with Data

### Data Selection and Filtering

```julia
# Filter data based on conditions
mask = YAXArray((rows, time), rand(Bool, (100, 36)))
temperature = YAXArray((rows, time), rand(-40:40, (100, 36)))

# Replace values where mask is true with missing
masked_data = where(mask, temperature, missing)

# Parallel processing for large arrays
chunked_result = pwhere(mask, temperature, -1, (50, 50))
```

## File I/O Operations

### Opening Data Trees

```julia
# Open from Zarr format
tree = open_datatree("data.zarr")

# Open from zipped Zarr
tree = open_datatree("data.zarr.zip")

# Open from JSON
tree = open_datatree("data.json", :json)

# Open from S3
tree = open_datatree("s3://bucket/data.zarr")
```

### Writing to Zarr

```julia
# Save tree to Zarr format
to_zarr(tree, "output.zarr")
```

## Visualization

### Display Tree Structure

```julia
# Basic tree display
show_tree(tree)

# Display with detailed information
show_tree(tree, details=true)

# Custom display with prefix
show_tree(tree, "  ", details=true)
```

## Isomorphism check

The [`YAXTrees.isomorphic`](@ref) function returns a boolean whether 2 trees are isomorphic or not.
Two `YAXTree` are isomorphic if they have the exact same tree structure and if the data contained in equivalent node
is the same type (`YAXArrays.YAXArray` or `YAXArrays.Datasets.Dataset`) and have the same variables and same dimensions. 

```julia
isomorphic(tree1, tree2)  # Returns true if both trees have the same structure and data
```

## Advanced Features

### Copying and Subsetting

The `select_vars` function provides flexible ways to select and copy parts of your data tree:

```julia
# Basic variable selection
selected_tree = select_vars(tree, ["temperature", "pressure"])  # using strings
selected_tree = select_vars(tree, [:temperature, :pressure])    # using symbols

# Non-exclusive mode (default)
# - Keeps nodes that have any of the specified variables
# - Preserves nodes without any of the specified variables
tree1 = select_vars(root, ["temperature", "pressure"])

# Exclusive mode
# Only keeps nodes that have the specified variables
# Removes nodes that only have different variables
tree2 = select_vars(root, ["temperature", "pressure"], exclusive=true)
```

Example with different behaviors:

```julia
# Create a test tree with different datasets
root = YAXTree()

# Dataset with temperature and pressure
ds1 = Dataset(
    temperature = YAXArray((Dim{:x}(1:3),), [20.0, 21.0, 22.0]),
    pressure = YAXArray((Dim{:x}(1:3),), [1000.0, 1001.0, 1002.0]),
    humidity = YAXArray((Dim{:x}(1:3),), [0.6, 0.7, 0.8])
)

# Dataset with only wind_speed
ds2 = Dataset(
    wind_speed = YAXArray((Dim{:x}(1:3),), [5.0, 6.0, 7.0])
)

# Add datasets to tree
root.data = ds1
root.child = YAXTree("child", data=ds2)

# Non-exclusive selection - keeps both nodes
selected1 = select_vars(root, ["temperature"])
@assert path_exists(selected1, "child") == true  # child node kept

# Exclusive selection - removes child node as it has no selected variables
selected2 = select_vars(root, ["temperature"], exclusive=true)
@assert path_exists(selected2, "child") == false  # child node removed

# Control error handling with datasets
copied_ds = copy_subset(dataset, ["temperature", "pressure"],
                     error=false,    # Don't error on missing variables
                     verbose=true)   # Show warning for missing variables

# Remove unwanted variables
filtered_tree = exclude_vars(tree, ["humidity", "wind_speed"])

# Advanced filtering example:
root = YAXTree()

# Create datasets with different variables
ds_main = Dataset(
    temperature = YAXArray((Dim{:x}(1:3),), [20.0, 21.0, 22.0]),
    pressure = YAXArray((Dim{:x}(1:3),), [1000.0, 1001.0, 1002.0]),
    humidity = YAXArray((Dim{:x}(1:3),), [0.6, 0.7, 0.8])
)

ds_weather = Dataset(
    wind_speed = YAXArray((Dim{:x}(1:3),), [5.0, 6.0, 7.0])
)

# Build tree structure
root.data = ds_main                     # Add main dataset to root
root.weather = YAXTree("weather", data=ds_weather)  # Add weather node

# Different selection behaviors:
# 1. Non-exclusive - keeps structure, filters variables where found
filtered1 = select_vars(root, ["temperature", "pressure"])
@assert haskey(filtered1.children, "weather")  # weather node remains

# 2. Exclusive - only keeps nodes containing selected variables
filtered2 = select_vars(root, ["temperature"], exclusive=true)
@assert !haskey(filtered2.children, "weather")  # weather node removed

# 3. Exclude specific variables
filtered3 = exclude_vars(root, ["humidity", "wind_speed"])
# Result has temperature and pressure, but not humidity or wind_speed
```

### Excluding Variables from Trees

The `exclude_vars` function provides a way to remove specific variables from datasets in a tree while preserving the tree structure. This is useful when you want to work with a subset of variables by specifying which ones to remove rather than which ones to keep.

```julia
# Basic variable exclusion
filtered_tree = exclude_vars(tree, ["humidity", "wind_speed"])  # using strings
filtered_tree = exclude_vars(tree, [:humidity, :wind_speed])    # using symbols
```

Key features of `exclude_vars`:

1. **Tree Structure Preservation**: The function maintains the original tree structure, only modifying the dataset contents.
2. **Nested Dataset Handling**: Variables are excluded from all datasets in the tree, regardless of their location in the hierarchy.
3. **Variable Type Support**: Works with both String and Symbol variable names.
4. **Node Cleanup**: If all variables are excluded from a dataset, that node's data becomes `nothing`.

Here's a comprehensive example:

```julia
# Create a test tree with nested datasets
root = YAXTree()

# Create main dataset with multiple variables
main_ds = Dataset(
    temperature = YAXArray((Dim{:x}(1:3),), [20.0, 21.0, 22.0]),
    pressure = YAXArray((Dim{:x}(1:3),), [1000.0, 1001.0, 1002.0]),
    humidity = YAXArray((Dim{:x}(1:3),), [0.6, 0.7, 0.8])
)

# Create weather dataset with different variables
weather_ds = Dataset(
    wind_speed = YAXArray((Dim{:x}(1:3),), [5.0, 6.0, 7.0]),
    humidity = YAXArray((Dim{:x}(1:3),), [0.5, 0.6, 0.7])
)

# Build tree structure
root.data = main_ds
root.weather = YAXTree("weather", data=weather_ds)

# Example 1: Exclude a single variable across all nodes
filtered = exclude_vars(root, ["humidity"])
@assert haskey(filtered.data.cubes, :temperature)     # Kept
@assert haskey(filtered.data.cubes, :pressure)        # Kept
@assert !haskey(filtered.data.cubes, :humidity)       # Removed
@assert haskey(filtered.weather.data.cubes, :wind_speed)  # Kept
@assert !haskey(filtered.weather.data.cubes, :humidity)   # Removed

# Example 2: Exclude multiple variables
filtered = exclude_vars(root, ["humidity", "pressure"])
@assert haskey(filtered.data.cubes, :temperature)      # Kept
@assert !haskey(filtered.data.cubes, :pressure)        # Removed
@assert !haskey(filtered.data.cubes, :humidity)        # Removed
@assert haskey(filtered.weather.data.cubes, :wind_speed)  # Kept

# Example 3: Exclude all variables from a node
filtered = exclude_vars(root, ["wind_speed", "humidity"])
@assert haskey(filtered.data.cubes, :temperature)      # Kept
@assert haskey(filtered.data.cubes, :pressure)         # Kept
@assert !haskey(filtered.data.cubes, :humidity)        # Removed
@assert isnothing(filtered.weather.data)               # Node data cleared as all variables excluded
```

Common use cases for `exclude_vars`:
1. Removing unwanted or redundant variables from a dataset
2. Creating a lightweight version of a tree by excluding large or unused variables
3. Cleaning up intermediate processing variables from results
4. Preparing data for export by excluding internal variables

Notes:
- Non-existent variables are silently ignored
- The function operates on all nodes in the tree simultaneously
- The original tree is not modified; a new tree is returned

## Working with Sentinel-3 products

### EOPF format

The new ESA EOPF format aims at providing a generic data interfac that can be used to represent in an homogeneous way the Copernicus Sentinel-1, Sentinel-2 and Sentinel-3 (Land) mission products:
it is a new harmonized data model for the Copernicus products.

See [https://cpm.pages.eopf.copernicus.eu/eopf-cpm/main/eoproduct-user-guide/product_description.html](https://cpm.pages.eopf.copernicus.eu/eopf-cpm/main/eoproduct-user-guide/product_description.html) for a description of the generic product called `EOProduct` and [PSD](https://cpm.pages.eopf.copernicus.eu/eopf-cpm/main/PSFD/index.html) which document the Product Structure and Format Definition.

### Legacy SAFE products

The Standard Archive Format for Europe (SAFE) format specification is the common basis for the Sentinel data products.
It has been designed to act as a common format for archiving and conveying data within ESA Earth Observation archiving facilities.
SAFE was recommended for the harmonisation of the GMES missions by the GMES Product Harmonisation Study.

See [https://sentiwiki.copernicus.eu/web/safe-format](https://sentiwiki.copernicus.eu/web/safe-format) for further details.

`YAXTrees.open_datatree` enable to open a SAFE product and convert it in-memory into an EOPF format. The data representation is the `YAXTree` structure.

