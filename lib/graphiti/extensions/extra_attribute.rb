require "jsonapi/serializable/resource/conditional_fields"

module Graphiti
  module Extensions
    # Only render a given attribute when the user specifically requests it.
    # Useful for computationally-expensive attributes that are not required
    # on every request.
    #
    # This class handles the serialization, but you may also want to run
    # code during scoping (for instance, to eager load associations referenced
    # by this extra attribute. See (Resource.extra_field).
    #
    # @example Basic Usage
    #   # Will only be rendered on user request, ie
    #   # /people?extra_fields[people]=net_worth
    #   extra_attribute :net_worth
    #
    # @example Eager Loading
    #   class PersonResource < ApplicationResource
    #     # If the user requests the 'net_worth' attribute, make sure
    #     # 'assets' are eager loaded
    #     extra_field :net_worth do |scope|
    #       scope.includes(:assets)
    #     end
    #   end
    #
    #   class SerializablePerson < Graphiti::Serializer
    #     # ... code ...
    #     extra_attribute :net_worth do
    #       @object.assets.sum(&:value)
    #     end
    #   end
    #
    # @see Resource.extra_field
    module ExtraAttribute
      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        # @param [Symbol] name the name of the attribute
        # @param [Hash] options the options passed on to vanilla to .attribute
        def extra_attribute(name, options = {}, &blk)
          allow_field = proc {
            if options[:if]
              next false unless instance_exec(&options[:if])
            end

            @extra_fields &&
              @extra_fields[@_type] &&
              @extra_fields[@_type].include?(name)
          }

          attribute name, if: allow_field, &blk
        end
      end
    end
  end
end
