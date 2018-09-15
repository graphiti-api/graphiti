module Graphiti
  class Sideload
    HOOK_ACTIONS = [:save, :create, :update, :destroy, :disassociate]
    TYPES = [:has_many, :belongs_to, :has_one, :many_to_many]

    attr_reader :name,
      :resource_class,
      :parent_resource_class,
      :foreign_key,
      :primary_key,
      :parent,
      :group_name,
      :link

    class_attribute :scope_proc,
      :assign_proc,
      :assign_each_proc,
      :params_proc,
      :pre_load_proc,
      :link_proc

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
      @as                    = opts[:as]
      @link                  = opts[:link]
      @single                = opts[:single]
      apply_belongs_to_many_filter if type == :many_to_many

      # polymorphic-specific
      @group_name            = opts[:group_name]
      @polymorphic_child     = opts[:polymorphic_child]
      @parent                = opts[:parent]
      if polymorphic_child?
        parent.resource.polymorphic << resource_class
      end
    end

    def self.scope(&blk)
      self.scope_proc = blk
    end

    def self.assign(&blk)
      self.assign_proc = blk
    end

    def self.assign_each(&blk)
      self.assign_each_proc = blk
    end

    def self.params(&blk)
      self.params_proc = blk
    end

    def self.pre_load(&blk)
      self.pre_load_proc = blk
    end

    def self.link(&blk)
      self.link_proc = blk
    end

    def errors
      @errors ||= []
    end

    def readable?
      !!@readable
    end

    def writable?
      !!@writable
    end

    def single?
      !!@single
    end

    def link?
      return true if link_proc

      if @link.nil?
        !!@parent_resource_class.autolink
      else
        !!@link
      end
    end

    def polymorphic_parent?
      resource.polymorphic?
    end

    def polymorphic_child?
      !!@polymorphic_child
    end

    def primary_key
      @primary_key ||= :id
    end

    def foreign_key
      @foreign_key ||= infer_foreign_key
    end

    def association_name
      @as || name
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

    def type
      @type || raise("Override #type in subclass. Should be one of #{TYPES.inspect}")
    end

    def load_params(parents, query)
      raise 'Override #load_params in subclass'
    end

    def base_scope
      if @base_scope
        @base_scope.respond_to?(:call) ? @base_scope.call : @base_scope
      else
        resource.base_scope
      end
    end

    def load(parents, query)
      params = load_params(parents, query)
      params_proc.call(params, parents) if params_proc
      opts = load_options(parents, query)
      proxy = resource.class._all(params, opts, base_scope)
      pre_load_proc.call(proxy, parents) if pre_load_proc
      proxy.to_a
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
      track_associated = type == :has_one
      associated = [] if track_associated
      if performant_assign?
        map = child_map(children)
      end

      parents.each do |parent|
        if performant_assign?
          relevant_children = children_for(parent, map) || []
        else
          relevant_children = fire_assign_each(parent, children)
        end

        if relevant_children.is_a?(Array)
          associated |= relevant_children if track_associated
          associate_all(parent, relevant_children)
        else
          associated << relevant_children if track_associated && relevant_children
          associate(parent, relevant_children)
        end
      end
      children.replace(associated) if track_associated
    end

    def resolve(parents, query)
      if single? && parents.length > 1
        raise Errors::SingularSideload.new(self, parents.length)
      end

      if self.class.scope_proc
        sideload_scope = fire_scope(parents)
        sideload_scope = Scope.new sideload_scope,
          resource,
          query,
          sideload_parent_length: parents.length,
          default_paginate: false
        sideload_scope.resolve do |sideload_results|
          fire_assign(parents, sideload_results)
        end
      else
        load(parents, query)
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

    def fire_hooks!(parent, objects, method)
      return unless self.class.hooks

      all = self.class.hooks[:"after_#{method}"] + self.class.hooks[:after_save]
      all.compact.each do |hook|
        resource.instance_exec(parent, objects, &hook)
      end
    end

    def associate_all(parent, children)
      parent_resource.associate_all(parent, children, association_name, type)
    end

    def associate(parent, child)
      parent_resource.associate(parent, child, association_name, type)
    end

    def disassociate(parent, child)
      parent_resource.disassociate(parent, child, association_name, type)
    end

    def ids_for_parents(parents)
      parent_ids = parents.map(&primary_key)
      parent_ids.compact!
      parent_ids.uniq!
      parent_ids
    end

    def performant_assign?
      !self.class.assign_each_proc
    end

    # @api private
    def resource_class_loaded?
      begin
        resource_class
        true
      rescue Graphiti::Errors::ResourceNotFound
        false
      end
    end

    private

    def apply_belongs_to_many_filter
      _self = self
      fk_type = parent_resource_class.attributes[:id][:type]
      resource_class.filter true_foreign_key, fk_type do
        eq do |scope, value|
          _self.belongs_to_many_filter(scope, value)
        end
      end
    end

    def load_options(parents, query)
      {}.tap do |opts|
        opts[:default_paginate] = false
        opts[:sideload_parent_length] = parents.length
        opts[:query] = query
        opts[:after_resolve] = ->(results) {
          fire_assign(parents, results)
        }
      end
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
      parent_ids = ids_for_parents(parents)
      if self.class.scope_proc
        instance_exec(parent_ids, parents, &self.class.scope_proc)
      else
        method = method(:scope)
        if [2,-2].include?(method.arity)
          scope(parent_ids, parents)
        else
          scope(parent_ids)
        end
      end
    end

    def infer_resource_class
      Util::Class.infer_resource_class(parent_resource.class, name)
    end

    def namespace_for(klass)
      Util::Class.namespace_for(klass)
    end
  end
end
