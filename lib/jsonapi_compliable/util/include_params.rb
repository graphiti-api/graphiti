module JsonapiCompliable
  module Util
    class IncludeParams
      class << self
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
