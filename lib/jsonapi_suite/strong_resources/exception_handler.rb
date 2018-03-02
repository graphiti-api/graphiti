module JsonapiSuite
  module StrongResources
    class ExceptionHandler < JsonapiErrorable::ExceptionHandler
      SPLIT_REGEX = /^Invalid parameter: ([\w]+)\W(.*)/

      def error_payload(error)
        message_parse = error.message.match(SPLIT_REGEX)

        attribute = message_parse[1]
        message = message_parse[2]
        error = {
          code:   'unprocessable_entity',
          status: '400',
          title: 'Malformed Attribute',
          detail: error.message,
          source: { pointer: "/data/attributes/#{attribute}" },
          meta:   {
            attribute: attribute,
            message: message
          }
        }

        {
          "errors" => [error]
        }
      end

      def status_code(_)
        400
      end

      def log?
        false
      end
    end
  end
end
