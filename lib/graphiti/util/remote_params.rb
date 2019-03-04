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
        if (include_hash = @query.include_hash.presence)
          @params[:include] = trim_sideloads(include_hash)
        end
        collect_params(@query, @resource)
        @params[:sort] = @sorts.join(",") if @sorts.present?
        @params[:filter] = @filters if @filters.present?
        @params[:page] = @pagination if @pagination.present?
        @params[:fields] = @fields if @fields.present?
        @params[:extra_fields] = @extra_fields if @extra_fields.present?
        @params[:stats] = @stats if @stats.present?
        @params
      end

      private

      # If this is a remote call, we don't care about local parents
      # When polymorphic, query is top-level (ie, query.resource is
      # the parent, not a child type implementation).
      # This is why we pass BOTH the resource and the query
      def query_chain(resource, query)
        top_remote_parent = query.parents.find { |p| p.resource.remote? }
        [].tap do |chain|
          query.parents.select { |p| p.resource.remote? }.each do |p|
            chain << p.association_name unless p == top_remote_parent
          end
          immediate_parent = query.parents.reverse[0]
          # This is not currently checking that it is a remote of the same API
          chain << query.association_name if immediate_parent&.resource&.remote
          chain.compact
        end.compact
      end

      def collect_params(query, resource = nil)
        query_hash = query.hash
        resource ||= query.resource
        chain = query_chain(resource, query)
        process_sorts(query_hash[:sort], chain)
        process_fields(query.fields.merge(query.hash[:fields] || {}))
        process_extra_fields(query.extra_fields.merge(query.hash[:extra_fields] || {}))
        process_filters(query_hash[:filter], chain)
        process_pagination(query_hash[:page], chain)
        process_stats(query_hash[:stats])

        query.sideloads.each_pair do |assn_name, nested_query|
          unless @resource.class.sideload(assn_name)
            collect_params(nested_query)
          end
        end
      end

      def process_stats(stats)
        return unless stats.present?
        @stats = {stats.keys.first => stats.values.join(",")}
      end

      def process_pagination(page, chain)
        return unless page.present?
        if (size = page[:size])
          key = (chain + [:size]).join(".")
          @pagination[key.to_sym] = size
        end
        if (number = page[:number])
          key = (chain + [:number]).join(".")
          @pagination[key.to_sym] = number
        end
      end

      def process_filters(filters, chain)
        return unless filters.present?
        filters.each_pair do |att, config|
          att = (chain + [att]).join(".")
          @filters[att.to_sym] = config
        end
      end

      def process_fields(fields)
        return unless fields

        fields.each_pair do |type, attrs|
          @fields[type] = attrs.join(",")
        end
      end

      def process_extra_fields(fields)
        return unless fields

        fields.each_pair do |type, attrs|
          @extra_fields[type] = attrs.join(",")
        end
      end

      def process_sorts(sorts, chain)
        return unless sorts

        if sorts.is_a?(String) # manually assigned
          @sorts << sorts
        else
          sorts.each do |s|
            sort = (chain + [s.keys.first]).join(".")
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
