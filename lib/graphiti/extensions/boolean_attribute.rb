module Graphiti
  module Extensions
    # Turns ruby ? methods into is_ attributes
    #
    # @example Basic Usage
    #   boolean_attribute :active?
    #
    #   # equivalent do
    #   def is_active
    #     @object.active?
    #   end
    module BooleanAttribute
      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        # Register a boolean attribute
        # @param name the corresponding ? method
        # @param [Hash] options Normal .attribute options
        def boolean_attribute(name, options = {}, &blk)
          blk ||= proc { @object.public_send(name) }
          field_name = :"is_#{name.to_s.delete("?")}"
          attribute field_name, options, &blk
        end
      end
    end
  end
end
