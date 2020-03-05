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
            @polymorphic_sideload_not_found = true unless @sideload
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
        return false if @polymorphic_sideload_not_found

        if @sideload.type == :belongs_to
          !@model.send(@sideload.foreign_key).nil?
        else
          @linkable
        end
      end

      def raw_url
        if @sideload.link_proc
          @sideload.link_proc.call(@model)
        elsif params.empty?
          path
        else
          "#{path}?#{CGI.unescape(params.to_query)}"
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
          if @sideload.type != :belongs_to || @sideload.remote?
            params[:filter] = @sideload.base_filter([@model])
          end

          @sideload.params_proc&.call(params, [@model], context)
        end
      end

      def path
        @path ||=
          path = @sideload.resource.endpoint[:url].to_s
        if @sideload.type == :belongs_to && !@sideload.remote?
          path = "#{path}/#{@model.send(@sideload.foreign_key)}"
        end
        path
      end

      def context
        Graphiti.context[:object]
      end
    end
  end
end
