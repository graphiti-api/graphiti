module JsonHelpers
  def ids_for(type)
    json_includes(type).map { |i| i['id'].to_i }
  end

  def json_item
    attrs = json['data']['attributes'] || {}
    attrs['id'] = json['data']['id']
    attrs['_jsonapi_type'] = json['data']['type']
    attrs
  end

  def json_included_types
    json['included'].map { |i| i['type'] }.uniq
  end

  def json_includes(type)
    json['included'].select { |i| i['type'] == type }
  end

  def json_ids
    json['data'].map { |d| d['id'].to_i }
  end

  def json
    JSON.parse(response.body)
  end
end
