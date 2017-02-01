module JsonapiCompliable
  class Sideload
    attr_reader :name, :resource, :sideloads, :scope_proc, :assign_proc

    def initialize(name, opts)
      @name = name
      @resource = (opts[:resource] || Class.new(Resource)).new
      @sideloads = {}

      extend @resource.adapter.sideloading_module
    end

    def scope(&blk)
      @scope_proc = blk
    end

    def assign(&blk)
      @assign_proc = blk
    end

    def allow_sideload(name, opts = {}, &blk)
      sideload = Sideload.new(name, opts)
      sideload.instance_eval(&blk) if blk
      @sideloads[name] = sideload
    end

    def sideload(name)
      @sideloads[name]
    end

    def to_hash
      { name => {} }.tap do |hash|
        @sideloads.each_pair do |key, sideload|
          hash[name][key] = sideload.to_hash[key]
        end
      end
    end
  end
end
