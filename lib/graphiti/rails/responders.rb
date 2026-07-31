# For use with the `responders` gem responders gem to get respond_with
module Graphiti
  module Rails
    module Responders
      extend ActiveSupport::Concern

      included do
        include ActionController::MimeResponds
        respond_to(*Graphiti::Rails.respond_to_formats)
      end

      # Override to avoid location url generation (for now)
      def respond_with(*args, &blk)
        opts = args.extract_options!
        opts[:location] = nil
        args << opts
        super(*args, &blk)
      end
    end
  end
end
