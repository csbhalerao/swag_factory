require "json"

desc 'Generate kotlin data class and endpoints'

task :g_network_code, [:file_name] do |t, args|
  json_data = json_data_from_file(args)
  schemas = json_data['components']['schemas']
  schema_keys = get_schema_keys(schemas)

  api_details = json_data['paths']
  path_array = paths(api_details)

  f_api_details = convert_desired_format(api_details, path_array)

  puts f_api_details.to_json
end

private_methods

def get_property_keys(properties)
  properties.keys
end

def get_schema_keys(schemas)
  schemas.keys
end

def paths(api_details)
  api_details.keys
end

def parse_request_body(data, method)
  return {} if data.nil?
  return {} if data[method].nil?
  data[method]['requestBody']
end

def parse_response_body(data, method)
  return {} if data.nil?
  return {} if data[method].nil?
  data[method]['responses']
end

def parse_properties(data)
  data['properties']
end

def parse_req_res_schema(data)
  data['content']['application/json']['schema']
end

def parse_success_api_respones(api_res, api_res_keys)
  return api_res['200'] if api_res_keys.include?('200')
  return api_res['201'] if api_res_keys.include?('201')
  {}
end

def get_http_method(api)
  return 'post' if api.keys.include?('post')
  return 'get' if api.keys.include?('get')
  return 'put' if api.keys.include?('put')
  return 'patch' if api.keys.include?('patch')
  return 'delete' if api.keys.include?('delete')
  ''
end

def json_data_from_file(args)
  json_string = File.read(args[:file_name])
  JSON.parse(json_string)
end

def convert_desired_format(api_details, path_array)
  path_array.map do |path|
    api = api_details[path]
    api_info = {}
    method = get_http_method(api)
    req_body = parse_request_body(api, method)
    unless req_body.nil? || req_body.blank?
      api_schema = parse_req_res_schema(req_body)
      api_info.store(:request, get_param_body(api_schema))
    end
    res_body = parse_response_body(api, method)
    unless res_body.nil? || res_body.blank?
      body = parse_response(res_body)
      api_info.store(:response, body)
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
    if properties[key]['type'] == 'object'
      param.store(:obj, get_param_body(properties[key]))
    end

    if properties[key]['type'] == 'array'
      param.store(:items, get_param_body(properties[key]))
    end

    param
  end
end

def get_param_body(api_schema)
  return {} if api_schema.nil?

  type = api_schema['type']
  if type != 'object' && type != 'array'
    return []
  end
  if type == 'object'
    properties = parse_properties(api_schema)
    if properties != nil
      keys = get_property_keys(properties)
      return formatted_entities(keys, properties)
    end
  end
  if type == 'array'
    get_param_body(api_schema['type']['items'])
  end
end

def parse_response(api_res)
  puts(__method__)
  return {} if api_res.nil?
  api_res_keys = api_res.keys
  response = parse_success_api_respones(api_res, api_res_keys)
  #puts(response)
  schema = parse_req_res_schema(response)
  get_param_body(schema)
end
