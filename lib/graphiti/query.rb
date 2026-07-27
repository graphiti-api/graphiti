require "digest"

module Graphiti
  class Query
    attr_reader :resource, :association_name, :params, :action

    def initialize(resource, params, association_name = nil, nested_include = nil, parents = [], action = nil)
      @resource = resource
      @association_name = association_name
      @params = params
      @params = @params.permit! if @params.respond_to?(:permit!)
      @params = @params.to_h if @params.respond_to?(:to_h)
      @params = @params.deep_symbolize_keys
      @include_param = nested_include || @params[:include]
      @parents = parents
      @action = parse_action(action)
    end

    def association?
      !!@association_name
    end

    def top_level?
      !association?
    end

    def links?
      return false if [:json, :xml, "json", "xml"].include?(params[:format])
      if Graphiti.config.links_on_demand
        [true, "true"].include?(@params[:links])
      else
        true
      end
    end

    def pagination_links?
      if action == :find
        false
      elsif Graphiti.config.pagination_links_on_demand
        [true, "true"].include?(@params[:pagination_links])
      else
        Graphiti.config.pagination_links
      end
    end

    def debug_requested?
      !!@params[:debug]
    end

    def hash
      @hash ||= {}.tap do |h|
        h[:filter] = filters
        h[:sort] = sorts
        h[:page] = pagination
        if association?
          resource_type = @resource.class.type
          h[:extra_fields] = {resource_type => extra_fields[resource_type]} if extra_fields.key?(resource_type)
        else
          h[:fields] = fields
          h[:extra_fields] = extra_fields
        end
        h[:stats] = stats
        h[:include] = sideload_hash
      end.reject { |_, value| value.empty? }
    end

    def zero_results?
      !@params[:page].nil? &&
        !@params[:page][:size].nil? &&
        @params[:page][:size].to_i == 0
    end

    def sideload_hash
      @sideload_hash = {}.tap do |hash|
        sideloads.each_pair do |key, value|
          hash[key] = sideloads[key].hash
        end
      end
    end

    class RemoteSideloadResource < ::Graphiti::Resource
      self.remote = "_remote_sideload_".freeze
      self.abstract_class = true # exclude from schema
    end

    def resource_for_sideload(sideload)
      if @resource.remote?
        RemoteSideloadResource.new
      else
        sideload.resource
      end
    end

    def sideloads
      @sideloads ||= {}.tap do |hash|
        include_hash.each_pair do |key, sub_hash|
          sideload = @resource.class.sideload(key)

          if sideload || @resource.remote?
            sl_resource = resource_for_sideload(sideload)
            query_parents = parents + [self]
            sub_hash = sub_hash[:include] if sub_hash.key?(:include)

            # NB: To handle on__<type>--<name>
            # A) relationship_name == :positions
            # B) key == on__employees.positions
            # This way A) ensures sideloads are resolved
            # And B) ensures nested filters, sorts etc still work
            relationship_name = sideload ? sideload.name : key
            hash[relationship_name] = Query.new sl_resource,
              @params,
              key,
              sub_hash,
              query_parents, :all
          else
            handle_missing_sideload(key)
          end
        end
      end
    end

    def parents
      @parents ||= []
    end

    def fields
      @fields ||= begin
        hash = parse_fieldset(@params[:fields] || {})
        hash.each_pair do |type, fields|
          hash[type] += extra_fields[type] if extra_fields[type]
        end
        hash
      end
    end

    def extra_fields
      @extra_fields ||= parse_fieldset(@params[:extra_fields] || {})
    end

    def filters
      @filters ||= {}.tap do |hash|
        (@params[:filter] || {}).each_pair do |name, value|
          name = name.to_sym

          if legacy_nested?(name)
            value.keys.each do |key|
              filter_name = key.to_sym
              filter_value = value[key]

              if @resource.get_attr!(filter_name, :filterable, request: true)
                hash[filter_name] = filter_value
              end
            end
          elsif nested?(name)
            name = name.to_s.split(".").last.to_sym
            validate!(name, :filterable)
            hash[name] = value
          elsif top_level? && validate!(name, :filterable)
            hash[name] = value
          end
        end
      end
    end

    def sorts
      @sorts ||= begin
        return @params[:sort] if @params[:sort].is_a?(Array)
        return [] if @params[:sort].nil?

        [].tap do |arr|
          sort_hashes do |key, value, type|
            if legacy_nested?(type)
              unless @resource.remote?
                @resource.get_attr!(key, :sortable, request: true)
              end
              arr << {key => value}
            elsif !type && top_level? && validate!(key, :sortable)
              arr << {key => value}
            elsif nested?("#{type}.#{key}")
              arr << {key => value}
            end
          end
        end
      end
    end

    def pagination
      @pagination ||= {}.tap do |hash|
        (@params[:page] || {}).each_pair do |name, value|
          if legacy_nested?(name)
            value.each_pair do |k, v|
              hash[k.to_sym] = cast_page_param(k.to_sym, v)
            end
          elsif nested?(name)
            param_name = name.to_s.split(".").last.to_sym
            hash[param_name] = cast_page_param(param_name, value)
          elsif top_level? && Scoping::Paginate::PARAMS.include?(name.to_sym)
            hash[name.to_sym] = cast_page_param(name.to_sym, value)
          end
        end
      end
    end

    def include_hash
      @include_hash ||= begin
        requested = include_directive.to_hash

        allowlist = nil
        if @resource.context&.respond_to?(:sideload_allowlist)
          allowlist = @resource.context.sideload_allowlist
          allowlist = allowlist[@resource.context_namespace] if allowlist
        end

        allowlist ? Util::IncludeParams.scrub(requested, allowlist) : requested
      end

      @include_hash
    end

    def stats
      @stats ||= {}.tap do |hash|
        (@params[:stats] || {}).each_pair do |k, v|
          if legacy_nested?(k)
            raise NotImplementedError.new("Association statistics are not currently supported")
          elsif top_level?
            v = v.split(",") if v.is_a?(String)
            hash[k.to_sym] = Array(v).flatten.map(&:to_sym)
          end
        end
      end
    end

    def paginate?
      ![false, "false"].include?(@params[:paginate])
    end

    def cache_key
      "args-#{query_cache_key}"
    end

    private

    def query_cache_key
      attrs = {extra_fields: extra_fields,
               fields: fields,
               links: links?,
               pagination_links: pagination_links?,
               format: params[:format]}

      Digest::SHA1.hexdigest(attrs.to_s)
    end

    def cast_page_param(name, value)
      if [:before, :after].include?(name)
        decode_cursor(value)
      else
        value.to_i
      end
    end

    def decode_cursor(cursor)
      JSON.parse(Base64.decode64(cursor)).symbolize_keys
    end

    # Try to find on this resource
    # If not there, follow the legacy logic of scalling all other
    # resource names/types
    # TODO: Eventually, remove the legacy logic
    def validate!(name, flag)
      return false if name.to_s.include?(".") # nested
      return true if @resource.remote?

      if (att = @resource.get_attr(name, flag, request: true))
        att
      else
        not_associated_name = !@resource.class.association_names.include?(name)
        not_associated_type = !@resource.class.association_types.include?(name)

        if not_associated_name && not_associated_type
          @resource.get_attr!(name, flag, request: true)
          return true
        end
        false
      end
    end

    def nested?(name)
      return false unless association?

      split = name.to_s.split(".")
      query_names = split[0..split.length - 2].map(&:to_sym)
      my_names = parents.map(&:association_name).compact + [association_name].compact
      query_names == my_names
    end

    def legacy_nested?(name)
      association? &&
        (name == @resource.type || name == @association_name)
    end

    def parse_fieldset(fieldset)
      {}.tap do |hash|
        fieldset.each_pair do |type, fields|
          type = type.to_sym
          fields = fields.to_s.split(",") unless fields.is_a?(Array)
          hash[type] = fields.map(&:to_sym)
        end
      end
    end

    def include_directive
      @include_directive ||= JSONAPI::IncludeDirective.new(@include_param)
    end

    def handle_missing_sideload(name)
      if Graphiti.config.raise_on_missing_sideload && !@resource.remote?
        raise Graphiti::Errors::InvalidInclude
          .new(@resource, name)
      end
    end

    def sort_hash(attr)
      value = attr[0] == "-" ? :desc : :asc
      key = attr.sub("-", "").to_sym

      {key => value}
    end

    def sort_hashes
      sorts = @params[:sort].split(",")
      sorts.each do |s|
        attr = nil
        type = s
        if s.include?(".")
          split = s.split(".")
          attr = split.pop
          type = split.join(".")
        end

        if attr.nil? # top-level
          next if @association_name
          hash = sort_hash(type)
          yield hash.keys.first.to_sym, hash.values.first
        else
          if type[0] == "-"
            type = type.sub("-", "")
            attr = "-#{attr}"
          end
          hash = sort_hash(attr)
          yield hash.keys.first.to_sym, hash.values.first, type.to_sym
        end
      end
    end

    def parse_action(action)
      action ||= @params.fetch(:action, Graphiti.context[:namespace]).try(:to_sym)
      case action
      when :index
        :all
      when :show
        :find
      else
        action
      end
    end
  end
end
