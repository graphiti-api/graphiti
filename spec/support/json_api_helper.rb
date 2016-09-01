RSpec::Matchers.define :have_all_keys_tested do |keys|
  match do |payload|
    payload.keys.all? { |k| keys.map(&:to_s).include?(k) }
  end
  failure_message do |payload|
    <<-STR
Expected that payload would have all keys tested.

The following are keys that were returned as part of the
payload, but not tested:

#{payload.keys.map(&:to_s) - keys.map(&:to_s)}
    STR
  end
end

RSpec::Matchers.define :have_payload_slice do |slice|
  match do |actual|
    actual == slice.values.first
  end
  failure_message do |actual|
    <<-STR
Expected that key '#{slice.keys.first}' would be #{slice.values.first.inspect}, got #{actual.inspect}"
    STR
  end
end

RSpec::Matchers.define :have_key_present do |key|
  match do |actual|
    !actual[key].nil?
  end
  failure_message do |_actual|
    <<-STR
Expected key '#{key}' to be present.
    STR
  end
end

module JSONAPIHelper
  def json
    JSON.parse(response.body)
  end

  def json_items(*indices)
    collection = if indices.compact.present?
                   indices.map do |i|
                     json['data'][i]['attributes']
                   end
                 else
                   json['data'].map { |d| d['attributes'] }
                 end
    collection = collection.first if indices.present? and collection.length == 1
    collection
  end

  def json_ids
    json['data'].map { |d| d['id'] }.map(&:to_i)
  end

  def json_item_by_id(id)
    json['data'].find { |d| d['id'] == id }['attributes']
  end

  def json_related_link(payload, assn_name)
    link = payload['relationships'][assn_name]['links']['related']['href']
    fail "link for #{assn_name} not found" unless link
    URI.decode(link)
  end

  def json_item(index = nil)
    if json['data'].is_a?(Array)
      json_items(index).first
    else
      json['data']['attributes']
    end
  end

  def json_includes(type, attr = nil)
    if includes = json['included']
      includes.select! { |incl| incl['type'] == type }

      includes.map do |i|
        if attr
          if attr == :id
            i['id']
          else
            i['attributes'][attr]
          end
        else
          i['attributes']
        end
      end
    end
  end

  def json_included_types
    (json['included'] || []).map { |i| i['type'] }.uniq
  end

  def json_include(type)
    json_includes(type).first
  end

  class AttributeAssertion
    attr_reader :keys_asserted

    def initialize(context, payload)
      @context  = context
      @payload  = payload
      @keys_asserted = []
      @no_keys_asserted = []
    end

    def timestamps!(&blk)
      payload = @payload
      @context.instance_eval do
        record = instance_eval(&blk)
        expect(payload['created_at']).to eq(record.created_at.as_json)
        expect(payload['updated_at']).to eq(record.updated_at.as_json)
      end
      @keys_asserted |= %w(created_at updated_at)
    end

    def key(name, missing: false, allow_nil: false, &blk)
      return if @keys_asserted.include?(name.to_s) # already asserted

      if missing
        payload = @payload
        @context.instance_eval do
          expect(payload).to_not have_key(name.to_s)
        end
        @keys_asserted << name.to_s
      else
        assert_key(@context, name.to_s, @payload, blk, allow_nil)
        @keys_asserted << name.to_s
      end
    end

    def includes(name, record)
      instance_exec(record, &JsonPayload.registry[name])
    end

    private

    def assert_key(context, key, payload, prc, allow_nil)
      context.instance_eval do
        expect(payload).to have_key_present(key) unless allow_nil
        expect(payload[key])
          .to have_payload_slice(key => instance_eval(&prc))
      end
    end
  end

  def assert_attributes(payload, &blk)
    assertion = AttributeAssertion.new(self, payload)
    assertion.instance_eval(&blk)
    expect(payload).to have_all_keys_tested(assertion.keys_asserted)
  end

  def assert_record_payload(name, record, payload, &blk)
    unless JsonPayload.registry[name]
      raise "No assertions registered for #{name}"
    end

    assert_attributes(payload) do
      instance_exec(record, &blk) if blk
      instance_exec(record, &JsonPayload.registry[name])
    end
  end
end
