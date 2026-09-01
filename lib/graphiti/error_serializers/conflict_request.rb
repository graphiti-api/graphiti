module Graphiti
  module ErrorSerializers
    # graphiti_errors overrode only the status here, and so reported a 409
    # alongside code "bad_request".
    class ConflictRequest < InvalidRequest
      STATUS = 409

      private

      def code
        "conflict"
      end

      def default_title
        "Conflict Error"
      end
    end
  end
end
