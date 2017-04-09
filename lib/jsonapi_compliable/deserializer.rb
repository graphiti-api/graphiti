class JsonapiCompliable::Deserializer
  def initialize(payload, env)
    @payload = payload
    @env = env
  end

  def data
    @payload[:data]
  end

  def id
    data[:id]
  end

  def attributes
    @attributes ||= raw_attributes.tap do |hash|
      hash.merge!(id: id) if id
    end
  end

  def attributes=(attrs)
    @attributes = attrs
  end

  def method
    case @env['REQUEST_METHOD']
      when 'POST' then :create
      when 'PUT', 'PATCH' then :update
      when 'DELETE' then :destroy
    end
  end

  def meta
    {
      type: data[:type],
      temp_id: data[:'temp-id'],
      method: method
    }
  end

  def relationships
    @relationships ||= process_relationships(raw_relationships)
  end

  def included
    @payload[:included] || []
  end

  def include_directive(memo = {}, relationship_node = nil)
    relationship_node ||= relationships

    relationship_node.each_pair do |name, relationship_payload|
      arrayified = [relationship_payload].flatten
      next if arrayified.all? { |rp| removed?(rp) }

      memo[name] ||= {}
      deep_merge!(memo[name], sub_directives(memo[name], arrayified))
    end

    memo
  end

  private

  def removed?(relationship_payload)
    method = relationship_payload[:meta][:method]
    [:disassociate, :destroy].include?(method)
  end

  def sub_directives(memo, relationship_payloads)
    {}.tap do |subs|
      relationship_payloads.each do |rp|
        sub_directive = include_directive(memo, rp[:relationships])
        deep_merge!(subs, sub_directive)
      end
    end
  end

  def deep_merge!(a, b)
    JsonapiCompliable::Util::Hash.deep_merge!(a, b)
  end

  def process_relationships(relationship_hash)
    {}.tap do |hash|
      relationship_hash.each_pair do |name, relationship_payload|
        name = name.to_sym

        if relationship_payload[:data]
          hash[name] = process_relationship(relationship_payload[:data])
        end
      end
    end
  end

  def process_relationship(relationship_data)
    if relationship_data.is_a?(Array)
      relationship_data.map do |rd|
        process_relationship_datum(rd)
      end
    else
      process_relationship_datum(relationship_data)
    end
  end

  def process_relationship_datum(datum)
    temp_id = datum[:'temp-id']
    included_object = included.find do |i|
      next unless i[:type] == datum[:type]

      (i[:id] && i[:id] == datum[:id]) ||
        (i[:'temp-id'] && i[:'temp-id'] == temp_id)
    end
    included_object ||= {}
    included_object[:relationships] ||= {}

    attributes = included_object[:attributes] || {}
    attributes[:id] = datum[:id] if datum[:id]
    relationships = process_relationships(included_object[:relationships] || {})


    {
      meta: {
        jsonapi_type: datum[:type],
        temp_id: temp_id,
        method: datum[:method].try(:to_sym)
      },
      attributes: attributes,
      relationships: relationships
    }
  end

  def raw_attributes
    data[:attributes] || {}
  end

  def raw_relationships
    data[:relationships] || {}
  end
end
