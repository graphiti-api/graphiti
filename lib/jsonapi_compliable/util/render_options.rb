module JsonapiCompliable
  module Util
    # Generate the options we end up passing to {{http://jsonapi-rb.org jsonapi-rb}}
    # @api private
    class RenderOptions
      def self.generate(object, query_hash, overrides = {})
        resolved = object.respond_to?(:resolve) ? object.resolve : object

        inferrer = ::Hash.new do |h, k|
          names = k.to_s.split('::')
          klass = names.pop
          h[k] = [*names, "Serializable#{klass}"].join('::').safe_constantize
        end

        fields = query_hash[:fields].dup
        extra_fields = query_hash[:extra_fields]

        # Ensure fields doesnt clobber extra fields
        if extra_fields.any? && fields.any?
          extra_fields.each { |k,v| fields[k] = fields[k].to_a + v }
        end

        options            = {}
        options[:class]    = inferrer
        options[:include]  = query_hash[:include]
        options[:jsonapi]  = resolved
        options[:fields]   = fields
        options.merge!(overrides)
        options[:meta]   ||= {}
        options[:expose] ||= {}
        options[:expose][:extra_fields] = extra_fields

        if object.respond_to?(:resolve_stats)
          stats = object.resolve_stats
          options[:meta][:stats] = stats unless stats.empty?
        end

        options
      end
    end
  end
end
