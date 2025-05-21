using Logging

@testset "Test ExampleProcessr" begin
    # Temporarily suppress info logging during the test
    logger = global_logger(SimpleLogger(stderr, Logging.Warn))
    try
        # Run through the test_EOTriggering and verify no errors occur
        @test_nowarn EOTriggering.run("resources/payload.toml")
    finally
        # Restore the original logger
        global_logger(logger)
    end
end
