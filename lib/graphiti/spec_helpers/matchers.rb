module Graphiti
  module SpecHelpers
    # Assertions against a resource's DSL. The schema specs cannot cover
    # adapter-dependent options (primary key, foreign key, and so on) because
    # the schema does not carry them; these read the resource config directly.
    module Matchers
      class BaseMatcher
        GRAPHITI_OPTS = [].freeze
        GRAPHITI_CONFIG_KEY = ""
        EXPECTED_ACTION = ""

        def description
          "#{self.class::EXPECTED_ACTION} #{target}"
        end

        def failure_message
          "expected that #{resource.class} would #{self.class::EXPECTED_ACTION} #{target}\n#{@opt_failures.join("\n")}"
        end

        def failure_message_when_negated
          "expected that #{resource.class} would not #{self.class::EXPECTED_ACTION} #{target}"
        end

        def opt_failure_message(opt, expected, actual)
          "expected that #{opt} would be #{expected}, was #{actual}"
        end

        def does_not_match?(resource)
          !matches?(resource)
        end

        def matches?(resource)
          @resource = resource

          expected? && expected_opts?
        end

        def with_options(opts)
          @opts = opts
          self
        end

        private

        def actual_opts
          self.class::GRAPHITI_OPTS & opts.keys
        end

        def config
          @config ||= resource.class.config[self.class::GRAPHITI_CONFIG_KEY][target]
        end

        def expected_opts?
          return false unless config

          actual_opts.map { |opt| assert_opt(opt) }.all?(true)
        end
      end

      class RelationMatcher < BaseMatcher
        GRAPHITI_OPTS = %i[primary_key foreign_key resource readable writable link single].freeze
        SIDELOAD_METHODS = {resource: :resource_class, readable: :readable?, writable: :writable?, single: :single?}.freeze
        GRAPHITI_CONFIG_KEY = :sideloads
        EXPECTED_ACTION = ""

        def initialize(target)
          @target = target
          @opts = {}
          @opt_failures = []
        end

        private

        attr_reader :target, :opts, :resource

        def assert_opt(opt)
          asserted_opt = SIDELOAD_METHODS.fetch(opt, opt)
          return true if config.send(asserted_opt) == opts[opt]

          @opt_failures << opt_failure_message(opt, opts[opt], config.send(asserted_opt))
          false
        end

        def expected?
          config && config.type == relation_name
        end

        # BelongsToMatcher -> :belongs_to, matching Sideload#type.
        def relation_name
          self.class.name.demodulize.gsub("Matcher", "").underscore.to_sym
        end
      end

      class BelongsToMatcher < RelationMatcher
        EXPECTED_ACTION = "belong to"
      end

      class HasManyMatcher < RelationMatcher
        EXPECTED_ACTION = "have many"
      end

      class HasOneMatcher < RelationMatcher
        EXPECTED_ACTION = "have one"
      end

      class ResourceDSLMatcher < BaseMatcher
        def initialize(target, type)
          @target = target
          @type = type
          @opts = {}
          @opt_failures = []
        end

        private

        attr_reader :target, :type, :opts, :resource

        def expected?
          config && assert_type
        end

        def assert_type
          return true if config[:type] == type

          @opt_failures << opt_failure_message("type", type, config[:type])
          false
        end

        def assert_opt(opt)
          return true if config[opt] == opts[opt]

          @opt_failures << opt_failure_message(opt, opts[opt], config[opt])
          false
        end
      end

      class ExposeAttributeMatcher < ResourceDSLMatcher
        GRAPHITI_OPTS = %i[writable readable sortable filterable].freeze
        GRAPHITI_CONFIG_KEY = :attributes
        EXPECTED_ACTION = "expose"
      end

      class FilterAttributeMatcher < ResourceDSLMatcher
        GRAPHITI_OPTS = %i[allow deny single required blanks].freeze
        GRAPHITI_CONFIG_KEY = :filters
        EXPECTED_ACTION = "filter"
      end

      # @param [Symbol] relation
      #
      # @example expect(subject).to belong_to_resource(:user)
      # @example expect(subject).to belong_to_resource(:user).with_options(foreign_key: :user_id, resource: UserResource)
      # @example expect(subject).not_to belong_to_resource(:user)
      def belong_to_resource(relation)
        BelongsToMatcher.new(relation)
      end

      # @param [Symbol] relation
      #
      # @example expect(subject).to have_many_resources(:posts)
      # @example expect(subject).to have_many_resources(:posts).with_options(foreign_key: :post_id, resource: PostResource)
      # @example expect(subject).not_to have_many_resources(:posts)
      def have_many_resources(relation)
        HasManyMatcher.new(relation)
      end

      # @param [Symbol] relation
      #
      # @example expect(subject).to have_one_resource(:post)
      # @example expect(subject).to have_one_resource(:post).with_options(foreign_key: :post_id, resource: PostResource)
      # @example expect(subject).not_to have_one_resource(:post)
      def have_one_resource(relation)
        HasOneMatcher.new(relation)
      end

      # @param [Symbol] attribute
      # @param [Symbol] type
      #
      # @example expect(subject).to expose_attribute(:name, :string)
      # @example expect(subject).to expose_attribute(:name, :string).with_options(writable: false)
      # @example expect(subject).not_to expose_attribute(:name, :string)
      def expose_attribute(attribute, type)
        ExposeAttributeMatcher.new(attribute, type)
      end

      # @param [Symbol] attribute
      # @param [Symbol] type
      #
      # @example expect(subject).to filter_attribute(:name, :string)
      # @example expect(subject).to filter_attribute(:name, :string).with_options(blanks: :null)
      # @example expect(subject).not_to filter_attribute(:name, :string)
      def filter_attribute(attribute, type)
        FilterAttributeMatcher.new(attribute, type)
      end
    end
  end
end
