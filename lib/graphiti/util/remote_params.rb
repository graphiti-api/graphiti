# Todo: class purpose
module Graphiti
  module Util
    class RemoteParams
      def self.generate(resource, query)
        new(resource, query).generate
      end

      def initialize(resource, query)
        @resource = resource
        @query = query
        @sorts = []
        @filters = {}
        @fields = {}
        @extra_fields = {}
        @pagination = {}
        @params = {}
      end

      def generate
        if include_hash = @query.include_hash.presence
          @params[:include] = trim_sideloads(include_hash)
        end
        collect_params(@query)
        @params[:sort] = @sorts.join(',') if @sorts.present?
        @params[:filter] = @filters if @filters.present?
        @params[:page] = @pagination if @pagination.present?
        @params[:fields] = @fields if @fields.present?
        @params[:extra_fields] = @extra_fields if @extra_fields.present?
        @params[:stats] = @stats if @stats.present?
        @params
      end

      private

      def collect_params(query)
        query_hash = query.hash
        process_sorts(query_hash[:sort], query)
        process_fields(query.fields.merge(query.hash[:fields] || {}))
        process_extra_fields(query.extra_fields.merge(query.hash[:extra_fields] || {}))
        process_filters(query_hash[:filter], query)
        process_pagination(query_hash[:page], query)
        process_stats(query_hash[:stats])

        query.sideloads.each_pair do |assn_name, nested_query|
          unless @resource.class.sideload(assn_name)
            collect_params(nested_query)
          end
        end
      end

      def process_stats(stats)
        return unless stats.present?
        @stats = { stats.keys.first => stats.values.join(',') }
      end

      def process_pagination(page, query)
        return unless page.present?
        if size = page[:size]
          key = (query.chain + [:size]).join('.')
          @pagination[key.to_sym] = size
        end
        if number = page[:number]
          key = (query.chain + [:number]).join('.')
          @pagination[key.to_sym] = number
        end
      end

      def process_filters(filters, query)
        return unless filters.present?
        filters.each_pair do |att, config|
          att = (query.chain + [att]).join('.')
          @filters[att.to_sym] = config
        end
      end

      def process_fields(fields)
        return unless fields

        fields.each_pair do |type, attrs|
          @fields[type] = attrs.join(',')
        end
      end

      def process_extra_fields(fields)
        return unless fields

        fields.each_pair do |type, attrs|
          @extra_fields[type] = attrs.join(',')
        end
      end

      def process_sorts(sorts, query)
        return unless sorts

        if sorts.is_a?(String) # manually assigned
          @sorts << sorts
        else
          sorts.each do |s|
            sort = (query.chain + [s.keys.first]).join('.')
            sort = "-#{sort}" if s.values.first == :desc
            @sorts << sort
          end
        end
      end

      # Do not pass local sideloads to the remote endpoint
      def trim_sideloads(include_hash)
        return unless include_hash.present?

        include_hash.each_pair do |assn_name, nested|
          sideload = @resource.class.sideload(assn_name)
          if sideload && !sideload.shared_remote?
            include_hash.delete(assn_name)
          end
        end
        JSONAPI::IncludeDirective.new(include_hash).to_string
      end
    end
  end
end
