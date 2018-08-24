module Graphiti
  module Util
    # Utility class for dealing with Include Directives
    class IncludeParams
      class << self
        # Let's say the user requested these sideloads:
        #
        #   GET /posts?include=comments.author
        #
        # But our resource had this code:
        #
        #   sideload_allowlist({ index: [:comments] })
        #
        # We should drop the 'author' sideload from the request.
        #
        # Hashes become 'include directive hashes' within the library. ie
        #
        #   [:tags, { comments: :author }]
        #
        # Becomes
        #
        #   { tags: {}, comments: { author: {} } }
        #
        # @param [Hash] requested_includes the nested hash the user requested
        # @param [Hash] allowed_includes the nested hash configured via DSL
        # @return [Hash] the scrubbed hash
        def scrub(requested_includes, allowed_includes)
          {}.tap do |valid|
            requested_includes.each_pair do |key, sub_hash|
              if allowed_includes[key]
                valid[key] = scrub(sub_hash, allowed_includes[key])
              end
            end
          end
        end
      end
    end
  end
end
