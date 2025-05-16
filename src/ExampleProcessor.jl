module ExampleProcessor

import ..YAXTrees: YAXTree
import ..YAXTrees: YAXTrees as YAXT

import ..CopernicusData: get_AWS_config

function processor_step1(inputs::Vector{YAXTree},adfs::Dict{String,Any};kwargs...)::YAXTree
    """
    Runs the first step of the input processing unit
    Parameters
    ----------
    inputs : Vector{YAXTree}
        List of input YAXTrees
    adfs : Dict{String,Any}
        Dictionary of auxiliary data files
    kwargs : Dict{String,Any}
        Additional keyword arguments
    Returns
    -------
    YAXTree
        Processed YAXTree
    """
    @info "Starting Example Processor Step 1"
    
    # Example processing step
    processed = inputs[1] # Placeholder for actual processing logic

    step1_product = YAXTree("step1")


    return step1_product

end
function processor_step2(inputs::Vector{YAXTree},adfs::Dict{String,Any};kwargs...)::YAXTree
    """
    Runs the first step of the input processing unit
    Parameters
    ----------
    inputs : Vector{YAXTree}
        List of input YAXTrees
    adfs : Dict{String,Any}
        Dictionary of auxiliary data files
    kwargs : Dict{String,Any}
        Additional keyword arguments
    Returns
    -------
    YAXTree
        Processed YAXTree
    """
    @info "Starting Example Processor Step 2"
    
    # Example processing step
    processed = inputs[1] # Placeholder for actual processing logic

    step2_product = YAXTree("step2")


    return step2_product

end
function example_processor(inputs::Vector{YAXTree},adfs::Dict{String,Any};kwargs...)
    """
    Runs the input processing unit
    Parameters
    ----------
    inputs : Vector{YAXTree}
        List of input YAXTrees
    adfs : Dict{String,Any}
        Dictionary of auxiliary data files
    kwargs : Dict{String,Any}
        Additional keyword arguments
    Returns
    -------
    YAXTree
        Processed YAXTree
    """
    @info "Starting Example Processor"

    if haskey(kwargs, :cloud_config)
        alias = get(kwargs[:cloud_config], "secret_alias", nothing)
        if !isnothing(alias)
            @info "Initialize AWS config for secret_alias $alias"
            get_AWS_config(alias)
        end
    end

    step1 = processor_step1(inputs,adfs;kwargs...)
    step2 = processor_step2([inputs...,step1],adfs;kwargs...)

    return step2

end
end #end of module