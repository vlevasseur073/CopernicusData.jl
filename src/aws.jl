using AWS
using AWS: @service
using IniFile

@service S3

struct CustomAWSConfig <: AbstractAWSConfig
    endpoint::String
    region::String
    creds
end

AWS.region(c::CustomAWSConfig) = c.region
AWS.credentials(c::CustomAWSConfig) = c.creds

function AWS.generate_service_url(aws::CustomAWSConfig, service::String, resource::String)
    service == "s3" || throw(ArgumentError("CustomAWSConfig Can only handle s3 requests"))
    return string(aws.endpoint, resource)
end

function get_ini_value(
    ini_file::String, profile::AbstractString, key::AbstractString; default_value=nothing
    )
    ini = Inifile()
    read(ini,ini_file)

    value = get(ini, "profile $profile", key)
    value === :notfound && (value = get(ini, profile, key))
    value === :notfound && (value = default_value)

    return value
end

"""
    function get_AWS_config(profile::String="default")

Generate and AWS config given a profile name.
To get the credentials, the function follows the priority as:
1- get aws config and credentials file as INI files in default path: ~/.aws
2- use environement varialbes (AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID, ...)
"""
function get_AWS_config(profile::String="default")
    aws_path = joinpath(homedir(),".aws")
    if ispath(aws_path)
        endpoint_url = get_ini_value(joinpath(aws_path,"config"), profile, "endpoint_url")
        region = get_ini_value(joinpath(aws_path,"config"), profile, "region")
        creds = AWSCredentials(;profile=profile)
        
    else
        @warn "AWS configuration is not available under $aws_path"
        @warn "Try to continue with environment variables"

        creds = AWSCredentials()
        try
            endpoint_url = ENV["AWS_ENDPOINT_URL"]
            region = ENV["AWS_DEFAULT_REGION"]
        catch e
            @error "Could not find full AWS configuration (endpoint_url or default_region)"
        end
    end
    config = AWS.global_aws_config(CustomAWSConfig(endpoint_url, region, creds))
    
    return config
end

function s3_list_bucket(full_path::String)
"""
    function s3_list_bucket(full_path::String)

Get list of objects in a S3 bucket path: "s3://bucket/Folder/"
"""
    if !startswith(full_path,"s3://")
        @error "Path is not an S3 bucket: $full_path"
        throw(ErrorException("Path is not an S3 bucket"))
    end
    path = replace(full_path,"s3://"=>"")
    folders = split(path,"/")
    bucket = folders[1]
    pattern = joinpath(folders[2:end])
    if isempty(pattern)
        S3.list_objects(bucket)
    else
        S3.list_objects(bucket, Dict("prefix"=>pattern))
    end
end

"""
function s3_get_object(full_path::String)
    Get and object from a S3 bucket given its full path (s3://....)
"""
function s3_get_object(full_path::String)
    if !startswith(full_path,"s3://")
        @error "Path is not an S3 bucket: $full_path"
        throw(ErrorException("Path is not an S3 bucket"))
    end

    path = replace(full_path,"s3://"=>"")
    folders = split(path,"/")
    bucket = folders[1]
    key = joinpath(folders[2:end])
    S3.get_object(bucket,key)

end