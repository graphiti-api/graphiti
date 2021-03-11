module Graphiti
  class RequestValidator
    delegate :validate,
      :validate!,
      :errors,
      :deserialized_payload,
      to: :@validator

    def initialize(root_resource, raw_params, action)
      @validator = ValidatorFactory.create(root_resource, raw_params, action)
    end

    class ValidatorFactory
      def self.create(root_resource, raw_params, action)
        case action
        when :update
          RequestValidators::UpdateValidator
        else
          RequestValidators::Validator
        end.new(root_resource, raw_params, action)
      end
    end
  end
end
