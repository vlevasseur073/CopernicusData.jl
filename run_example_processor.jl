using CopernicusData
using TOML

# Run through the triggering process
payload_file = "resources/payload.toml"
@time p = EOTriggering.run(payload_file)

# Run manually the first workflow
payload_file = "resources/payload.toml"
payload = TOML.parsefile(payload_file)
## Get ADFs
adfs = Dict{String, Any}()
for adf in payload["workflow"][1]["parameters"]["aux_files"]
    id = pop!(adf,"id")
    adfs[id] = adf
end
## Get input
inputs = Vector{Dict{String, Any}}()
for id in payload["workflow"][1]["inputs"]
    for p in payload["I/O"]["inputs_products"]
        if p["id"] == id
            push!(inputs, p)
        end
    end
end
@debug adfs
@debug inputs

dt = open_datatree(inputs[1]["path"], name=inputs[1]["id"])
kwargs = Dict()
kwargs[:start_time] = "2019-12-27T12:41:00.000"
kwargs[:stop_time] = "2019-12-27T12:44:00.000"
res = ExampleProcessor.example_processor([dt],adfs;kwargs...)
