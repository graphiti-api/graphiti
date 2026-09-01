module Graphiti
  module SpecHelpers
    module Errors
      class Base < StandardError; end

      class LinksNotFound < Base
        def initialize(name)
          @name = name
        end

        def message
          "Relationship with name '#{@name}' has no links!"
        end
      end

      class NoAttribute < Base
        def initialize(name)
          @name = name
        end

        def message
          "No attribute '#{@name}' in JSON response node!"
        end
      end

      class SideloadNotFound < Base
        def initialize(name)
          @name = name
        end

        def message
          "Relationship with name '#{@name}' not found!"
        end
      end

      class NoResponse < Base
        def message
          "Cannot parse response - missing #response.body!"
        end
      end

      class NoData < Base
        def initialize(payload)
          @payload = payload
        end

        def message
          "Payload did not contain 'data'! Payload was:\n\n#{JSON.pretty_generate(@payload)}"
        end
      end

      class NoSideloads < Base
        def initialize(payload)
          @payload = payload
        end

        def message
          "Tried to find sideload, but the payload did not contain 'included'! Payload was:\n\n#{JSON.pretty_generate(@payload)}"
        end
      end

      class NoMeta < Base
        def initialize(payload)
          @payload = payload
        end

        def message
          "Tried to find metadata, but the payload did not contain 'meta'! Payload was:\n\n#{JSON.pretty_generate(@payload)}"
        end
      end
    end
  end
end
