module JsonapiCompliable
  # Resources hold configuration: How do you want to process incoming JSONAPI
  # requests?
  #
  # Let's say we start with an empty hash as our scope object:
  #
  #   render_jsonapi({})
  #
  # Let's define the behavior of various parameters. Here we'll merge
  # options into our hash when the user filters, sorts, and paginates.
  # Then, we'll pass that hash off to an HTTP Client:
  #
  #   class PostResource < ApplicationResource
  #     type :posts
  #     use_adapter JsonapiCompliable::Adapters::Null
  #
  #     # What do do when filter[active] parameter comes in
  #     allow_filter :active do |scope, value|
  #       scope.merge(active: value)
  #     end
  #
  #     # What do do when sorting parameters come in
  #     sort do |scope, attribute, direction|
  #       scope.merge(order: { attribute => direction })
  #     end
  #
  #     # What do do when pagination parameters come in
  #     page do |scope, current_page, per_page|
  #       scope.merge(page: current_page, per_page: per_page)
  #     end
  #
  #     # Resolve the scope by passing the hash to an HTTP Client
  #     def resolve(scope)
  #       MyHttpClient.get(scope)
  #     end
  #   end
  #
  # This code can quickly become duplicative - we probably want to reuse
  # this logic for other objects that use the same HTTP client.
  #
  # That's why we also have *Adapters*. Adapters encapsulate common, reusable
  # resource configuration. That's why we don't need to specify the above code
  # when using +ActiveRecord+ - the default logic is already in the adapter.
  #
  #   class PostResource < ApplicationResource
  #     type :posts
  #     use_adapter JsonapiCompliable::Adapters::ActiveRecord
  #
  #     allow_filter :title
  #   end
  #
  # Of course, we can always override the Resource directly for one-off
  # customizations:
  #
  #   class PostResource < ApplicationResource
  #     type :posts
  #     use_adapter JsonapiCompliable::Adapters::ActiveRecord
  #
  #     allow_filter :title_prefix do |scope, value|
  #       scope.where(["title LIKE ?", "#{value}%"])
  #     end
  #   end
  #
  # Resources can also define *Sideloads*. Sideloads define the relationships between resources:
  #
  #   allow_sideload :comments, resource: CommentResource do
  #     # How to fetch the associated objects
  #     # This will be further chained down the line
  #     scope do |posts|
  #       Comment.where(post_id: posts.map(&:id))
  #     end
  #
  #     # Now that we've resolved everything, how to assign the objects
  #     assign do |posts, comments|
  #       posts.each do |post|
  #         relevant_comments = comments.select { |c| c.post_id === post.id }
  #         post.comments = relevant_comments
  #       end
  #     end
  #   end
  #
  # Once again, we can DRY this up using an Adapter:
  #
  #   use_adapter JsonapiCompliable::Adapters::ActiveRecord
  #
  #   has_many :comments,
  #     scope: -> { Comment.all },
  #     resource: CommentResource,
  #     foreign_key: :post_id
  class Resource
    extend Forwardable
    attr_reader :context

    class << self
      extend Forwardable
      attr_accessor :config

      # @!method allow_sideload
      #   @see Sideload#allow_sideload
      def_delegator :sideloading, :allow_sideload
      # @!method has_many
      #   @see Adapters::ActiveRecordSideloading#has_many
      def_delegator :sideloading, :has_many
      # @!method has_one
      #   @see Adapters::ActiveRecordSideloading#has_one
      def_delegator :sideloading, :has_one
      # @!method belongs_to
      #   @see Adapters::ActiveRecordSideloading#belongs_to
      def_delegator :sideloading, :belongs_to
      # @!method has_and_belongs_to_many
      #   @see Adapters::ActiveRecordSideloading#has_and_belongs_to_many
      def_delegator :sideloading, :has_and_belongs_to_many
      # @!method polymorphic_belongs_to
      #   @see Adapters::ActiveRecordSideloading#polymorphic_belongs_to
      def_delegator :sideloading, :polymorphic_belongs_to
      # @!method polymorphic_has_many
      #   @see Adapters::ActiveRecordSideloading#polymorphic_has_many
      def_delegator :sideloading, :polymorphic_has_many
    end

    # @!method sideload
    #   @see Sideload#sideload
    def_delegator :sideloading, :sideload

    # @private
    def self.inherited(klass)
      klass.config = Util::Hash.deep_dup(self.config)
    end

    # @api private
    def self.sideloading
      @sideloading ||= Sideload.new(:base, resource: self)
    end

    # Whitelist a filter
    #
    # @example Basic Filtering
    #   allow_filter :title
    #
    #   # When using ActiveRecord, this code is equivalent
    #   allow_filter :title do |scope, value|
    #     scope.where(title: value)
    #   end
    #
    # @example Custom Filtering
    #   # All filters can be customized with a block
    #   allow_filter :title_prefix do |scope, value|
    #     scope.where('title LIKE ?', "#{value}%")
    #   end
    #
    # @example Guarding Filters
    #   # Only allow the current user to filter on a property
    #   allow_filter :title, if: :admin?
    #
    #   def admin?
    #     current_user.role == 'admin'
    #   end
    #
    # If a filter is not allowed, a +Jsonapi::Errors::BadFilter+ error will be raised.
    #
    # @overload allow_filter(name, options = {})
    #   @param [Symbol] name The name of the filter
    #   @param [Hash] options
    #   @option options [Symbol] :if A method name on the current context - If the method returns false, +BadFilter+ will be raised.
    #   @option options [Array<Symbol>] :aliases Allow the user to specify these aliases in the URL, then match to this filter. Mainly used for backwards-compatibility.
    #
    # @yieldparam scope The object being scoped
    # @yieldparam value The sanitized value from the URL
    def self.allow_filter(name, *args, &blk)
      opts = args.extract_options!
      aliases = [name, opts[:aliases]].flatten.compact
      config[:filters][name.to_sym] = {
        aliases: aliases,
        if: opts[:if],
        filter: blk,
        required: opts[:required].respond_to?(:call) ? opts[:required] : !!opts[:required]
      }
    end

    # Whitelist a statistic.
    #
    # Statistics are requested like
    #
    #   GET /posts?stats[total]=count
    #
    # And returned in +meta+:
    #
    #   {
    #     data: [...],
    #     meta: { stats: { total: { count: 100 } } }
    #   }
    #
    # Statistics take into account the current scope, *without pagination*.
    #
    # @example Total Count
    #   allow_stat total: [:count]
    #
    # @example Average Rating
    #   allow_stat rating: [:average]
    #
    # @example Custom Stat
    #   allow_stat rating: [:average] do
    #     standard_deviation { |scope, attr| ... }
    #   end
    #
    # @param [Symbol, Hash] symbol_or_hash The attribute and metric
    # @yieldparam scope The object being scoped
    # @yieldparam [Symbol] attr The name of the metric
    def self.allow_stat(symbol_or_hash, &blk)
      dsl = Stats::DSL.new(config[:adapter], symbol_or_hash)
      dsl.instance_eval(&blk) if blk
      config[:stats][dsl.name] = dsl
    end

    # When you want a filter to always apply, on every request.
    #
    # @example Only Active Posts
    #   default_filter :active do |scope|
    #     scope.where(active: true)
    #   end
    #
    # Default filters can be overridden *if* there is a corresponding +allow_filter+:
    #
    # @example Overriding Default Filters
    #   allow_filter :active
    #
    #   default_filter :active do |scope|
    #     scope.where(active: true)
    #   end
    #
    #   # GET /posts?filter[active]=false
    #   # Returns only active posts
    #
    # @see .allow_filter
    # @param [Symbol] name The default filter name
    # @yieldparam scope The object being scoped
    def self.default_filter(name, &blk)
      config[:default_filters][name.to_sym] = {
        filter: blk
      }
    end

    # The Model object associated with this class.
    #
    # This model will be utilized on write requests.
    #
    # Models need not be ActiveRecord ;)
    #
    # @example
    #   class PostResource < ApplicationResource
    #     # ... code ...
    #     model Post
    #   end
    #
    # @param [Class] klass The associated Model class
    def self.model(klass)
      config[:model] = klass
    end

    # Register a hook that fires AFTER all validation logic has run -
    # including validation of nested objects - but BEFORE the transaction
    # has closed.
    #
    # Helpful for things like "contact this external service after persisting
    # data, but roll everything back if there's an error making the service call"
    #
    # @param [Hash] +only: [:create, :update, :destroy]+
    def self.before_commit(only: [:create, :update, :destroy], &blk)
      Array(only).each do |verb|
        config[:before_commit][verb] = blk
      end
    end

    # Actually fire the before commit hooks
    #
    # @see .before_commit
    # @api private
    def before_commit(model, method)
      hook = self.class.config[:before_commit][method]
      hook.call(model) if hook
    end

    # Define custom sorting logic
    #
    # @example Sort on alternate table
    #   # GET /employees?sort=title
    #   sort do |scope, att, dir|
    #     if att == :title
    #       scope.joins(:current_position).order("title #{dir}")
    #     else
    #       scope.order(att => dir)
    #     end
    #   end
    #
    # @yieldparam scope The current object being scoped
    # @yieldparam [Symbol] att The requested sort attribute
    # @yieldparam [Symbol] dir The requested sort direction (:asc/:desc)
    def self.sort(&blk)
      config[:sorting] = blk
    end

    # Define custom pagination logic
    #
    # @example Use will_paginate instead of Kaminari
    #   # GET /employees?page[size]=10&page[number]=2
    #   paginate do |scope, current_page, per_page|
    #     scope.paginate(page: current_page, per_page: per_page)
    #   end
    #
    # @yieldparam scope The current object being scoped
    # @yieldparam [Integer] current_page The page[number] parameter value
    # @yieldparam [Integer] per_page The page[size] parameter value
    def self.paginate(&blk)
      config[:pagination] = blk
    end

    # Perform special logic when an extra field is requested.
    # Often used to eager load data that will be used to compute the
    # extra field.
    #
    # This is *not* required if you have no custom logic.
    #
    # @example Eager load if extra field is required
    #   # GET /employees?extra_fields[employees]=net_worth
    #   extra_field(employees: [:net_worth]) do |scope|
    #     scope.includes(:assets)
    #   end
    #
    # @see Scoping::ExtraFields
    #
    # @param [Symbol] name Name of the extra field
    # @yieldparam scope The current object being scoped
    # @yieldparam [Integer] current_page The page[number] parameter value
    # @yieldparam [Integer] per_page The page[size] parameter value
    def self.extra_field(name, &blk)
      config[:extra_fields][name] = blk
    end

    # Configure the adapter you want to use.
    #
    # @example ActiveRecord Adapter
    #   require 'jsonapi_compliable/adapters/active_record'
    #   use_adapter JsonapiCompliable::Adapters::ActiveRecord
    #
    # @param [Class] klass The adapter class
    def self.use_adapter(klass)
      config[:adapter] = klass.new
    end

    # Override default sort applied when not present in the query parameters.
    #
    # Default: [{ id: :asc }]
    #
    # @example Order by created_at descending by default
    #   # GET /employees will order by created_at descending
    #   default_sort([{ created_at: :desc }])
    #
    # @param [Array<Hash>] val Array of sorting criteria
    def self.default_sort(val)
      config[:default_sort] = val
    end

    # The JSONAPI Type. For instance if you queried:
    #
    # GET /employees?fields[positions]=title
    #
    # And/Or got back in the response
    #
    # { id: '1', type: 'positions' }
    #
    # The type would be :positions
    #
    # This should match the +type+ set in your serializer.
    #
    # @example
    #   class PostResource < ApplicationResource
    #     type :posts
    #   end
    #
    # @param [Array<Hash>] value Array of sorting criteria
    def self.type(value = nil)
      config[:type] = value
    end

    # Set an alternative default page number. Defaults to 1.
    # @param [Integer] val The new default
    def self.default_page_number(val)
      config[:default_page_number] = val
    end

    # Set an alternate default page size, when not specified in query parameters.
    #
    # @example
    #   # GET /employees will only render 10 employees
    #   default_page_size 10
    #
    # @param [Integer] val The new default page size.
    def self.default_page_size(val)
      config[:default_page_size] = val
    end

    # This is where we store all information set via DSL.
    # Useful for introspection.
    # Gets dup'd when inherited.
    #
    # @return [Hash] the current configuration
    def self.config
      @config ||= begin
        {
          filters: {},
          default_filters: {},
          extra_fields: {},
          stats: {},
          sorting: nil,
          pagination: nil,
          model: nil,
          before_commit: {},
          adapter: Adapters::Abstract.new
        }
      end
    end

    # Run code within a given context.
    # Useful for running code within, say, a Rails controller context
    #
    # When using Rails, controller actions are wrapped this way.
    #
    # @example Sinatra
    #   get '/api/posts' do
    #     resource.with_context self, :index do
    #       scope = jsonapi_scope(Tweet.all)
    #       render_jsonapi(scope.resolve, scope: false)
    #     end
    #   end
    #
    # @see Rails
    # @see Base#wrap_context
    # @param object The context (Rails controller or equivalent)
    # @param namespace One of index/show/etc
    def with_context(object, namespace = nil)
      JsonapiCompliable.with_context(object, namespace) do
        yield
      end
    end

    # The current context **object** set by +#with_context+. If you are
    # using Rails, this is a controller instance.
    #
    # This method is equivalent to +JsonapiCompliable.context[:object]+
    #
    # @see #with_context
    # @return the context object
    def context
      JsonapiCompliable.context[:object]
    end

    # The current context **namespace** set by +#with_context+. If you
    # are using Rails, this is the controller method name (e.g. +:index+)
    #
    # This method is equivalent to +JsonapiCompliable.context[:namespace]+
    #
    # @see #with_context
    # @return [Symbol] the context namespace
    def context_namespace
      JsonapiCompliable.context[:namespace]
    end

    # Build a scope using this Resource configuration
    #
    # Essentially "api private", but can be useful for testing.
    #
    # @see Scope
    # @see Query
    # @param base The base scope we are going to chain
    # @param query The relevant Query object
    # @param opts Opts passed to +Scope.new+
    # @return [Scope] a configured Scope instance
    def build_scope(base, query, opts = {})
      Scope.new(base, self, query, opts)
    end

    # Create the relevant model.
    # You must configure a model (see .model) to create.
    # If you override, you *must* return the created instance.
    #
    # @example Send e-mail on creation
    #   def create(attributes)
    #     instance = model.create(attributes)
    #     UserMailer.welcome_email(instance).deliver_later
    #     instance
    #   end
    #
    # @see .model
    # @see Adapters::ActiveRecord#create
    # @param [Hash] create_params The relevant attributes, including id and foreign keys
    # @return [Object] an instance of the just-created model
    def create(create_params)
      adapter.create(model, create_params)
    end

    # Update the relevant model.
    # You must configure a model (see .model) to update.
    # If you override, you *must* return the updated instance.
    #
    # @example Send e-mail on update
    #   def update(attributes)
    #     instance = model.update_attributes(attributes)
    #     UserMailer.profile_updated_email(instance).deliver_later
    #     instance
    #   end
    #
    # @see .model
    # @see Adapters::ActiveRecord#update
    # @param [Hash] update_params The relevant attributes, including id and foreign keys
    # @return [Object] an instance of the just-updated model
    def update(update_params)
      adapter.update(model, update_params)
    end

    # Destroy the relevant model.
    # You must configure a model (see .model) to destroy.
    # If you override, you *must* return the destroyed instance.
    #
    # @example Send e-mail on destroy
    #   def destroy(attributes)
    #     instance = model_class.find(id)
    #     instance.destroy
    #     UserMailer.goodbye_email(instance).deliver_later
    #     instance
    #   end
    #
    # @see .model
    # @see Adapters::ActiveRecord#destroy
    # @param [String] id The +id+ of the relevant Model
    # @return [Object] an instance of the just-destroyed model
    def destroy(id)
      adapter.destroy(model, id)
    end

    # Delegates #associate to adapter. Built for overriding.
    #
    # @see .use_adapter
    # @see Adapters::Abstract#associate
    # @see Adapters::ActiveRecord#associate
    def associate(parent, child, association_name, type)
      adapter.associate(parent, child, association_name, type)
    end

    # Delegates #disassociate to adapter. Built for overriding.
    #
    # @see .use_adapter
    # @see Adapters::Abstract#disassociate
    # @see Adapters::ActiveRecord#disassociate
    def disassociate(parent, child, association_name, type)
      adapter.disassociate(parent, child, association_name, type)
    end

    # @api private
    def persist_with_relationships(meta, attributes, relationships, caller_model = nil)
      persistence = JsonapiCompliable::Util::Persistence \
        .new(self, meta, attributes, relationships, caller_model)
      persistence.run
    end

    # @see Sideload#association_names
    def association_names
      sideloading.association_names
    end

    # The relevant proc for the given attribute and calculation.
    #
    # @example Custom Stats
    #   # Given this configuration
    #   allow_stat :rating do
    #     average { |scope, attr| ... }
    #   end
    #
    #   # We'd call the method like
    #   resource.stat(:rating, :average)
    #   # Which would return the custom proc
    #
    # Raises +JsonapiCompliable::Errors::StatNotFound+ if not corresponding
    # stat has been configured.
    #
    # @see Errors::StatNotFound
    # @param [String, Symbol] attribute The attribute we're calculating.
    # @param [String, Symbol] calculation The calculation to run
    # @return [Proc] the corresponding callable
    def stat(attribute, calculation)
      stats_dsl = stats[attribute] || stats[attribute.to_sym]
      raise Errors::StatNotFound.new(attribute, calculation) unless stats_dsl
      stats_dsl.calculation(calculation)
    end

    # Interface to the sideloads for this Resource
    # @api private
    def sideloading
      self.class.sideloading
    end

    # @see .default_sort
    # @api private
    def default_sort
      self.class.config[:default_sort] || [{ id: :asc }]
    end

    # @see .default_page_number
    # @api private
    def default_page_number
      self.class.config[:default_page_number] || 1
    end

    # @see .default_page_size
    # @api private
    def default_page_size
      self.class.config[:default_page_size] || 20
    end

    # Returns :undefined_jsonapi_type when not configured.
    # @see .type
    # @api private
    def type
      self.class.config[:type] || :undefined_jsonapi_type
    end

    # @see .allow_filter
    # @api private
    def filters
      self.class.config[:filters]
    end

    # @see .sort
    # @api private
    def sorting
      self.class.config[:sorting]
    end

    # @see .allow_stat
    # @api private
    def stats
      self.class.config[:stats]
    end

    # @see .paginate
    # @api private
    def pagination
      self.class.config[:pagination]
    end

    # @see .extra_field
    # @api private
    def extra_fields
      self.class.config[:extra_fields]
    end

    # @see .default_filter
    # @api private
    def default_filters
      self.class.config[:default_filters]
    end

    # @see .model
    # @api private
    def model
      self.class.config[:model]
    end

    # @see .use_adapter
    # @api private
    def adapter
      self.class.config[:adapter]
    end

    # How do you want to resolve the scope?
    #
    # For ActiveRecord, when we want to actually fire SQL, it's
    # +#to_a+.
    #
    # @example Custom API Call
    #   # Let's build a hash and pass it off to an HTTP client
    #   class PostResource < ApplicationResource
    #     type :posts
    #     use_adapter JsonapiCompliable::Adapters::Null
    #
    #     sort do |scope, attribute, direction|
    #       scope.merge!(order: { attribute => direction }
    #     end
    #
    #     page do |scope, current_page, per_page|
    #       scope.merge!(page: current_page, per_page: per_page)
    #     end
    #
    #     def resolve(scope)
    #       MyHttpClient.get(scope)
    #     end
    #   end
    #
    # This method *must* return an array of resolved model objects.
    #
    # By default, delegates to the adapter. You likely want to alter your
    # adapter rather than override this directly.
    #
    # @see Adapters::ActiveRecord#resolve
    # @param scope The scope object we've built up
    # @return [Array] array of resolved model objects
    def resolve(scope)
      adapter.resolve(scope)
    end

    # How to run write requests within a transaction.
    #
    # @example
    #   resource.transaction do
    #     # ... save calls ...
    #   end
    #
    # Should roll back the transaction, but avoid bubbling up the error,
    # if +JsonapiCompliable::Errors::ValidationError+ is raised within
    # the block.
    #
    # By default, delegates to the adapter. You likely want to alter your
    # adapter rather than override this directly.
    #
    # @see Adapters::ActiveRecord#transaction
    # @return the result of +yield+
    def transaction
      response = nil
      begin
        adapter.transaction(model) do
          response = yield
        end
      rescue Errors::ValidationError => e
        response = e.validation_response
      end
      response
    end
  end
end
