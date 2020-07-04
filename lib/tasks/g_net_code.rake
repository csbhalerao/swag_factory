require "json"

desc 'Generate kotlin data class and endpoints'

task :g_network_code, [:file_name] do |t, args|
  api_details = SwaggerConvertor.new(args).exec
  #puts api_details.to_json
  KotlinCodeGenerator.new(api_details).exec
end

class KotlinCodeGenerator
  attr_reader :api_details

  def initialize(api_dtails)
    @api_details = api_dtails
  end

  def exec()
    return '' if api_details.nil? || api_details.empty?
    api_details.map do |detail|
      #get_endpoint_details(detail)
      puts get_endpoint_details(detail)
    end
  end

  private

  def get_endpoint_details(detail)
    method = http_method(detail[:method])
    url = detail[:url]
    request = detail[:request]
    response = detail[:response]
    chunks = split_url(url)

    interface_str_to_display = interface_name_to_display(chunks)

    url_str_to_display = annotation_url_to_display(method, url)

    function_str_to_display = function_name_to_display(chunks)

    fun_content = function_content(chunks, request)

    #puts request_name

    interface_str_to_display + url_str_to_display + function_str_to_display + fun_content
  end

  def fetch_path_element(chunks)
    path_values = ''
    chunks.each do |element|
      if element.start_with?("{")
        element_without_curly = element.tr('{', '')
        element_without_curly = element_without_curly.tr('}', '')
        element_to_use = element_without_curly.tr('_', '')
        formatted_ele = '"'+element_to_use+'"'
        path_values += "@Path(#{formatted_ele}) #{element_to_use}: String)"
      end
    end
    path_values
  end

  def build_request_class_name(chunks)
    req_str = 'Request'
    return req_str if chunks.nil? || chunks.empty?
    return chunks[0].capitalize + req_str if chunks.length < 2
    last_item = chunks[chunks.length - 1].capitalize
    second_last_item = chunks[chunks.length - 2].capitalize
    last_item = '' if last_item.start_with?("{")
    second_last_item = '' if second_last_item.start_with?("{")
    last_item + second_last_item + req_str
  end

  def build_request_class(class_name) end

  def function_content(chunks, request)
    path_element = fetch_path_element(chunks)
    return ')' if (path_element.nil? || path_element.blank?) && (request.nil? || request.empty?)
    return path_element if request.nil? || request.empty?
    class_name = build_request_class_name(chunks)
    build_request_class(class_name)
    body_req = '@Body req: '
    return path_element + body_req  + class_name + ')' unless path_element.nil?
    body_req + class_name + ')'
  end

  def format_function_name(chunks)
    return 'fun a' if chunks.nil? || chunks.empty?
    return "fun #{chunks[0].capitalize}" if chunks.length < 2
    last_item = chunks[chunks.length - 1]
    second_last_item = chunks[chunks.length - 2].capitalize
    last_item = '' if last_item.start_with?("{")
    second_last_item = '' if second_last_item.start_with?("{")
    second_last_item = second_last_item.downcase if last_item.blank?
    fun_name = last_item + second_last_item
    'fun ' + fun_name.tr('_', '') + '('
  end

  def format_endpoint_class_name(chunks)
    return 'Endpoint' if chunks.nil? || chunks.empty?
    return chunks[0].capitalize + "Endpoint" if chunks.length < 2
    last_item = chunks[chunks.length - 1].capitalize
    second_last_item = chunks[chunks.length - 2].capitalize
    last_item = '' if last_item.start_with?("{")
    second_last_item = '' if second_last_item.start_with?("{")
    last_item + second_last_item + 'Endpoint'
  end

  def split_url(url)
    url.split('/')
  end

  def http_method(method)
    "@#{method.upcase}"
  end

  def function_name_to_display(chunks)
    function_name = format_function_name(chunks)
    "#{function_name}"
  end

  def annotation_url_to_display(method, url)
    formatted_url = '("' + url + '")'
    "#{method}#{formatted_url}  \n"
  end

  def interface_name_to_display(chunks)
    class_name = format_endpoint_class_name(chunks)
    "interface  #{class_name} { \n"
  end
end


class SwaggerConvertor
  attr_reader :file_name, :json_data, :component_schemas

  def initialize(file_name)
    @file_name = file_name
    @json_data = json_data_from_file(file_name)
    @component_schemas = json_data['components']['schemas']
  end

  def exec()
    api_details = @json_data['paths']
    path_array = paths(api_details)

    convert_desired_format(api_details, path_array)
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
        items = properties[key]['items']
        properties_items = parse_properties(items)
        if properties_items != nil
          item_keys = get_property_keys(properties_items)
          child = {
              obj: formatted_entities(item_keys, properties_items)
          }
          param.store(:items, child)
        end
      end

      param
    end
  end

  def get_param_body(api_schema)
    return {} if api_schema.nil?
    unless api_schema['$ref'].nil?
      return handle_schema_ref(api_schema)
    end
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
  end

  def handle_schema_ref(api_schema)
    ref = api_schema['$ref']
    strings = ref.split('/')
    component = strings.last
    get_param_body(component_schemas[component])
  end

  def parse_response(api_res)
    return {} if api_res.nil?
    api_res_keys = api_res.keys
    response = parse_success_api_respones(api_res, api_res_keys)
    schema = parse_req_res_schema(response)
    get_param_body(schema)
  end
end
