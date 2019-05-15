# If you're using Rails + responders gem to get respond_with
module Graphiti
  module Responders
    extend ActiveSupport::Concern

    included do
      backtrace = ::Rails::VERSION::MAJOR == 4 ? caller(2) : caller_locations(2)
      DEPRECATOR.deprecation_warning("Including Graphiti::Responders", "Use graphiti-rails instead. See https://www.graphiti.dev/guides/graphiti-rails-migration for details.", backtrace)
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
