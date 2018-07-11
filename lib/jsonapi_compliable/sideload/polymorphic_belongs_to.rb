class JsonapiCompliable::Sideload::PolymorphicBelongsTo < JsonapiCompliable::Sideload::BelongsTo
  class Group
    attr_reader :name, :calls

    def initialize(name)
      @name = name
      @calls = []
    end

    def method_missing(name, *args, &blk)
      @calls << [name, args, blk]
    end
  end

  class Grouper
    attr_reader :column_name

    def initialize(column_name)
      @column_name = column_name
      @groups = []
    end

    def on(name, &blk)
      group = Group.new(name)
      @groups << group
      group.belongs_to(name.to_s.underscore.to_sym)
      group
    end

    def apply(sideload, resource_class)
      @groups.each do |group|
        group.calls.each do |call|
          args = call[1]
          opts = args.extract_options!
          opts.merge! as: sideload.name,
            parent: sideload,
            group_name: group.name,
            polymorphic_child: true
          if !sideload.resource.class.abstract_class?
            opts[:foreign_key] ||= sideload.foreign_key
            opts[:primary_key] ||= sideload.primary_key
          end
          args << opts
          resource_class.send(call[0], *args, &call[2])
        end
      end
    end
  end

  class_attribute :grouper
  attr_accessor :children
  self.grouper = Grouper.new(:default)

  def type
    :polymorphic_belongs_to
  end

  def infer_foreign_key
    :"#{name}_id"
  end

  def self.group_by(name, &blk)
    self.grouper = Grouper.new(name)
    self.grouper.instance_eval(&blk)
  end

  def initialize(name, opts)
    super
    self.children = {}
    grouper.apply(self, parent_resource_class)
  end

  def child_for_type(type)
    children.values.find do |sideload|
      sideload.resource.type == type
    end
  end

  def resolve(parents, query)
    parents.group_by(&grouper.column_name).each_pair do |group_name, group|
      next if group_name.nil?

      match = ->(name, sl) { sl.group_name == group_name.to_sym }
      if child = children.find(&match)
        sideload = child[1]
        query = remove_invalid_sideloads(sideload.resource, query)
        sideload.resolve(group, query)
      else
        err = ::JsonapiCompliable::Errors::PolymorphicChildNotFound
        raise err.new(self, group_name)
      end
    end
  end

  private

  # We may be requesting a relationship that some subclasses support,
  # but not others. Remove anything we don't support.
  def remove_invalid_sideloads(resource, query)
    query = query.dup
    query.sideloads.each_pair do |key, value|
      unless resource.class.sideload(key)
        query.sideloads.delete(key)
      end
    end
    query
  end
end
