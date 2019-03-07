module Graphiti
  module Util
    # @api private
    class Sideload
      # Determine the namespace for the sideload
      #
      # In other words, given a query like
      # /things?include=a.b
      #
      # When 'a' is sideloading 'b', b's namespace is 'b'.
      #
      # However, consider a recursive tree structure:
      #
      # /things?include=children.children
      #
      # The first occurrance of "children" will have the namespace
      # "children", the second will be "children.children" and so forth.
      #
      # This is used to match up other criteria in the query:
      #
      # ?filter[children.children][a]=b
      #
      # @api private
      def self.namespace(a, b)
        if a.to_s.split(".")[0] == b.to_s
          :"#{a}.#{b}"
        else
          b
        end
      end
    end
  end
end
