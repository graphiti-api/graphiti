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
      @jsonapi_resource ||= self.class._jsonapi_compliable.new
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

    # Tracks the current context so we can refer to it within any
    # random object. Helpful for easy-access to things like the current
    # user.
    #
    # @api private
    # @yieldreturn Code to run within the current context
    def wrap_context
      jsonapi_resource.with_context(self, action_name.to_sym) do
        yield
      end
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
      @deserialized_params ||= JsonapiCompliable::Deserializer.new(params, request.env)
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

    def jsonapi_destroy
      _persist do
        jsonapi_resource.destroy(params[:id])
      end
    end

    # Similar to +render :json+ or +render :jsonapi+
    #
    # By default, this will "build" the scope via +#jsonapi_scope+. To avoid
    # this, pass +scope: false+
    #
    # This builds relevant options and sends them to
    # +JSONAPI::Serializable::SuccessRenderer#render+from
    # {http://jsonapi-rb.org jsonapi-rb}
    #
    # @example Build Scope by Default
    #   # Employee.all returns an ActiveRecord::Relation. No SQL is fired at this point.
    #   # We further 'chain' onto this scope, applying pagination, sorting,
    #   # filters, etc that the user has requested.
    #   def index
    #     employees = Employee.all
    #     render_jsonapi(employees)
    #   end
    #
    # @example Avoid Building Scope by Default
    #   # Maybe we already manually scoped, and don't want to fire the logic twice
    #   # This code is equivalent to the above example
    #   def index
    #     scope = jsonapi_scope(Employee.all)
    #     # ... do other things with the scope ...
    #     render_jsonapi(scope.resolve, scope: false)
    #   end
    #
    # @param scope [Scope, Object] the scope to build or render.
    # @param [Hash] opts the render options passed to {http://jsonapi-rb.org jsonapi-rb}
    # @option opts [Boolean] :scope Default: true. Should we call #jsonapi_scope on this object?
    # @see #jsonapi_scope
    def render_jsonapi(scope, opts = {})
      scope = jsonapi_scope(scope) unless opts[:scope] == false || scope.is_a?(JsonapiCompliable::Scope)
      opts  = default_jsonapi_render_options.merge(opts)
      opts  = Util::RenderOptions.generate(scope, query_hash, opts)
      opts[:expose][:context] = self
      opts[:include] = deserialized_params.include_directive if force_includes?
      perform_render_jsonapi(opts)
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

    def force_includes?
      not deserialized_params.data.nil?
    end

    def perform_render_jsonapi(opts)
      # TODO(beauby): Reuse renderer.
      JSONAPI::Serializable::Renderer.new
        .render(opts.delete(:jsonapi), opts).to_json
    end

    def _persist
      validation_response = nil
      jsonapi_resource.transaction do
        object = yield
        validation_response = Util::ValidationResponse.new \
          object, deserialized_params
        raise Errors::ValidationError unless validation_response.to_a[1]
      end
      validation_response
    end
  end
end
