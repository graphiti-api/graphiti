module Graphiti
  class Sideload
    HOOK_ACTIONS = [:save, :create, :update, :destroy, :disassociate]
    TYPES = [:has_many, :belongs_to, :has_one, :many_to_many]

    attr_reader :name,
      :parent_resource_class,
      :parent,
      :group_name,
      :link,
      :polymorphic_as

    class_attribute :scope_proc,
      :assign_proc,
      :assign_each_proc,
      :params_proc,
      :pre_load_proc,
      :link_proc

    def initialize(name, opts)
      @name = name
      validate_options!(opts)
      @parent_resource_class = opts[:parent_resource]
      @resource_class = opts[:resource]
      @primary_key = opts[:primary_key]
      @foreign_key = opts[:foreign_key]
      @type = opts[:type]
      @base_scope = opts[:base_scope]
      @readable = opts[:readable]
      @writable = opts[:writable]
      @as = opts[:as]
      @link = opts[:link]
      @single = opts[:single]
      @remote = opts[:remote]
      apply_belongs_to_many_filter if type == :many_to_many

      @description = opts[:description]

      # polymorphic has_many
      @polymorphic_as = opts[:polymorphic_as]
      # polymorphic_belongs_to-specific
      @group_name = opts[:group_name]
      @polymorphic_child = opts[:polymorphic_child]
      @parent = opts[:parent]
      @always_include_resource_ids = opts[:always_include_resource_ids]

      if polymorphic_child?
        parent.resource.polymorphic << resource_class
      end

      if remote?
        @resource_class = create_remote_resource
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

    def create_remote_resource
      remote_url = @remote
      klass = Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::GraphitiAPI
        self.model = OpenStruct
        self.remote = remote_url
        self.validate_endpoints = false
      }
      name = "#{parent_resource_class.name}.#{@name}.remote"
      klass.class_eval("def self.name;'#{name}';end", __FILE__, __LINE__)
      klass
    end

    def errors
      @errors ||= []
    end

    def remote?
      !!@remote
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

    def polymorphic_has_one?
      !!@polymorphic_as
    end

    def polymorphic_has_many?
      !!@polymorphic_as
    end

    def always_include_resource_ids?
      !!@always_include_resource_ids
    end

    def link?
      return true if link_proc

      if @link.nil?
        !!@parent_resource_class.autolink
      else
        !!@link
      end
    end

    def link_filter(parents)
      base_filter(parents)
    end

    def link_extra_fields
      return unless context&.respond_to?(:params)

      extra_fields_name = [association_name, resource.type].find { |param|
        context.params.dig(:extra_fields, param)
      }

      if extra_fields_name
        extra_fields = context.params.dig(:extra_fields, extra_fields_name)
        {resource.type => extra_fields}
      end
    end

    # The parent resource is a remote,
    # AND the sideload is a remote to the same endpoint
    def shared_remote?
      resource.remote? &&
        resource.remote_base_url = parent_resource_class.remote_base_url
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
      raise "Override #assign_each in subclass"
    end

    def type
      @type || raise("Override #type in subclass. Should be one of #{TYPES.inspect}")
    end

    def load_params(parents, query)
      raise "Override #load_params in subclass"
    end

    def description
      return @description if @description.present?
      parent_resource_class.resolve_i18n_field_description(name, field_type: :relationships)
    end

    def base_scope
      if @base_scope
        @base_scope.respond_to?(:call) ? @base_scope.call : @base_scope
      else
        resource.base_scope
      end
    end

    def build_resource_proxy(parents, query, graph_parent)
      params = nil
      opts = nil
      proxy = nil

      with_error_handling Errors::SideloadParamsError do
        params = load_params(parents, query)
        params_proc&.call(params, parents, context)
        return [] if blank_query?(params)

        opts = load_options(parents, query)
        opts[:sideload] = self
        opts[:parent] = graph_parent
      end

      with_error_handling(Errors::SideloadQueryBuildingError) do
        scope = base_scope
        scope[:foreign_key] = foreign_key if remote?
        proxy = resource.class._all(params, opts, scope)
        pre_load_proc&.call(proxy, parents)
      end

      proxy
    end

    def load(parents, query, graph_parent)
      build_resource_proxy(parents, query, graph_parent).to_a
    end

    # Override in subclass
    def infer_foreign_key
      model = parent_resource_class.model
      namespace = namespace_for(model)
      model_name = model.name.gsub("#{namespace}::", "")
      :"#{model_name.underscore}_id"
    end

    def resource
      @resource ||= resource_class.new
    end

    def parent_resource
      @parent_resource ||= parent_resource_class.new
    end

    # See https://github.com/graphiti-api/graphiti/issues/186
    def clear_resources
      @resource = nil
      @parent_resource = nil
    end

    def assign(parents, children)
      track_associated = type == :has_one
      associated = [] if track_associated
      if performant_assign?
        map = child_map(children)
      end

      parents.each do |parent|
        relevant_children = if performant_assign?
          children_for(parent, map) || []
        else
          fire_assign_each(parent, children)
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

    def resolve(parents, query, graph_parent)
      if single? && parents.length > 1
        raise Errors::SingularSideload.new(self, parents.length)
      end

      if self.class.scope_proc
        sideload_scope = fire_scope(parents)
        sideload_scope = Scope.new sideload_scope,
          resource,
          query,
          parent: graph_parent,
          sideload: self,
          sideload_parent_length: parents.length,
          default_paginate: false
        sideload_scope.resolve do |sideload_results|
          fire_assign(parents, sideload_results)
        end
      else
        load(parents, query, graph_parent)
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
      resource_class
      true
    rescue Graphiti::Errors::ResourceNotFound
      false
    end

    private

    def blank_query?(params)
      if (filter = params[:filter])
        if filter.values == [""]
          return true
        end
      end
      false
    end

    def validate_options!(opts)
      if opts[:remote]
        if opts[:resource]
          raise Errors::SideloadConfig.new(@name, opts[:parent_resource], "cannot pass :remote and :resource options together")
        end

        if opts[:link]
          raise Errors::SideloadConfig.new(@name, opts[:parent_resource], "remote sideloads do not currently support :link")
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
      with_error_handling Errors::SideloadAssignError do
        if self.class.assign_proc
          instance_exec(parents, children, &self.class.assign_proc)
        else
          assign(parents, children)
        end
      end
    end

    def with_error_handling(error_class)
      begin
        result = yield
      rescue
        raise error_class.new(parent_resource_class, name)
      end
      result
    end

    def fire_scope(parents)
      parent_ids = ids_for_parents(parents)
      if self.class.scope_proc
        instance_exec(parent_ids, parents, &self.class.scope_proc)
      else
        method = method(:scope)
        if [2, -2].include?(method.arity)
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

    # TODO: call this at runtime to support procs
    def evaluate_flag(flag)
      return false if flag.blank?

      case flag.class.name
      when "Symbol", "String"
        resource.send(flag)
      when "Proc"
        resource.instance_exec(&flag)
      else
        !!flag
      end
    end

    def context
      Graphiti.context[:object]
    end
  end
end
