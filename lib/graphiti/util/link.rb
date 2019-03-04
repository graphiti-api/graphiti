module Graphiti
  module Util
    class Link
      def initialize(sideload, model)
        @sideload = sideload
        @model = model
        @linkable = true

        if @sideload.type == :polymorphic_belongs_to
          if (type = @model.send(@sideload.grouper.field_name))
            @sideload = @sideload.children.values.find { |c|
              c.group_name == type.to_sym
            }
          else
            @linkable = false
          end
        end
      end

      def generate
        if linkable?
          on_demand_links(raw_url)
        end
      end

      private

      def linkable?
        if @sideload.type == :belongs_to
          !@model.send(@sideload.foreign_key).nil?
        else
          @linkable
        end
      end

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

        url << if url.include?("?")
          "&links=true"
        else
          "?links=true"
        end
        url
      end

      def params
        @params ||= {}.tap do |params|
          if @sideload.type != :belongs_to
            params[:filter] = @sideload.base_filter([@model])
          end

          @sideload.params_proc&.call(params, [@model])
        end
      end

      def path
        @path ||=
          path = @sideload.resource.endpoint[:url].to_s
        if @sideload.type == :belongs_to
          path = "#{path}/#{@model.send(@sideload.foreign_key)}"
        end
        path
      end
    end
  end
end
