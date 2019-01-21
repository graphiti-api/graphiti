module Graphiti
  module Util
    class Link
      def initialize(sideload, model)
        @sideload = sideload
        @model = model

        if @sideload.type == :polymorphic_belongs_to
          type = @model.send(@sideload.grouper.field_name)
          @sideload = @sideload.children.values.find do |c|
            c.group_name == type.to_sym
          end
        end
      end

      def generate
        on_demand_links(raw_url)
      end

      private

      def raw_url
        if @sideload.link_proc
          @sideload.link_proc.call(@model)
        else
          if params.empty?
            path
          else
            "#{path}?#{URI.unescape(params.to_query)}"
          end
        end
      end

      def on_demand_links(url)
        return url unless Graphiti.config.links_on_demand

        if url.include?('?')
          url << '&links=true'
        else
          url << '?links=true'
        end
        url
      end

      def params
        @params ||= {}.tap do |params|
          if @sideload.type != :belongs_to
            params[:filter] = @sideload.base_filter([@model])
          end

          if @sideload.params_proc
            @sideload.params_proc.call(params, [@model])
          end
        end
      end

      def path
        @path ||=
          path = @sideload.resource.endpoint[:url].to_s
          if @sideload.type == :belongs_to
            linked_resource_id = @model.send(@sideload.foreign_key)
            if linked_resource_id
              path = "#{path}/#{linked_resource_id}"
            else
              path = nil
            end
          end
          path
      end
    end
  end
end
