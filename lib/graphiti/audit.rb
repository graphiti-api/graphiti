module Graphiti
  # Resources register themselves as they load, so eager load before auditing.
  class Audit
    Finding = Struct.new(:severity, :check, :message, :remedy) do
      def error?
        severity == :error
      end
    end

    Row = Struct.new(
      :resource,
      :relationship,
      :type,
      :target,
      :resource_ids_source,
      :resource_ids_source_if_always,
      :resource_ids_default,
      :resource_ids_blocker,
      :preloaded,
      :options,
      :findings
    ) do
      def would_start_loading?
        return false if resource_ids_default == :never

        resource_ids_source != :load && resource_ids_source_if_always == :load
      end

      def severity
        return :error if findings.any?(&:error?)
        findings.empty? ? :ok : :warning
      end

      def error?
        severity == :error
      end
    end

    def self.run(resources = nil)
      new(resources).run
    end

    def self.findings(resources = nil)
      run(resources).flat_map(&:findings)
    end

    def initialize(resources = nil)
      @resources = resources || Graphiti.resources.reject(&:abstract_class?)
    end

    def run
      @resources.sort_by { |resource| resource.name.to_s }.flat_map { |resource| rows_for(resource) }
    end

    private

    def rows_for(resource_class)
      model = inferred_model(resource_class)

      resource_class.sideloads.map do |name, sideload|
        row_for(resource_class, name, sideload, model)
      end
    end

    def row_for(resource_class, name, sideload, model)
      source = resource_ids_source(sideload)

      Row.new(
        resource: resource_class.name,
        relationship: name,
        type: sideload.type,
        target: target_name(sideload),
        resource_ids_source: source,
        resource_ids_source_if_always: resource_ids_source_if_always(resource_class, sideload),
        resource_ids_default: resource_class.belongs_to_resource_ids_by_default,
        resource_ids_blocker: sideload.resource_ids_blocker,
        preloaded: (source == :load) ? association_preloaded?(resource_class, sideload) : nil,
        options: declaration_options(sideload),
        findings: [
          missing_association_method(sideload, model),
          missing_guard_method(resource_class, sideload),
          missing_sideload_filter(sideload)
        ].compact
      )
    rescue => error
      Row.new(
        resource: resource_class.name,
        relationship: name,
        type: sideload.type,
        resource_ids_source: :none,
        options: {},
        findings: [
          Finding.new(
            severity: :error,
            check: :broken_relationship,
            message: "#{error.class}: #{error.message.strip.lines.first.to_s.strip}"
          )
        ]
      )
    end

    def declaration_options(sideload)
      options = sideload.non_default_options
      options[:base_scope] = "..." if sideload.customized_base_scope?
      options[:scope] = "..." if sideload.class.scope_proc
      options[:params] = "..." if sideload.class.params_proc
      options
    end

    def resource_ids_source(sideload)
      return :none unless sideload.render_resource_ids?

      sideload.resource_ids_blocker.nil? ? :key : :load
    end

    def resource_ids_source_if_always(resource_class, sideload)
      original = resource_class.belongs_to_resource_ids_by_default
      resource_class.belongs_to_resource_ids_by_default = :always
      resource_ids_source(sideload)
    ensure
      resource_class.belongs_to_resource_ids_by_default = original
    end

    def target_name(sideload)
      if sideload.type == :polymorphic_belongs_to
        children = sideload.children.values.filter_map { |child| short_name(child) }
        return children.empty? ? nil : children.join(", ")
      end

      sideload.resource.class.name
    rescue
      nil
    end

    def short_name(sideload)
      sideload.resource.class.name&.split("::")&.last
    rescue
      nil
    end

    def inferred_model(resource_class)
      model = resource_class.model
      model.is_a?(Class) ? model : nil
    rescue Errors::ModelNotFound
      nil
    end

    def missing_association_method(sideload, model)
      return unless model
      return if sideload.type == :polymorphic_belongs_to
      return if model.method_defined?(sideload.association_name)
      return if model.private_method_defined?(sideload.association_name)

      Finding.new(
        severity: :error,
        check: :missing_association_method,
        message: "#{model.name} has no ##{sideload.association_name} method",
        remedy: "define it, point the relationship at the real association with `as:`, or remove the relationship"
      )
    end

    def missing_guard_method(resource_class, sideload)
      guard = sideload.readable_guard_name
      return unless guard
      return if defines?(resource_class, guard)
      return if defines?(sideload.resource.class, guard)

      Finding.new(
        severity: :error,
        check: :missing_guard_method,
        message: "##{guard} is defined on neither #{resource_class.name} nor its related resource",
        remedy: "define the guard on either resource"
      )
    end

    def defines?(resource_class, method_name)
      resource_class.method_defined?(method_name) ||
        resource_class.private_method_defined?(method_name)
    end

    def missing_sideload_filter(sideload)
      return if builds_its_own_query?(sideload)

      key = sideload_filter_key(sideload)
      return unless key

      related = sideload.resource.class
      return if related.filters.key?(key)

      Finding.new(
        severity: :error,
        check: :missing_sideload_filter,
        message: "#{related.name} is missing `filter #{key.inspect}`",
        remedy: "declare the filter on the related resource"
      )
    end

    def builds_its_own_query?(sideload)
      sideload.class.params_proc || sideload.class.scope_proc
    end

    def sideload_filter_key(sideload)
      case sideload.type
      when :has_many, :has_one then sideload.foreign_key
      when :many_to_many then sideload.true_foreign_key
      when :belongs_to then sideload.primary_key
      end
    end

    def association_preloaded?(resource_class, sideload)
      scope = resource_class.new.base_scope
      return nil unless scope.respond_to?(:includes_values)

      preloads = [scope.includes_values, scope.preload_values, scope.eager_load_values]
      association_names(preloads).include?(sideload.association_name.to_sym)
    rescue
      nil
    end

    def association_names(preload_values)
      Array(preload_values).flat_map do |value|
        case value
        when Hash then value.keys.map(&:to_sym)
        when Array then association_names(value)
        else [value.to_sym]
        end
      end
    end
  end
end
