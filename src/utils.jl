using Zarr

function upload_zarr_to_s3(local_zarr_path::String, store::S3Store, base_key::String)
    # Ensure the base_key doesn't end with a slash but has proper structure
    base_key = rstrip(base_key, '/')
    
    # Walk through the Zarr directory structure
    for (root, _, files) in walkdir(local_zarr_path)
        for file in files
            # Get the full local file path
            local_file_path = joinpath(root, file)
            
            # Calculate the relative path from the Zarr root
            rel_path = replace(local_file_path, local_zarr_path => "")
            rel_path = lstrip(rel_path, '/')
            
            # Create the S3 object key by combining base_key with the relative path
            s3_key = joinpath(base_key, rel_path)
            
            # Read the file content
            content = read(local_file_path)
            
            # Determine content type based on file extension/name
            content_type = if endswith(file, ".json") || file == ".zarray" || file == ".zgroup"
                "application/json"
            else
                # For chunk data
                "application/octet-stream"
            end
            
            # Upload the file to S3
            try
                store[s3_key] = content
                @debug "Uploaded $rel_path ($local_file_path) to s3://$store.bucket/$s3_key"
            catch e
                @error "Error uploading $rel_path ($local_file_path), $s3_key: $e"
            end
        end
    end
    
    @info "Zarr dataset upload complete: s3://$store.bucket/$base_key"
end

function upload_to_s3(file_path, bucket, key; content_type=nothing, metadata=Dict())
    try
        # Determine content type if not provided
        if content_type === nothing
            # Simple content type determination based on extension
            ext = lowercase(split(file_path, '.')[end])
            content_type = if ext == "txt"
                "text/plain"
            elseif ext in ["jpg", "jpeg"]
                "image/jpeg"
            elseif ext == "png"
                "image/png"
            elseif ext == "pdf"
                "application/pdf"
            else
                "application/octet-stream"
            end
        end
        
        # Read file
        open(file_path, "r") do file
            content = read(file)
            
            # Build params dictionary
            params = Dict(
                "body" => content,
                "Content-Type" => content_type,
                "Content-Length" => length(content)
            )
            
            # Add any custom metadata
            for (key, value) in metadata
                params["x-amz-meta-$key"] = string(value)
            end
            
            # Upload to S3
            response = S3.put_object(bucket, key, params)
            @info "Successfully uploaded $(file_path) to s3://$(bucket)/$(key)"
            return response
        end
    catch e
        @error "Error uploading $(file_path) to S3: $e"
        rethrow(e)
    end
end
