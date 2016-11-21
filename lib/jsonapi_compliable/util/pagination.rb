module JsonapiCompliable
  module Util
    class Pagination
      def self.zero?(params)
        params = params[:page] || params['page'] || {}
        size   = params[:size] || params['size']
        [0, '0'].include?(size)
      end
    end
  end
end
