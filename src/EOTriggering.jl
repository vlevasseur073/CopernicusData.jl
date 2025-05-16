module EOTriggering

using Distributed
using Logging
using TOML
using YAXArrays

import ..EOProducts: EOProduct
import ..YAXTrees: YAXTree, open_datatree

PayloadTag = [
    "workflow",
    "I/O",
    "breakpoints",
    "logging"
]

struct Payload
    workflow
    io_config
    breakpoints
    logging
end

struct PayloadWorkflow
    mod::String
    processing_unit::String
    name::String
    inputs::Vector{String}
    function PayloadWorkflow(d::Dict)
        mod=d["module"]
        processing_unit=d["processing_unit"]
        name=d["name"]
        inputs=d["inputs"]
        new(mod,processing_unit,name,inputs)
    end
end

function dummy_processing_unit(
    inputs::Vector{YAXTree},
    adfs::Union{Nothing,Dict{String,Any}};
    kwargs...
)#::YAXArrays.Dataset
    @info "Hello !"
    # var1=YAXArray(rand(2,2))
    # return YAXArrays.Dataset(var1)
end

function parse_payload_file(file::String)
    TOML.tryparsefile(file)    
end

function get_logging_level(payload::Dict{String, Any})
    if haskey(payload, "logging")
        logging = payload["logging"]
        level = get(logging,"level","Info")
        if level == "Debug"
            return Logging.Debug
        else
            return Logging.Info
        end
    end

    return Logging.Info
end

function processor_run(
    fn::Function,
    inputs::Vector{YAXTree},
    adfs::Union{Dict{String,Any},Nothing}=nothing;
    kwargs...)#::YAXArrays.Dataset
    @debug "processor_run" kwargs
    try
        ret = fn(inputs,adfs;kwargs...)
        return ret
    catch e
        @error e
        throw(e)
    end
    # return fn(inputs,args)
end

function run(file::String)
    payload = parse_payload_file(file)

    # [logging]
    log_level = get_logging_level(payload)
    if log_level == Logging.Debug
        ENV["JULIA_DEBUG"] = parentmodule(EOTriggering)
    end
    @debug "Payload File: " payload

    # [parallel_context]
    # if haskey(payload,"parallel_context")
    #     parallel_context = payload["parallel_context"]
    #     @debug "Parallel context: " parallel_context
    #     processes = get(parallel_context, "processes", 1)
    #     @info "Number of requested processes: " processes
    #     if processes > 1
    #         nprocs = Distributed.nprocs()
    #         if processes - nprocs > 0 
    #             Distributed.addprocs(processes - nprocs)
    #         end
    #     end
    # end
    if !reduce(&,map(x->haskey(payload,x),PayloadTag))
        msg = """Invalid payload file $(file)
              File must contain the following tag $(PayloadTag)"""
        throw(ErrorException(msg))
    end

    # cloud_config
    if haskey(payload, "cloud_config")
        cloud_config = payload["cloud_config"]
    else
        cloud_config = nothing
    end

    io = payload["I/O"]
    inputs = Vector{YAXTree}()
    for item in io["inputs_products"]
        product = item["path"]
        name = item["id"]
        tree_product = open_datatree(product,name=name)
        push!(inputs,tree_product)
    end
    @info "List of inputs: "
    for p in inputs
        if log_level == Logging.Debug
            @debug " - input: $(p.name)" p
        else
            @info " - input: $(p.name)"
        end
    end
    
    workflow = payload["workflow"]
    for w in workflow
        try
            PayloadWorkflow(w)
        catch e
            @error e
        end
    end
    # @info workflow
    for pu in workflow
        workflow_inputs = [p for p in inputs if p.name in pu["inputs"]]
        #TODO
        #Add intermediate inputs from previous PU output. 
        #Input is referenced with the name of the previous PU
        # push!(workflow,output[pu["inputs"]
        name = pu["name"]
        mod = pu["module"]
        process = pu["processing_unit"]
        params = pu["parameters"]
        
        if haskey(params, "aux_files")
            # @show params
            aux_files = pop!(params,"aux_files")
            # @show params
            adfs = Dict{String,Any}()
            for adf in aux_files
                id = pop!(adf,"id")
                adfs[id]  = adf
            end
            # @info adfs
        else
            adfs = nothing
        end
        # @show params
        try
            m = getfield(Main,Symbol(mod))
            fn = getfield(m,Symbol(process))
            if isa(fn,Function)
                @info "Running $(name)($(mod).$(process))"
                if !isnothing(cloud_config)
                    kwargs = merge((cloud_config=cloud_config,),NamedTuple((Symbol(k),v) for (k,v) in params))
                else
                    kwargs = NamedTuple((Symbol(k),v) for (k,v) in params)
                end
                out = processor_run(fn,workflow_inputs,adfs;kwargs...)
                # return fn()
            else
                @error "processing_unit requested in workflow is not a Function $(pu)"
                # throw(TypeError)
            end
        catch e
            if isa(e,UndefVarError)
                @error "Unknown function requested in workflow $(pu)"
                throw(UndefVarError)
            end
        end


    end
end

end # module EOTriggering
