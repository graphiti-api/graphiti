# Merged in from the standalone graphiti_spec_helpers gem, retired as of
# Graphiti 2.0. The GraphitiSpecHelpers namespace and the
# "graphiti_spec_helpers/rspec" require path are kept verbatim so existing spec
# suites need no changes beyond dropping the gem from their Gemfile.
require "json"
require "active_support/core_ext/string"
require "active_support/core_ext/hash"
require "graphiti"

require "graphiti/spec_helpers/helpers"
require "graphiti/spec_helpers/node"
require "graphiti/spec_helpers/errors_proxy"
require "graphiti/spec_helpers/errors"
require "graphiti/spec_helpers/matchers"

module Graphiti
  module SpecHelpers
    def self.included(klass)
      klass.send(:include, Helpers)
    end

    class TestRunner < ::Graphiti::Runner
      def current_user
        nil
      end
    end

    module Sugar
      def d
        jsonapi_data
      end

      def included(type = nil)
        jsonapi_included(type)
      end

      def errors
        jsonapi_errors
      end

      def dt(*args)
        json_datetime(*args)
      end

      def datetime(*args)
        json_datetime(*args)
      end

      def date(*args)
        json_date(*args)
      end
    end
  end
end
