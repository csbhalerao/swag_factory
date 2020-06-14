require "json"

desc 'Generate kotlin data class and endpoints'

task :g_network_code, [:file_name] do |t, args|
  json_data = jsonDataFromFile(args)
  schemas = json_data['components']['schemas']
  schema_keys = getSchemaKeys(schemas)

  api_details = json_data['paths']
  path_array = paths(api_details)

  f_api_details = convert_desired_format(api_details, path_array)

  puts f_api_details.to_json
end

private_methods

def get_property_keys(properties)
  properties.keys
end

def getSchemaKeys(schemas)
  schemas.keys
end

def paths(api_details)
  api_details.keys
end

def parse_request_body(data, method)
  data[method]['requestBody']
end

def parse_properties(data)
  data['properties']
end

def parse_api_schema(data)
  data['content']['application/json']['schema']
end

def get_http_method(api)
  http_method = ''
  http_method = 'post' if api.keys.include?('post')
  http_method = 'get' if api.keys.include?('get')
  http_method = 'put' if api.keys.include?('put')
  http_method = 'patch' if api.keys.include?('patch')
  http_method = 'delete' if api.keys.include?('delete')
  http_method
end

def jsonDataFromFile(args)
  json_string = File.read(args[:file_name])
  JSON.parse(json_string)
end

def convert_desired_format(api_details, path_array)
  path_array.map do |path|
    api = api_details[path]
    api_info = {}
    method = get_http_method(api)
    req_body = parse_request_body(api, method)
    unless req_body.nil?
      api_schema = parse_api_schema(req_body)
      api_info.store(:request, get_request_body(api_schema))
    end

    api_info.store(:url, path)
    api_info.store(:method, method)
    api_info
  end
end

def formatted_entities(keys, properties)
  keys.map do |key|
    param = {}
    param.store(:name, key)
    param.store(:type, properties[key]['type'])
    param
  end
end

def get_request_body(api_schema)
  type = api_schema['type']
  if type != 'object'
    return []
  end
  properties = parse_properties(api_schema)
  keys = get_property_keys(properties)
  formatted_entities(keys, properties)
end
