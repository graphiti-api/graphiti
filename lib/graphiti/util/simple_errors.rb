# A minimal implementation of an errors object similar to `ActiveModel::Errors`.
# Designed to support internal Graphiti classes like the `RequestValidator` so
# that there does not need to be a dependency on activemodel.
module Graphiti
  module Util
    class SimpleErrors
      include Enumerable

      # Overridable under graphiti.errors.messages.
      DEFAULT_MESSAGES = {
        missing: "is missing",
        invalid: "must be an object",
        invalid_relationship: "is not a valid relationship",
        unwritable_relationship: "cannot be written",
        unknown_attribute: "is an unknown attribute",
        unwritable_attribute: "cannot be written",
        type_error: "should be type %{type}",
        attribute_mismatch: "does not match the server endpoint"
      }.freeze

      # Joins an attribute to its message, like Rails' own errors.format.
      DEFAULT_FORMAT = "%{attribute} %{message}"

      attr_reader :messages, :details

      def initialize(validation_target)
        @target = validation_target
        @messages = apply_default_array({})
        @details = apply_default_array({})
        @errors = apply_default_array({})
      end

      def clear
        messages.clear
        details.clear
      end

      def [](attribute)
        messages[attribute.to_sym]
      end

      def each
        messages.each_key do |attribute|
          messages[attribute].each { |error| yield attribute, error }
        end
      end

      def size
        values.flatten.size
      end
      alias_method :count, :size

      def values
        messages.values.reject(&:empty?)
      end

      def keys
        messages.select { |key, value|
          !value.empty?
        }.keys
      end

      def empty?
        size.zero?
      end
      alias_method :blank?, :empty?

      def add(attribute, code, message: nil, **interpolations)
        details[attribute.to_sym] << {error: code}
        messages[attribute.to_sym] << translate(code, message, **interpolations, attribute: attribute)
      end

      def added?(attribute, code)
        details[attribute.to_sym].include?({error: code})
      end

      def full_messages
        map { |attribute, message| full_message(attribute, message) }
      end
      alias_method :to_a, :full_messages

      def full_messages_for(attribute)
        attribute = attribute.to_sym
        messages[attribute].map { |message| full_message(attribute, message) }
      end

      def full_message(attribute, message)
        return message if attribute == :base

        translate(:format, DEFAULT_FORMAT, [:graphiti, :errors], attribute: attribute, message: message)
      end

      private

      def translate(key, fallback, scope = [:graphiti, :errors, :messages], **interpolations)
        fallback ||= DEFAULT_MESSAGES.fetch(key) { "is #{key.to_s.humanize.downcase}" }
        return fallback % interpolations unless defined?(::I18n)

        ::I18n.t(key, scope: scope, default: fallback, **interpolations)
      end

      def apply_default_array(hash)
        hash.default_proc = proc { |h, key| h[key] = [] }
        hash
      end
    end
  end
end
