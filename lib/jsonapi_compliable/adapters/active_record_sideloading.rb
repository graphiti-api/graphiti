module JsonapiCompliable
  module Adapters
    module ActiveRecordSideloading
      def has_many(association_name, scope: nil, resource:, foreign_key:, primary_key: :id, &blk)
        _scope = scope

        allow_sideload association_name, type: :has_many, resource: resource, foreign_key: foreign_key, primary_key: primary_key do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(primary_key) }
            _scope.call.where(foreign_key => parent_ids.uniq.compact)
          end

          assign do |parents, children|
            parents.each do |parent|
              parent.association(association_name).loaded!
              relevant_children = children.select { |c| c.send(foreign_key) == parent.send(primary_key) }
              relevant_children.each do |c|
                parent.association(association_name).add_to_target(c, :skip_callbacks)
              end
            end
          end

          instance_eval(&blk) if blk
        end
      end

      def belongs_to(association_name, scope: nil, resource:, foreign_key:, primary_key: :id, &blk)
        _scope = scope

        allow_sideload association_name, type: :belongs_to, resource: resource, foreign_key: foreign_key, primary_key: primary_key do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(foreign_key) }
            _scope.call.where(primary_key => parent_ids.uniq.compact)
          end

          assign do |parents, children|
            parents.each do |parent|
              relevant_child = children.find { |c| parent.send(foreign_key) == c.send(primary_key) }
              parent.send(:"#{association_name}=", relevant_child)
            end
          end

          instance_eval(&blk) if blk
        end
      end

      def has_one(association_name, scope: nil, resource:, foreign_key:, primary_key: :id, &blk)
        _scope = scope

        allow_sideload association_name, type: :has_one, foreign_key: foreign_key, primary_key: primary_key, resource: resource do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(primary_key) }
            _scope.call.where(foreign_key => parent_ids.uniq.compact)
          end

          assign do |parents, children|
            parents.each do |parent|
              parent.association(association_name).loaded!
              relevant_child = children.find { |c| c.send(foreign_key) == parent.send(primary_key) }
              next unless relevant_child
              parent.association(association_name).replace(relevant_child, false)
            end
          end

          instance_eval(&blk) if blk
        end
      end

      def has_and_belongs_to_many(association_name, scope: nil, resource:, foreign_key:, primary_key: :id, as: nil, &blk)
        through = foreign_key.keys.first
        fk      = foreign_key.values.first
        _scope  = scope

        allow_sideload association_name, type: :habtm, foreign_key: foreign_key, primary_key: primary_key, resource: resource do
          scope do |parents|
            parent_ids = parents.map { |p| p.send(primary_key) }
            parent_ids.uniq!
            parent_ids.compact!
            _scope.call
              .joins(through)
              .preload(through) # otherwise n+1 as we reference in #assign
              .where(through => { fk => parent_ids })
              .distinct
          end

          assign do |parents, children|
            parents.each do |parent|
              parent.association(association_name).loaded!
              relevant_children = children.select { |c| c.send(through).any? { |ct| ct.send(fk) == parent.send(primary_key) } }
              relevant_children.each do |c|
                parent.association(association_name).add_to_target(c, :skip_callbacks)
              end
            end
          end

          instance_eval(&blk) if blk
        end
      end

      def polymorphic_belongs_to(association_name, group_by:, groups:, &blk)
        allow_sideload association_name, type: :polymorphic_belongs_to, polymorphic: true do
          group_by(group_by)

          groups.each_pair do |type, config|
            primary_key = config[:primary_key] || :id
            foreign_key = config[:foreign_key]

            allow_sideload type, parent: self, primary_key: primary_key, foreign_key: foreign_key, type: :belongs_to, resource: config[:resource] do
              scope do |parents|
                parent_ids = parents.map { |p| p.send(foreign_key) }
                parent_ids.compact!
                parent_ids.uniq!
                config[:scope].call.where(primary_key => parent_ids)
              end

              assign do |parents, children|
                parents.each do |parent|
                  parent.send(:"#{association_name}=", children.find { |c| c.send(primary_key) == parent.send(foreign_key) })
                end
              end
            end
          end
        end

        instance_eval(&blk) if blk
      end
    end
  end
end
