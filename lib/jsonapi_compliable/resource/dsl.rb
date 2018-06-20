module JsonapiCompliable
  class Resource
    module DSL
      extend ActiveSupport::Concern

      class_methods do
        def allow_filter(name, *args, &blk)
          opts = args.extract_options!
          aliases = [name, opts[:aliases]].flatten.compact
          config[:filters][name.to_sym] = {
            aliases: aliases,
            if: opts[:if],
            filter: blk,
            required: opts[:required].respond_to?(:call) ? opts[:required] : !!opts[:required]
          }
        end

        def sort(&blk)
          config[:sorting] = blk
        end

        def paginate(&blk)
          config[:pagination] = blk
        end

        def extra_field(name, &blk)
          config[:extra_fields][name] = blk
        end

        def allow_stat(symbol_or_hash, &blk)
          dsl = Stats::DSL.new(adapter, symbol_or_hash)
          dsl.instance_eval(&blk) if blk
          config[:stats][dsl.name] = dsl
        end

        def default_filter(name, &blk)
          config[:default_filters][name.to_sym] = {
            filter: blk
          }
        end

        def before_commit(only: [:create, :update, :destroy], &blk)
          Array(only).each do |verb|
            config[:before_commit][verb] = blk
          end
        end
      end
    end
  end
end
