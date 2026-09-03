module Graphiti
  module Util
    class PublicIdBlock
      attr_reader :encoder, :decoder

      def encode(&blk)
        @encoder = blk
      end

      def decode(&blk)
        @decoder = blk
      end
    end
  end
end
