module Graphiti
  class Resource
    module Persistence
      extend ActiveSupport::Concern

      class_methods do
        def before_attributes(method = nil, only: [:create, :update], &blk)
          add_callback(:attributes, :before, method, only, &blk)
        end

        def after_attributes(method = nil, only: [:create, :update], &blk)
          add_callback(:attributes, :after, method, only, &blk)
        end

        def before_save(method = nil, only: [:create, :update], &blk)
          add_callback(:save, :before, method, only, &blk)
        end

        def after_save(method = nil, only: [:create, :update], &blk)
          add_callback(:save, :after, method, only, &blk)
        end

        def before_destroy(method = nil, &blk)
          add_callback(:destroy, :before, method, [:destroy], &blk)
        end

        def after_destroy(method = nil, &blk)
          add_callback(:destroy, :after, method, [:destroy], &blk)
        end

        def around_attributes(method = nil, only: [:create, :update], &blk)
          if blk
            raise Errors::AroundCallbackProc.new(self, 'around_attributes')
          else
            add_callback(:attributes, :around, method, only, &blk)
          end
        end

        def around_save(method = nil, only: [:create, :update], &blk)
          if blk
            raise Errors::AroundCallbackProc.new(self, 'around_save')
          else
            add_callback(:save, :around, method, only, &blk)
          end
        end

        def around_persistence(method = nil, only: [:create, :update], &blk)
          if blk
            raise Errors::AroundCallbackProc.new(self, 'around_persistence')
          else
            add_callback(:persistence, :around, method, only, &blk)
          end
        end

        def around_destroy(method = nil, &blk)
          if blk
            raise Errors::AroundCallbackProc.new(self, 'around_destroy')
          else
            add_callback(:destroy, :around, method, [:destroy], &blk)
          end
        end

        private

        def add_callback(kind, lifecycle, method = nil, only, &blk)
          config[:callbacks][kind] ||= {}
          config[:callbacks][kind][lifecycle] ||= []
          config[:callbacks][kind][lifecycle] << { callback: (method || blk), only: Array(only) }
        end
      end

      def create(create_params)
        model_instance = nil

        run_callbacks :persistence, :create, create_params do
          run_callbacks :attributes, :create, create_params do |params|
            model_instance = build(model)
            assign_attributes(model_instance, params)
            model_instance
          end

          run_callbacks :save, :create, model_instance do
            model_instance = save(model_instance)
          end

          model_instance
        end
      end

      def update(update_params)
        model_instance = nil
        id = update_params.delete(:id)

        run_callbacks :persistence, :update, update_params do
          run_callbacks :attributes, :update, update_params do |params|
            model_instance = self.class._find(params.merge(id: id)).data
            assign_attributes(model_instance, params)
            model_instance
          end

          run_callbacks :save, :update, model_instance do
            model_instance = save(model_instance)
          end
        end

        model_instance
      end

      def destroy(id)
        model_instance = self.class._find(id: id).data
        run_callbacks :destroy, :destroy, model_instance do
          adapter.destroy(model_instance)
        end
        model_instance
      end

      def build(model)
        adapter.build(model)
      end

      def assign_attributes(model_instance, update_params)
        adapter.assign_attributes(model_instance, update_params)
      end

      def save(model_instance)
        adapter.save(model_instance)
      end

      private

      def run_callbacks(kind, action, *args)
        fire_around_callbacks(kind, action, *args) do |*yieldargs|
          fire_callbacks(kind, :before, action, *yieldargs)
          result = yield(*yieldargs)
          fire_callbacks(kind, :after, action, result)
          result
        end
      end

      def fire_callbacks(kind, lifecycle, action, *args)
        if callbacks = self.class.config[:callbacks][kind]
          callbacks = callbacks[lifecycle] || []
          callbacks.each do |config|
            callback = config[:callback]
            next unless config[:only].include?(action)

            if callback.respond_to?(:call)
              instance_exec(*args, &callback)
            else
              send(callback, *args)
            end
          end
        end
      end

      def fire_around_callbacks(kind, action, *args, &blk)
        callbacks = self.class.config[:callbacks][kind].try(:[], :around) || []
        callbacks = callbacks.select { |cb| cb[:only].include?(action) }
        if callbacks.length.zero?
          yield(*args)
        else
          prc = around_callback_proc(callbacks, 0, *args, &blk)
          instance_exec(*args, &prc)
        end
      end

      # The tricky thing here is we need to yield to the next around callback
      # until there are no more callbacks, then we want to call the original block
      # Also keep in mind each callback needs to yield to the next
      def around_callback_proc(callbacks, index, *args, &blk)
        method_name = callbacks[index][:callback]

        if callbacks[index + 1]
          proc do
            r = nil
            send(method_name, *args) do |r2|
              wrapped = around_callback_proc(callbacks, index+1, r2, &blk)
              r = instance_exec(r2, &wrapped)
            end
            r
          end
        else
          proc do |result|
            r = nil
            send(callbacks[index][:callback], result) do |r2|
              r = instance_exec(r2, &blk)
            end
            r
          end
        end
      end
    end
  end
end
