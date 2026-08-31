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
      translate_deprecated_options!(opts)
      @parent_resource_class = opts[:parent_resource]
      @resource_class_name = opts[:resource]
      @primary_key = opts[:primary_key]
      @foreign_key = opts[:foreign_key]
      @type = opts[:type]
      @base_scope = opts[:base_scope]
      @readable = opts[:readable]
      @writable = opts[:writable]
      @as = opts[:as]
      @link = opts[:link]
      unless @link.nil? || Resource::LINK_MODES.include?(@link)
        raise Errors::InvalidLinkRendering.new(@parent_resource_class, :"#{name} link", @link)
      end
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
      @render_resource_ids = opts[:resource_ids]

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

    ASSIGNING_QUERY = :__graphiti_assigning_query
    private_constant :ASSIGNING_QUERY

    def self.assigning_node(query)
      return yield if query.nil?

      previous = Fiber[ASSIGNING_QUERY]
      Fiber[ASSIGNING_QUERY] = query
      yield
    ensure
      Fiber[ASSIGNING_QUERY] = previous unless query.nil?
    end

    def self.current_assigning_query
      Fiber[ASSIGNING_QUERY]
    end

    def self.assigned?(query, record, association_name)
      query.association_owners.key?([record.object_id, association_name])
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
        self.validate_requests = false
        self.validate_links = false
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
      evaluate_flag @readable
    end

    def writable?
      evaluate_flag @writable
    end

    def guarded?
      dynamic_flag?(@readable) || dynamic_flag?(@writable)
    end

    def readable_guarded?
      dynamic_flag?(@readable)
    end

    def readable_guard_name
      @readable.to_sym if @readable.is_a?(Symbol) || @readable.is_a?(String)
    end

    def non_default_options
      options = {}
      options[:as] = association_name if @as
      options[:primary_key] = primary_key unless primary_key == :id
      options[:single] = true if single?
      options[:remote] = @remote if remote?
      options[:link] = @link unless @link.nil?
      options[:readable] = @readable unless @readable.nil? || @readable == true
      options[:writable] = @writable unless @writable.nil? || @writable == true
      options[:resource_ids] = @render_resource_ids unless @render_resource_ids.nil?
      options
    end

    def customized_base_scope?
      !!@base_scope
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

    # Every check behind the blocker is static sideload configuration, and this
    # is asked once per rendered record per relationship.
    def resource_ids_from_foreign_key?
      return @resource_ids_from_foreign_key unless @resource_ids_from_foreign_key.nil?

      @resource_ids_from_foreign_key = resource_ids_blocker.nil?
    end

    def resource_ids_blocker
      :no_foreign_key_on_parent
    end

    def render_resource_ids?
      return !!@render_resource_ids unless @render_resource_ids.nil?

      default_render_resource_ids?
    end

    def default_render_resource_ids?
      false
    end

    # A custom link block means the author wants the link, so a false default does not silence it.
    def link_mode
      return @link unless @link.nil?

      default = @parent_resource_class.relationship_links
      (link_proc && default == false) ? true : default
    end

    def link?
      link_mode != false
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
      @resource_class ||= (@resource_class_name.is_a?(String) ? @resource_class_name.constantize : @resource_class_name) ||
        infer_resource_class
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

    def load(parents, query, graph_parent, &proxy_block)
      if Scope.resolve_synchronously?
        sync_load(parents, query, graph_parent, &proxy_block)
      else
        future_load(parents, query, graph_parent, &proxy_block).value!
      end
    end

    def sync_load(parents, query, graph_parent, &proxy_block)
      proxy = build_resource_proxy(parents, query, graph_parent)
      proxy_block&.call(proxy)
      proxy.to_a
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

    def resolve(parents, query, graph_parent, &proxy_block)
      if Scope.resolve_synchronously?
        sync_resolve(parents, query, graph_parent, &proxy_block)
      else
        future_resolve(parents, query, graph_parent, &proxy_block).value!
      end
    end

    # Called by a scope that already decided to stay inline, so it must not consult the pool again.
    # A scope_proc builds a Scope rather than a proxy, and that nested scope decides for itself.
    def sync_resolve(parents, query, graph_parent, &proxy_block)
      assert_singular!(parents)

      if self.class.scope_proc
        build_sideload_scope(parents, query, graph_parent).resolve do |sideload_results|
          fire_assign(parents, sideload_results, query)
        end
      else
        sync_load(parents, query, graph_parent, &proxy_block)
      end
    end

    # A scope_proc builds a Scope rather than a proxy, and a Scope's cache key omits what a proxy's carries.
    def future_resolve(parents, query, graph_parent, &proxy_block)
      assert_singular!(parents)

      if self.class.scope_proc
        build_sideload_scope(parents, query, graph_parent).future_resolve do |sideload_results|
          fire_assign(parents, sideload_results, query)
        end
      else
        future_load(parents, query, graph_parent, &proxy_block)
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
      return unless claim_association(parent)

      parent_resource.associate_all(parent, children, association_name, type)
    end

    def associate(parent, child)
      return unless claim_association(parent)

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

    def assert_singular!(parents)
      if single? && parents.length > 1
        raise Errors::SingularSideload.new(self, parents.length)
      end
    end

    def build_sideload_scope(parents, query, graph_parent)
      Scope.new fire_scope(parents),
        resource,
        query,
        parent: graph_parent,
        sideload: self,
        sideload_parent_length: parents.length,
        default_paginate: false
    end

    def future_load(parents, query, graph_parent, &proxy_block)
      proxy = build_resource_proxy(parents, query, graph_parent)
      proxy_block&.call(proxy)
      proxy.respond_to?(:future_resolve_data) ? proxy.future_resolve_data : Concurrent::Promises.fulfilled_future(proxy)
    end

    def blank_query?(params)
      if (filter = params[:filter])
        if filter.values == [""]
          return true
        end
      end
      false
    end

    def translate_deprecated_options!(opts)
      return unless opts.key?(:always_include_resource_ids)

      Graphiti::DEPRECATOR.deprecation_warning(
        :always_include_resource_ids,
        "Use :resource_ids instead (#{opts[:parent_resource]&.name}##{@name})"
      )

      value = opts.delete(:always_include_resource_ids)
      opts[:resource_ids] = value unless opts.key?(:resource_ids)
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
          fire_assign(parents, results, query)
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

    def fire_assign(parents, children, query = nil)
      self.class.assigning_node(query) do
        with_error_handling Errors::SideloadAssignError do
          if self.class.assign_proc
            instance_exec(parents, children, &self.class.assign_proc)
          else
            assign(parents, children)
          end
        end
      end
    end

    # A record can be shared by two nodes of the include tree, and a node that narrows
    # differently returns different rows, so the first node to populate an association owns it.
    def claim_association(parent)
      query = self.class.current_assigning_query
      return true if query.nil?

      key = [parent.object_id, association_name]
      query.association_owners.compute_if_absent(key) { query.hash } == query.hash
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

    def dynamic_flag?(flag)
      flag.is_a?(Symbol) || flag.is_a?(String) || flag.is_a?(Proc)
    end

    # The guard method may be defined on either resource. The declaring side
    # wins (`has_many :positions, readable: :admin?` calls EmployeeResource#admin?,
    # matching how attribute guards resolve). If the related resource is the only place
    # that defines it, the guard runs there. For instance, PositionResource#admin? can guard
    # every relationship that points at positions.

    def evaluate_flag(flag)
      return false if flag.blank?

      case flag
      when Symbol, String
        guard_resource(flag).send(flag)
      when Proc
        evaluate_guard_proc(flag)
      else
        !!flag
      end
    end

    # Private methods are eligible - guards are often not part of a
    # resource's public API.
    def guard_resource(method_name)
      if !parent_resource.respond_to?(method_name, true) &&
          resource.respond_to?(method_name, true)
        resource
      else
        parent_resource
      end
    end

    # A proc can't be introspected the way a method name can, so run it
    # against the declaring resource and only reach for the related one if
    # that resource turns out not to define what the proc references.
    def evaluate_guard_proc(flag)
      parent_resource.instance_exec(&flag)
    rescue NameError => error
      raise error unless resource.respond_to?(error.name, true)
      resource.instance_exec(&flag)
    end

    def context
      Graphiti.context[:object]
    end
  end
end
