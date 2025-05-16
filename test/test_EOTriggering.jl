using TOML
using Logging

# Mock payload file content
mock_payload = """
[[workflow]]
module = "EOTriggering"
processing_unit = "dummy_processing_unit"
name = "test_unit"
inputs = ["input1"]
parameters = {}

["I/O"]

[["I/O".inputs_products]]
path = "resources/yax.zarr"
id = "input1"

["I/O".output_products]
path = "path/to/output1"
id = "out"

[logging]
level = "Debug"

[breakpoints]
related_unit = "dummy1"
break_mode = "s"
storage = "dummy1.zarr"
store_params = { }
"""

# Write mock payload to a temporary file
function write_mock_payload(content::String)
    file = tempname()
    open(file, "w") do f
        write(f, content)
    end
    return file
end

@testset "EOTriggering Tests" begin
    # Test parse_payload_file
    @testset "parse_payload_file" begin
        file = write_mock_payload(mock_payload)
        payload = EOTriggering.parse_payload_file(file)
        @test payload["workflow"][1]["module"] == "EOTriggering"
        @test payload["I/O"]["inputs_products"][1]["path"] == "resources/yax.zarr"
        @test payload["I/O"]["output_products"]["path"] == "path/to/output1"
        @test payload["breakpoints"]["related_unit"] == "dummy1"
        @test payload["logging"]["level"] == "Debug"
    end

    # Test get_logging_level
    @testset "get_logging_level" begin
        payload = TOML.parse(mock_payload)
        log_level = EOTriggering.get_logging_level(payload)
        @test log_level == Logging.Debug
    end

    # Test processor_run
    @testset "processor_run" begin
        inputs = [YAXTree("input1")]
        adfs = nothing
        result = EOTriggering.processor_run(EOTriggering.dummy_processing_unit, inputs, adfs)
        @test isnothing(result)
    end

    # Test run
    @testset "run" begin
        file = write_mock_payload(mock_payload)
        EOTriggering.run(file)
        @test true # If no errors, the test passes
    end
end