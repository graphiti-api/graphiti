module Graphiti
  module ErrorSerializers
    class InvalidRequest
      STATUS = 400

      attr_reader :source

      def initialize(source)
        @source = source
      end

      def status
        self.class::STATUS
      end

      def errors
        [].tap do |payload|
          source.details.each_pair do |attribute, attribute_errors|
            attribute_errors.each_with_index do |error, index|
              message = source.messages[attribute][index]

              payload << {
                code: code,
                status: status.to_s,
                title: title,
                detail: source.full_message(attribute, message),
                source: {pointer: pointer_for(attribute)},
                meta: {
                  attribute: attribute,
                  message: message,
                  code: error[:error]
                }
              }
            end
          end
        end
      end

      # graphiti_errors named the payload this. Remove in 3.0.
      def rendered_errors
        Graphiti::DEPRECATOR.deprecation_warning("#rendered_errors", "use #errors")
        errors
      end

      private

      def code
        "bad_request"
      end

      def title
        return default_title unless defined?(::I18n)

        ::I18n.t :title, scope: [:graphiti, :errors, code], default: default_title
      end

      def default_title
        "Request Error"
      end

      # "filter.foo[0]" describes a path into the payload, not an attribute
      # name, so it becomes a JSON pointer.
      def pointer_for(attribute)
        attribute.to_s.tr(".", "/").gsub(/\[(\d+)\]/, '/\1')
      end
    end
  end
end
