module Graphiti
  module Util
    module Cursor
      def self.encode(parts)
        parts.each do |part|
          part[:value] = part[:value].iso8601(6) if part[:value].is_a?(Time)
        end
        Base64.encode64(parts.to_json)
      end

      def self.decode(resource, cursor)
        parts = JSON.parse(Base64.decode64(cursor)).map(&:symbolize_keys)
        parts.each do |part|
          part[:attribute] = part[:attribute].to_sym
          config = resource.get_attr!(part[:attribute], :sortable, request: true)
          value = part[:value]
          part[:value] = if config[:type] == :datetime
            Dry::Types["json.date_time"][value].iso8601(6)
          else
            resource.typecast(part[:attribute], value, :sortable)
          end
        end
        parts
      end
    end
  end
end
