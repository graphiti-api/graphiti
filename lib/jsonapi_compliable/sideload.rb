module JsonapiCompliable
  class Sideload
    HOOK_ACTIONS = [:save, :create, :update, :destroy, :disassociate]
    TYPES = [:has_many, :belongs_to, :has_one, :many_to_many]

    attr_reader :name,
      :resource_class,
      :parent_resource_class,
      :foreign_key,
      :primary_key

    class << self
      attr_reader :scope_proc, :assign_proc, :assign_each_proc
    end

    def initialize(name, opts)
      @name                  = name
      @parent_resource_class = opts[:parent_resource]
      @resource_class        = opts[:resource]
      @primary_key           = opts[:primary_key]
      @foreign_key           = opts[:foreign_key]
      @type                  = opts[:type]
      @base_scope            = opts[:base_scope]
      @readable              = opts[:readable]
      @writable              = opts[:writable]
    end

    def self.scope(&blk)
      @scope_proc = blk
    end

    def self.assign(&blk)
      @assign_proc = blk
    end

    def self.assign_each(&blk)
      @assign_each_proc = blk
    end

    def readable?
      !!@readable
    end

    def writable?
      !!@writable
    end

    def primary_key
      @primary_key ||= :id
    end

    def foreign_key
      @foreign_key ||= infer_foreign_key
    end

    def resource_class
      @resource_class ||= infer_resource_class
    end

    def scope(parents)
      raise "No #scope defined for sideload with name '#{name}'. Make sure to define this in your adapter, or pass a block that defines the scope."
    end

    def assign_each(parent, children)
      raise 'Override #assign_each in subclass'
    end

    # TODO confirm need the if @type
    def type
      @type || raise("Override #type in subclass. Should be one of #{TYPES.inspect}")
    end

    def default_base_scope
    end

    def base_scope
      @base_scope || default_base_scope
    end

    # Override in subclass
    def infer_foreign_key
      model = parent_resource_class.model
      namespace = namespace_for(model)
      model_name = model.name.gsub("#{namespace}::", '')
      :"#{model_name.underscore}_id"
    end

    def resource
      @resource ||= resource_class.new
    end

    def parent_resource
      @parent_resource ||= parent_resource_class.new
    end

    def assign(parents, children)
      associated = []
      parents.each do |parent|
        relevant_children = fire_assign_each(parent, children)
        if relevant_children.is_a?(Array)
          relevant_children.each do |child|
            associated << child
            associate(parent, child)
          end
        else
          associated << relevant_children
          associate(parent, relevant_children)
        end
      end
      (children - associated).each do |unassigned|
        children.delete(unassigned)
      end
    end

    def resolve(parents, query, namespace)
      sideload_scope   = fire_scope(parents)

      sideload_scope   = Scope.new sideload_scope,
        resource,
        query,
        sideload_parent_length: parents.length,
        default_paginate: false,
        namespace: namespace
      sideload_scope.resolve do |sideload_results|
        fire_assign(parents, sideload_results)
      end
    end

    def self.after_save(only: [], except: [], &blk)
      actions = HOOK_ACTIONS - except
      actions = only & actions
      actions = [:save] if only.empty? && except.empty?
      actions.each do |a|
        hooks[:"after_#{a}"] << blk
      end
    end

    def self.hooks
      @hooks ||= {}.tap do |h|
        HOOK_ACTIONS.each do |a|
          h[:"after_#{a}"] = []
          h[:"before_#{a}"] = []
        end
      end
    end

    def self.fire_hooks!(parent, objects, method)
      return unless self.hooks

      hooks = self.hooks[:"after_#{method}"] + self.hooks[:after_save]
      hooks.compact.each do |hook|
        resource.instance_exec(parent, objects, &hook)
      end
    end

    private

    def associate(parent, child)
      parent_resource.associate(parent, child, name, type)
    end

    def disassociate(parent, child)
      parent_resource.disassociate(parent, child, name, type)
    end

    def fire_assign_each(parent, children)
      if self.class.assign_each_proc
        instance_exec(parent, children, &self.class.assign_each_proc)
      else
        assign_each(parent, children)
      end
    end

    def fire_assign(parents, children)
      if self.class.assign_proc
        instance_exec(parents, children, &self.class.assign_proc)
      else
        assign(parents, children)
      end
    end

    def fire_scope(parents)
      if self.class.scope_proc
        instance_exec(parents, &self.class.scope_proc)
      else
        scope(parents)
      end
    end

    def namespace_for(klass)
      namespace = klass.name
      split = namespace.split('::')
      split[0,split.length-1].join('::')
    end

    def infer_resource_class
      namespace = namespace_for(parent_resource.class)
      inferred_name = "#{name.to_s.singularize.classify}Resource"
      klass = "#{namespace}::#{inferred_name}".safe_constantize
      unless klass
        raise Errors::ResourceNotFound.new(parent_resource, name)
      end
      klass
    end
  end
end
