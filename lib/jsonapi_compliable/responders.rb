# If you're using Rails + responders gem to get respond_with
module JsonapiCompliable
  module Responders
    extend ActiveSupport::Concern

    included do
      include ActionController::MimeResponds
      respond_to :json, :jsonapi, :xml, :api_json
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
