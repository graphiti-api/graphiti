module JsonapiCompliable
  class Sideload
    attr_reader :name,
      :resource_class,
      :polymorphic,
      :sideloads,
      :scope_proc,
      :assign_proc,
      :grouper

    def initialize(name, opts)
      @name               = name
      @resource_class     = (opts[:resource] || Class.new(Resource))
      @sideloads          = {}
      @polymorphic        = !!opts[:polymorphic]
      @polymorphic_groups = {} if polymorphic?

      extend @resource_class.config[:adapter].sideloading_module
    end

    def polymorphic?
      @polymorphic == true
    end

    def scope(&blk)
      @scope_proc = blk
    end

    def assign(&blk)
      @assign_proc = blk
    end

    def group_by(&grouper)
      @grouper = grouper
    end

    def resolve(parents, query, namespace = nil)
      namespace ||= name

      if polymorphic?
        resolve_polymorphic(parents, query)
      else
        resolve_basic(parents, query, namespace)
      end
    end

    def allow_sideload(name, opts = {}, &blk)
      sideload = Sideload.new(name, opts)
      sideload.instance_eval(&blk) if blk

      if polymorphic?
        @polymorphic_groups[name] = sideload
      else
        @sideloads[name] = sideload
      end
    end

    def sideload(name)
      @sideloads[name]
    end

    # Grab from nested sideloads, AND resource, recursively
    def to_hash
      { name => {} }.tap do |hash|
        @sideloads.each_pair do |key, sideload|
          hash[name][key] = sideload.to_hash[key]

          if sideloading = sideload.resource_class.sideloading
            hash[name][key].merge!(sideloading.to_hash[:base])
          end
        end
      end
    end

    private

    def resolve_polymorphic(parents, query)
      parents.group_by(&@grouper).each_pair do |group_type, group_members|
        sideload_for_group = @polymorphic_groups[group_type]
        if sideload_for_group
          sideload_for_group.resolve(group_members, query, name)
        end
      end
    end

    def resolve_basic(parents, query, namespace)
      sideload_scope   = scope_proc.call(parents)
      sideload_scope   = Scope.new(sideload_scope, resource_class.new, query, namespace: namespace)
      sideload_results = sideload_scope.resolve
      assign_proc.call(parents, sideload_results)
    end
  end
end
