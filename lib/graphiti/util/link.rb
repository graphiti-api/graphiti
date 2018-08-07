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
        if params.empty?
          path
        else
          "#{path}?#{URI.unescape(params.to_query)}"
        end
      end

      private

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
            path = "#{path}/#{@model.send(@sideload.foreign_key)}"
          end
          path
      end
    end
  end
end
