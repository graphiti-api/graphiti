module JsonapiCompliable
  # Provides main interface to jsonapi_compliable
  #
  # This gets mixed in to a "context" class, such as a Rails controller.
  module Base
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :_jsonapi_compliable, :_sideload_whitelist
      end

      def self.inherited(klass)
        super
        klass._jsonapi_compliable = Class.new(_jsonapi_compliable)
        klass._sideload_whitelist = _sideload_whitelist.dup if _sideload_whitelist
      end
    end

    # @!classmethods
    module ClassMethods
      # Define your JSONAPI configuration
      #
      # @example Inline Resource
      #   # 'Quick and Dirty' solution that does not require a separate
      #   # Resource object
      #   class PostsController < ApplicationController
      #     jsonapi do
      #       type :posts
      #       use_adapter JsonapiCompliable::Adapters::ActiveRecord
      #
      #       allow_filter :title
      #     end
      #   end
      #
      # @example Resource Class (preferred)
      #   # Make code reusable by encapsulating it in a Resource class
      #   class PostsController < ApplicationController
      #     jsonapi resource: PostResource
      #   end
      #
      # @see Resource
      # @param resource [Resource] the Resource class associated to this endpoint
      # @return [void]
      def jsonapi(foo = 'bar', resource: nil, &blk)
        if resource
          self._jsonapi_compliable = resource
        else
          if !self._jsonapi_compliable
            self._jsonapi_compliable = Class.new(JsonapiCompliable::Resource)
          end
        end

        self._jsonapi_compliable.class_eval(&blk) if blk
      end

      # Set the sideload whitelist. You may want to omit sideloads for
      # security or performance reasons.
      #
      # Uses JSONAPI::IncludeDirective from {{http://jsonapi-rb.org jsonapi-rb}}
      #
      # @example Whitelisting Relationships
      #   # Given the following whitelist
      #   class PostsController < ApplicationResource
      #     jsonapi resource: MyResource
      #
      #     sideload_whitelist({
      #       index: [:blog],
      #       show: [:blog, { comments: :author }]
      #     })
      #
      #     # ... code ...
      #   end
      #
      #   # A request to sideload 'tags'
      #   #
      #   # GET /posts/1?include=tags
      #   #
      #   # ...will silently fail.
      #   #
      #   # A request for comments and tags:
      #   #
      #   # GET /posts/1?include=tags,comments
      #   #
      #   # ...will only sideload comments
      #
      # @param [Hash, Array, Symbol] whitelist
      # @see Query#include_hash
      def sideload_whitelist(hash)
        self._sideload_whitelist = JSONAPI::IncludeDirective.new(hash).to_hash
      end
    end

    # @api private
    def sideload_whitelist
      self.class._sideload_whitelist || {}
    end

    # Returns an instance of the associated Resource
    #
    # In other words, if you configured your controller as:
    #
    #   jsonapi resource: MyResource
    #
    # This returns MyResource.new
    #
    # @return [Resource] the configured Resource for this controller
    def jsonapi_resource
      @jsonapi_resource ||= begin
        resource = self.class._jsonapi_compliable
        if resource.is_a?(Hash)
          resource[action_name.to_sym].new
        else
          resource.new
        end
      end
    end

    # Instantiates the relevant Query object
    #
    # @see Query
    # @return [Query] the Query object for this resource/params
    def query
      @query ||= Query.new(jsonapi_resource, params)
    end

    # @see Query#to_hash
    # @return [Hash] the normalized query hash for only the *current* resource
    def query_hash
      @query_hash ||= query.to_hash[jsonapi_resource.type]
    end

    def wrap_context
      JsonapiCompliable.with_context(jsonapi_context, action_name.to_sym) do
        yield
      end
    end

    def jsonapi_context
      self
    end

    # Use when direct, low-level access to the scope is required.
    #
    # @example Show Action
    #   # Scope#resolve returns an array, but we only want to render
    #   # one object, not an array
    #   scope = jsonapi_scope(Employee.where(id: params[:id]))
    #   render_jsonapi(scope.resolve.first, scope: false)
    #
    # @example Scope Chaining
    #   # Chain onto scope after running through typical DSL
    #   # Here, we'll add active: true to our hash if the user
    #   # is filtering on something
    #   scope = jsonapi_scope({})
    #   scope.object.merge!(active: true) if scope.object[:filter]
    #
    # @see Resource#build_scope
    # @return [Scope] the configured scope
    def jsonapi_scope(scope, opts = {})
      jsonapi_resource.build_scope(scope, query, opts)
    end

    # @see Deserializer#initialize
    # @return [Deserializer]
    def deserialized_params
      @deserialized_params ||= JsonapiCompliable::Deserializer.new(params, verb)
    end

    def verb
      request.env['REQUEST_METHOD'].downcase.to_sym
    end

    # Create the resource model and process all nested relationships via the
    # serialized parameters. Any error, including validation errors, will roll
    # back the transaction.
    #
    # @example Basic Rails
    #   # Example Resource must have 'model'
    #   #
    #   # class PostResource < ApplicationResource
    #   #   model Post
    #   # end
    #   def create
    #     post, success = jsonapi_create.to_a
    #
    #     if success
    #       render_jsonapi(post, scope: false)
    #     else
    #       render_errors_for(post)
    #     end
    #   end
    #
    # @see Resource.model
    # @see #resource
    # @see #deserialized_params
    # @return [Util::ValidationResponse]
    def jsonapi_create
      _persist do
        jsonapi_resource.persist_with_relationships \
          deserialized_params.meta,
          deserialized_params.attributes,
          deserialized_params.relationships
      end
    end

    # Update the resource model and process all nested relationships via the
    # serialized parameters. Any error, including validation errors, will roll
    # back the transaction.
    #
    # @example Basic Rails
    #   # Example Resource must have 'model'
    #   #
    #   # class PostResource < ApplicationResource
    #   #   model Post
    #   # end
    #   def update
    #     post, success = jsonapi_update.to_a
    #
    #     if success
    #       render_jsonapi(post, scope: false)
    #     else
    #       render_errors_for(post)
    #     end
    #   end
    #
    # @see #jsonapi_create
    # @return [Util::ValidationResponse]
    def jsonapi_update
      _persist do
        jsonapi_resource.persist_with_relationships \
          deserialized_params.meta,
          deserialized_params.attributes,
          deserialized_params.relationships
      end
    end

    # Delete the model
    # Any error, including validation errors, will roll back the transaction.
    #
    # Note: +before_commit+ hooks still run unless excluded
    #
    # @return [Util::ValidationResponse]
    def jsonapi_destroy
      jsonapi_resource.transaction do
        model = jsonapi_resource.destroy(params[:id])
        validator = ::JsonapiCompliable::Util::ValidationResponse.new \
          model, deserialized_params
        validator.validate!
        jsonapi_resource.before_commit(model, :destroy)
        validator
      end
    end

    def jsonapi_render_options
      defaults = default_jsonapi_render_options
      options = Util::RenderOptions.generate(query_hash, defaults)
      options[:expose][:context] = jsonapi_context
      if options[:include].empty? && force_includes?
        options[:include] = deserialized_params.include_directive
      end
      options
    end

    def resolve(base)
      scope = jsonapi_scope(base)
      [scope.resolve, scope.resolve_stats]
    end

    def render_jsonapi(scope, options = {})
      models, stats = scope, nil
      unless options[:apply_scoping] == false
        models, stats = resolve(scope)
      end
      models = models[0] if options[:single]
      options = jsonapi_render_options.merge(options)
      options[:meta][:stats] = stats unless stats.blank?
      Renderer.new(models, options).to_jsonapi
    end

    # Define a hash that will be automatically merged into your
    # render_jsonapi call
    #
    # @example
    #   # this
    #   render_jsonapi(foo)
    #   # is equivalent to this
    #   render jsonapi: foo, default_jsonapi_render_options
    #
    # @see #render_jsonapi
    # @return [Hash] the options hash you define
    def default_jsonapi_render_options
      {}.tap do |options|
      end
    end

    private

    def _persist
      jsonapi_resource.transaction do
        ::JsonapiCompliable::Util::Hooks.record do
          model = yield
          validator = ::JsonapiCompliable::Util::ValidationResponse.new \
            model, deserialized_params
          validator.validate!
          validator
        end
      end
    end

    def force_includes?
      not deserialized_params.data.nil?
    end
  end
end
