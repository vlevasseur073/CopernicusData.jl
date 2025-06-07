using Documenter
using CopernicusData
push!(LOAD_PATH, "../src")
using Plots

makedocs(
    sitename = "CopernicusData.jl",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    modules = [ CopernicusData ],
    pages = [
        "quickstart.md",
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Release Notes" => "release_notes.md",
        "Examples" => Any[
            "Sentinel-3 zarr products" =>"examples.md"
        ],
        "api.md",
    ],
    clean = false,
    remotes = nothing,
    # checkdocs=:exports
    checkdocs=:none
#    repo = Documenter.Remotes.GitHub("vlevasseur073", "CopernicusData.jl")

)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/vlevasseur073/CopernicusData.jl.git",
    devbranch="main"#,
    # push_preview=true #needed for private project
)
