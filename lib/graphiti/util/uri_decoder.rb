module Graphiti
  module Util
    module UriDecoder
      def self.decode_uri(uri)
        Graphiti.config.uri_decoder.call(uri)
      end
    end
  end
end
