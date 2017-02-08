module JsonapiCompliable
  module Util
    class RenderOptions
      def self.generate(object, query_hash, overrides = {})
        resolved = object.respond_to?(:resolve) ? object.resolve : object

        options            = {}
        options[:include]  = query_hash[:include]
        options[:jsonapi]  = resolved
        options[:fields]   = query_hash[:fields]
        options.merge!(overrides)
        options[:meta]   ||= {}
        options[:expose] ||= {}
        options[:expose][:extra_fields] = query_hash[:extra_fields]

        if object.respond_to?(:resolve_stats)
          stats = object.resolve_stats
          options[:meta][:stats] = stats unless stats.empty?
        end

        options
      end
    end
  end
end
