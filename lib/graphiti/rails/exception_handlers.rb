module Graphiti
  module Rails
    class ExceptionHandler < RescueRegistry::ExceptionHandler
      # We've actually changed the signature here which is somewhat risky...
      def build_payload(show_details: false, traces: nil, style: :rails)
        case style
        when :standard
          super(show_details: show_details, traces: traces).tap do |payload|
            if show_details
              # For Vandal and Request Responses
              payload[:__raw_error__] = {
                message: exception.message,
                debug: exception.instance_variable_get(:@__graphiti_debug),
                backtrace: exception.backtrace
              }
            end
          end
        when :rails
          # TODO: Find way to not duplicate RailsExceptionHandler
          body = {
            status: status_code,
            error: title
          }

          if show_details
            body[:exception] = exception.inspect
            body[:traces] = traces if traces
          end

          body
        else
          raise ArgumentError, "unknown style #{style}"
        end
      end

      def formatted_response(content_type, **options)
        # We're relying on the fact that `formatted_response` passes through unknown options to `build_payload`
        if Graphiti::Rails.handled_exception_formats.include?(content_type.to_sym)
          options[:style] = :standard
        end
        super
      end
    end

    class FallbackHandler < ExceptionHandler
      # A nil response is what hands the exception back to the default Rails
      # handler, so formats Graphiti does not claim render as they always did.
      def formatted_response(content_type, **options)
        return unless Graphiti::Rails.handled_exception_formats.include?(content_type.to_sym)

        super
      end
    end

    class InvalidRequestHandler < ExceptionHandler
      # NOTE: `style` is ignored. A rejected request always reports which
      # parameters were rejected and why.
      def build_payload(show_details: false, traces: nil, style: nil)
        {errors: error_serializer.new(exception.errors).errors}
      end

      private

      def error_serializer
        Graphiti::ErrorSerializers::InvalidRequest
      end
    end

    class ConflictRequestHandler < InvalidRequestHandler
      private

      def error_serializer
        Graphiti::ErrorSerializers::ConflictRequest
      end
    end
  end
end
