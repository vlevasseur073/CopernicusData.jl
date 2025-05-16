using TOML

export include_toml_in_markdown

function include_toml_in_markdown(filepath::String)

    try
      config = TOML.parsefile(filepath)

    #   markdown_clode_block = """
    #   println("```toml")
      println("$(TOML.print(config))")
    #   println("```")
    #   """

      return nothing
    catch e
        return "Error reading TOML file: $(e)"
    end
end
