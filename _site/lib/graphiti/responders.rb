# If you're using Rails + responders gem to get respond_with
module Graphiti
  module Responders
    extend ActiveSupport::Concern

    included do
      include ActionController::MimeResponds
      respond_to(*Graphiti.config.respond_to)
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
