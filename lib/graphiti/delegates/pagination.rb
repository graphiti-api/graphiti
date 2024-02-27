module Graphiti
  module Delegates
    class Pagination
      def initialize(proxy)
        @proxy = proxy
      end

      def links?
        @proxy.query.pagination_links? && @proxy.data.present?
      end

      def links
        @links ||= {}.tap do |links|
          links[:self] = pagination_link(current_page)
          links[:first] = pagination_link(1)
          links[:last] = pagination_link(last_page)
          links[:prev] = pagination_link(current_page - 1) if has_previous_page?
          links[:next] = pagination_link(current_page + 1) if has_next_page?
        end.select { |k, v| !v.nil? }
      end

      def has_next_page?
        current_page != last_page && last_page.present?
      end

      def has_previous_page?
        current_page != 1 ||
          !!pagination_params.try(:[], :page).try(:[], :after) ||
          !!pagination_params.try(:[], :page).try(:[], :offset)
      end

      private

      def pagination_params
        @pagination_params ||= @proxy.query.params.reject { |key, _| [:action, :controller, :format].include?(key) }
      end

      def pagination_link(page)
        return nil unless @proxy.resource.endpoint

        uri = URI(@proxy.resource.endpoint[:url].to_s)

        page_params = {
          number: page,
          size: page_size
        }
        page_params[:offset] = offset if offset

        # Overwrite the pagination query params with the desired page
        uri.query = pagination_params.merge(page: page_params).to_query
        uri.to_s
      end

      def last_page
        if @last_page
          return @last_page
        elsif page_size == 0 || item_count == 0
          return nil
        end

        count = item_count
        count = item_count - offset if offset
        @last_page = (count / page_size)
        @last_page += 1 if count % page_size > 0
        @last_page
      end

      def item_count
        begin
          return @item_count if @item_count
          @item_count = item_count_from_proxy || item_count_from_stats
          unless @item_count.is_a?(Numeric)
            raise TypeError, "#{@proxy.resource}.stat(:total, :count) returned an invalid value #{@item_count}"
          end
        rescue
          # FIXME: Unable to log because of how rspec mocks were
          # created for the logger. In other words, logging here will
          # break tests.

          # Graphiti.logger.warn(e.message)
          @item_count = 0
        end
        @item_count
      end

      def item_count_from_proxy
        @proxy.stats.dig(:total, :count)
      end

      def item_count_from_stats
        stats = Stats::Payload.new(@proxy.resource, @proxy.query, @proxy.scope.unpaginated_object, @proxy.data)
        stats.calculate_stat(:total, @proxy.resource.stat(:total, :count))
      end

      def current_page
        @current_page ||= (page_param[:number] || 1).to_i
      end

      def offset
        @offset ||= if (value = page_param[:offset])
          value.to_i
        end
      end

      def page_size
        @page_size ||= (page_param[:size] ||
                        @proxy.resource.default_page_size ||
                        Graphiti::Scoping::Paginate::DEFAULT_PAGE_SIZE).to_i
      end

      def page_param
        @page_param ||= (@proxy.query.hash[:page] || {})
      end
    end
  end
end
