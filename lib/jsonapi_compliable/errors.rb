module JSONAPICompliable
  module Errors
    class BadFilter < StandardError; end
    class UnsupportedPageSize < StandardError; end
  end
end
