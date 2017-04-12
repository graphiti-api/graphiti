module JsonapiCompliable
  class Sideload
    attr_reader :name,
      :resource_class,
      :polymorphic,
      :polymorphic_groups,
      :sideloads,
      :scope_proc,
      :assign_proc,
      :grouper,
      :foreign_key,
      :primary_key,
      :type

    def initialize(name, type: nil, resource: nil, polymorphic: false, primary_key: :id, foreign_key: nil)
      @name               = name
      @resource_class     = (resource || Class.new(Resource))
      @sideloads          = {}
      @polymorphic        = !!polymorphic
      @polymorphic_groups = {} if polymorphic?
      @primary_key        = primary_key
      @foreign_key        = foreign_key
      @type               = type

      extend @resource_class.config[:adapter].sideloading_module
    end

    def resource
      @resource ||= resource_class.new
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

    def associate(parent, child)
      resource_class.config[:adapter].associate(parent, child, name, type)
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
    # To prevent circular relationships (author resource sideloads
    # books and books resource sideloads authors), this allows
    # sideloading up to 10 levels deep into the nesting of relationships
    # We may want to make this configurable (possible at runtime), or
    # maybe there is a better pattern here
    def to_hash(levels_deep = 0)
      levels_deep += 1
      return {} if levels_deep == 10

      { name => {} }.tap do |hash|
        @sideloads.each_pair do |key, sideload|
          hash[name][key] = sideload.to_hash(levels_deep)[key] || {}

          if sideload.polymorphic?
            sideload.polymorphic_groups.each_pair do |type, sl|
              hash[name][key].merge!(nested_sideload_hash(sl, levels_deep))
            end
          else
            hash[name][key].merge!(nested_sideload_hash(sideload, levels_deep))
          end
        end
      end
    end

    private

    def nested_sideload_hash(sideload, levels_deep)
      {}.tap do |hash|
        if sideloading = sideload.resource_class.sideloading
          hash.merge!(sideloading.to_hash(levels_deep)[:base])
        end
      end
    end

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
      sideload_scope   = Scope.new(sideload_scope, resource_class.new, query, default_paginate: false, namespace: namespace)
      sideload_results = sideload_scope.resolve
      assign_proc.call(parents, sideload_results)
    end
  end
end
