module JsonapiCompliable
  class Resource
    module Configuration
      extend ActiveSupport::Concern

      included do
        class << self
          attr_writer :config
        end

        class_attribute :adapter,
          :model,
          :type,
          :default_page_size,
          :default_sort

        self.adapter ||= Adapters::Abstract.new
        self.default_sort ||= []
        self.default_page_size ||= 20
        self.type ||= :undefined_jsonapi_type
      end

      class_methods do
        def sideloads
          config[:sideloads]
        end

        def config
          @config ||=
            {
              filters: {},
              default_filters: {},
              extra_fields: {},
              stats: {},
              sorting: nil,
              pagination: nil,
              before_commit: {},
              sideloads: {}
            }
        end
      end

      def filters
        self.class.config[:filters]
      end

      def sorting
        self.class.config[:sorting]
      end

      def stats
        self.class.config[:stats]
      end

      def pagination
        self.class.config[:pagination]
      end

      def extra_fields
        self.class.config[:extra_fields]
      end

      def default_filters
        self.class.config[:default_filters]
      end
    end
  end
end
