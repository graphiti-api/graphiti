module Graphiti
  class Resource
    module Interface
      extend ActiveSupport::Concern

      class_methods do
        def cache_resource(expires_in: false, tag: nil)
          @cache_resource = true
          @cache_expires_in = expires_in
          @cache_tag = tag
        end

        def all(params = {}, base_scope = nil)
          validate_request!(params)
          _all(params, {}, base_scope)
        end

        # @api private
        def _all(params, opts, base_scope)
          runner = Runner.new(self, params, query: opts.delete(:query), action: :all)
          opts[:params] = params
          runner.proxy(base_scope, opts.merge(caching_options))
        end

        def find(params = {}, base_scope = nil)
          validate_request!(params)
          _find(params, base_scope)
        end

        # @api private
        def public_ids_by(filter_name, keys)
          encode = config[:public_id_encode]
          return keys.to_h { |key| [key, encode.call(key)] } if encode && filter_name == :_primary_key

          attribute = model_attribute_for(filter_name)
          value = (filter_name == :_primary_key) ? Util::InternalParam.new(keys) : keys.join(",")
          translate_ids(filter_name => value).each_with_object({}) do |record, map|
            map[record.send(attribute)] = public_id_for(record)
          end
        end

        # @api private
        # Sqids decodes any string in its alphabet, so "42" yields some unrelated record.
        # A decode only counts if encoding the result gives back the string that was sent.
        def decode_encoded_id(public_id)
          primary_key = config[:public_id_decode].call(public_id)
          return if primary_key.nil?

          primary_key if config[:public_id_encode].call(primary_key) == public_id
        end

        def decode_public_id(public_id)
          decode_public_ids([public_id]).first
        end

        def decode_public_ids(public_ids)
          if config[:public_id_decode]
            return public_ids.map { |public_id| decode_encoded_id(public_id) }.compact
          end

          translate_ids(_public_id: Util::InternalParam.new(public_ids)).map { |record| record.send(model_primary_key) }
        end

        # @api private
        def _find(params = {}, base_scope = nil)
          guard_nil_id!(params[:data])
          guard_nil_id!(params)

          id = params[:data].try(:[], :id) || params.delete(:id)
          params[:filter] ||= {}
          params[:filter][:id] = id if id

          runner = Runner.new(self, params, action: :find)

          find_options = {
            single: true,
            raise_on_missing: true,
            bypass_required_filters: true
          }.merge(caching_options)

          runner.proxy base_scope, find_options
        end

        def build(params, base_scope = nil)
          validate_request!(params)
          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true, raise_on_missing: true, assign_action: :create)
        end

        # Wrap models fetched outside graphiti so they render like any other proxy
        def wrap(models, base_scope = nil)
          validate_wrap_models!(models)
          runner = Runner.new(self, {}, action: :find)
          runner.proxy(base_scope, bypass_required_filters: true).tap do |proxy|
            proxy.data = models
          end
        end

        private

        # Skip polymorphic parents - resource_for_model raises a better error for unknown children
        def validate_wrap_models!(models)
          return if abstract_class? || (polymorphic? && !polymorphic_child?)

          [models].flatten.compact.each do |model|
            unless model.is_a?(self.model)
              raise Errors::InvalidWrapModel.new(self, model)
            end
          end
        end

        def caching_options
          {cache: @cache_resource, cache_expires_in: @cache_expires_in, cache_tag: @cache_tag}
        end

        def translate_ids(filter)
          opts = {default_paginate: false, bypass_required_filters: true, bypass_default_filters: true, translating_public_ids: true}
          _all({filter: filter}, opts, nil).data
        end

        def validate_request!(params)
          return if Graphiti.context[:graphql] || !validate_requests?

          if context&.respond_to?(:request)
            path = context.request.env["PATH_INFO"]
            unless allow_request?(path, params, current_action)
              raise Errors::InvalidEndpoint.new(self, path, current_action)
            end
          end
        end

        def guard_nil_id!(params)
          return unless params
          if params.key?(:id) && params[:id].nil?
            raise Errors::UndefinedIDLookup.new(self)
          end
        end
      end
    end
  end
end
