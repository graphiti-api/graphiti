module Graphiti
  module Util
    class CacheDebug
      attr_reader :proxy

      def initialize(proxy)
        @proxy = proxy
      end

      def last_version
        @last_version ||= Graphiti.cache.read(key) || {}
      end

      def name
        tag = proxy.resource_cache_tag

        "#{::Graphiti.context[:object]&.request&.method} #{::Graphiti.context[:object]&.request&.url} #{tag}"
      end

      def key
        "graphiti:debug/#{name}"
      end

      def current_version
        @current_version ||= {
          cache_key: proxy.cache_key_with_version,
          version: proxy.updated_at,
          expires_in: proxy.cache_expires_in,
          etag: proxy.etag,
          miss_count: last_version[:miss_count].to_i + (changed_key? ? 1 : 0),
          hit_count: last_version[:hit_count].to_i + (!changed_key? && !new_key? ? 1 : 0),
          request_count: last_version[:request_count].to_i + (last_version.present? ? 1 : 0)
        }
      end

      def analyze
        yield self
        save
      end

      def request_count
        current_version[:request_count]
      end

      def miss_count
        current_version[:miss_count]
      end

      def hit_count
        current_version[:hit_count]
      end

      def change_percentage
        return 0 if request_count == 0
        (miss_count.to_i / request_count.to_f * 100).round(1)
      end

      def volatile?
        change_percentage > 50
      end

      def new_key?
        last_version[:cache_key].blank? && proxy.cache_key_with_version
      end

      def changed_key?
        last_version[:cache_key] != proxy.cache_key_with_version && !new_key?
      end

      def removed_segments
        changes[1] - changes[0]
      end

      def added_segments
        changes[0] - changes[1]
      end

      def changes
        sub_keys_old = last_version[:cache_key]&.scan(/\w+\/query-[a-z0-9-]+\/args-[a-z0-9-]+/).to_a || []
        sub_keys_new = current_version[:cache_key]&.scan(/\w+\/query-[a-z0-9-]+\/args-[a-z0-9-]+/).to_a || []

        [sub_keys_old, sub_keys_new]
      end

      def save
        Graphiti.cache.write(key, current_version)
      end
    end
  end
end
