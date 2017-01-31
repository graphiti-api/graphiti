module JsonapiCompliable
  module Scoping::Filterable
    def find_filter(name)
      find_filter!(name)
    rescue JsonapiCompliable::Errors::BadFilter
      nil
    end

    def find_filter!(name)
      filter_name, filter_value = \
        dsl.filters.find { |_name, opts| opts[:aliases].include?(name.to_sym) }
      raise JsonapiCompliable::Errors::BadFilter unless filter_name
      if guard = filter_value[:if]
        raise JsonapiCompliable::Errors::BadFilter if dsl.context[:object].send(guard) == false
      end
      { filter_name => filter_value }
    end

    def filter_param
      query_hash[:filter]
    end
  end
end
