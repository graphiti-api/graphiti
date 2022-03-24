# A minimal implementation of an errors object similar to `ActiveModel::Errors`.
# Designed to support internal Graphiti classes like the `RequestValidator` so
# that there does not need to be a dependency on activemodel.
module Graphiti
  module Util
    class SimpleErrors
      include Enumerable

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

      def add(attribute, code, message: nil)
        message ||= "is #{code.to_s.humanize.downcase}"

        details[attribute.to_sym] << {error: code}
        messages[attribute.to_sym] << message
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
        "#{attribute} #{message}"
      end

      private

      def apply_default_array(hash)
        hash.default_proc = proc { |h, key| h[key] = [] }
        hash
      end
    end
  end
end
