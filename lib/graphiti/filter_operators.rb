module Graphiti
  class FilterOperators
    class Catchall
      attr_reader :procs

      def initialize(resource, type_name, opts)
        @procs = {}
        defaults = resource.adapter.default_operators[type_name] || [:eq]
        if opts[:only]
          defaults = defaults.select { |op| Array(opts[:only]).include?(op) }
        end
        if opts[:except]
          defaults = defaults.reject { |op| Array(opts[:except]).include?(op) }
        end
        defaults.each do |op|
          @procs[op] = nil
        end
      end

      def method_missing(name, *args, &blk)
        @procs[name] = blk
      end
      # rubocop: enable Style/MethodMissingSuper

      def respond_to_missing?(*args)
        true
      end

      def to_hash
        @procs
      end
    end

    def self.build(resource, type_name, opts = {}, &blk)
      c = Catchall.new(resource, type_name, opts)
      c.instance_eval(&blk) if blk
      c.to_hash
    end
  end
end
