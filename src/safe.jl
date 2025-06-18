# Define the mappings directory path relative to this file
const MAPPINGS_DIR = joinpath(dirname(@__DIR__), "src", "mappings")

const TYPE_TO_MAPPING = Dict(
    "OL_1_ERR" => joinpath(dirname(@__DIR__), "src", "mappings", "S03OLCERR_mapping.json"),
    "OL_1_EFR" => joinpath(dirname(@__DIR__), "src", "mappings", "S03OLCEFR_mapping.json"),
    "OL_2_LFR" => joinpath(dirname(@__DIR__), "src", "mappings", "S03OLCLFR_mapping.json"),
    "SL_1_RBT" => joinpath(dirname(@__DIR__), "src", "mappings", "S03SLSRBT_mapping.json"),
    "SL_2_FRP" => joinpath(dirname(@__DIR__), "src", "mappings", "S03SLSFRP_mapping.json"),
)