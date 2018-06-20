module JsonapiCompliable
  class Resource
    module Sideloading
      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        def allow_sideload(name, opts = {}, &blk)
          klass = Class.new(opts.delete(:class) || Sideload)
          klass.class_eval(&blk) if blk
          opts[:parent_resource] = self
          sideload = klass.new(name, opts)
          config[:sideloads][name] = sideload
          sideload
        end

        def has_many(name, opts = {}, &blk)
          opts[:class] = adapter.sideloading_classes[:has_many]
          allow_sideload(name, opts, &blk)
        end

        def belongs_to(name, opts = {}, &blk)
          opts[:class] = adapter.sideloading_classes[:belongs_to]
          allow_sideload(name, opts, &blk)
        end

        def has_one(name, opts = {}, &blk)
          opts[:class] = adapter.sideloading_classes[:has_one]
          allow_sideload(name, opts, &blk)
        end

        def many_to_many(name, opts = {}, &blk)
          opts[:class] = adapter.sideloading_classes[:many_to_many]
          allow_sideload(name, opts, &blk)
        end

        def sideload(name)
          sideloads[name]
        end

        def all_sideloads(memo = {})
          sideloads.each_pair do |name, sideload|
            unless memo[name]
              memo[name] = sideload
              memo.merge!(sideload.resource.class.all_sideloads(memo))
            end
          end
          memo
        end

        def association_names(memo = [])
          all_sideloads.each_pair do |name, sl|
            unless memo.include?(sl.name)
              memo << sl.name
              memo |= sl.resource.class.association_names(memo)
            end
          end

          memo
        end
      end
    end
  end
end
