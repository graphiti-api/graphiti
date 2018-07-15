module JsonapiCompliable
  class FilterOperators
    class Catchall
      attr_reader :procs

      def initialize
        @procs = {}
      end

      def method_missing(name, *args, &blk)
        @procs[name] = blk
      end

      def to_hash
        @procs
      end
    end

    def self.build(&blk)
      c = Catchall.new
      c.instance_eval(&blk) if blk
      c.to_hash
    end
  end
end
