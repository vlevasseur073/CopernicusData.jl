using CopernicusData
using Documenter

DocMeta.setdocmeta!(CopernicusData, :DocTestSetup, :(using CopernicusData); recursive=true)

makedocs(;
    modules=[CopernicusData],
    authors="Vincent Levasseur <vince.levasseur@protonmail.com> and contributors",
    sitename="CopernicusData.jl",
    format=Documenter.HTML(;
        canonical="https://vlevasseur073.github.io/CopernicusData.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/vlevasseur073/CopernicusData.jl",
    devbranch="main",
)
