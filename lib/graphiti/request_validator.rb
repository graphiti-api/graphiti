module Graphiti
  class RequestValidator
    delegate :validate,
      :validate!,
      :errors,
      :deserialized_payload,
      to: :@validator

    def initialize(root_resource, raw_params)
      @validator = ValidatorFactory.create(root_resource, raw_params)
    end

    class ValidatorFactory
      def self.create(root_resource, raw_params)
        case raw_params["action"]
        when "update" then
          RequestValidators::UpdateValidator
        else
          RequestValidators::Validator
        end.new(root_resource, raw_params)
      end
    end
  end
end
