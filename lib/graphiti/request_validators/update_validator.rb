module Graphiti
  module RequestValidators
    class UpdateValidator < Validator
      def validate
        if required_payload? && payload_matches_endpoint?
          super
        else
          false
        end
      end

      private

      def attribute_mismatch(attr_path)
        @error_class = Graphiti::Errors::ConflictRequest
        @errors.add(
          attr_path.join("."),
          :attribute_mismatch,
          message: "does not match the server endpoint"
        )
      end

      def required_payload?
        [
          [:data],
          [:data, :type],
          [:data, :id]
        ].each do |required_attr|
          attribute_mismatch(required_attr) unless @params.dig(*required_attr)
        end
        errors.blank?
      end

      def payload_matches_endpoint?
        unless @params.dig(:data, :id) == @params.dig(:filter, :id)
          attribute_mismatch([:data, :id])
        end

        meta_type = @params.dig(:data, :type)

        # NOTE: calling #to_s and comparing 2 strings is slower than
        # calling #to_sym and comparing 2 symbols. But pre ruby-2.2
        # #to_sym on user supplied data would lead to a memory leak.
        if @root_resource.type.to_s != meta_type
          if @root_resource.polymorphic?
            begin
              @root_resource.class.resource_for_type(meta_type).new
            rescue Errors::PolymorphicResourceChildNotFound
              attribute_mismatch([:data, :type])
            end
          else
            attribute_mismatch([:data, :type])
          end
        end

        errors.blank?
      end
    end
  end
end
