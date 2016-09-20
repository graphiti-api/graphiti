module JsonapiCompliable
  module Util
    class IncludeParams
      def self.compare(includes, whitelist)
        {}.tap do |valid|
          includes.to_hash.each_pair do |key, sub_hash|
            if whitelist[key]
              valid[key] = compare(sub_hash, whitelist[key])
            end
          end
        end
      end

      def self.scrub(controller)
        dsl       = controller._jsonapi_compliable
        whitelist = dsl.sideloads[:whitelist] || {}
        whitelist = whitelist[controller.action_name]
        includes  = JSONAPI::IncludeDirective.new(controller.params[:include])

        if whitelist
          Util::IncludeParams.compare(includes, whitelist)
        else
          {}
        end
      end
    end
  end
end
