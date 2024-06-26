class Graphiti::Sideload::PolymorphicBelongsTo < Graphiti::Sideload::BelongsTo
  class Group
    attr_reader :name, :calls

    def initialize(name)
      @name = name
      @calls = []
    end

    def method_missing(name, *args, &blk)
      @calls << [name, args, blk]
    end
    # rubocop: enable Style/MethodMissingSuper

    def respond_to_missing?(*args)
      true
    end
  end

  class Grouper
    attr_reader :field_name

    def initialize(field_name, opts = {})
      @field_name = field_name
      @groups = []
      @except = Array(opts[:except]).map(&:to_sym)
      @only = Array(opts[:only]).map(&:to_sym)
    end

    def expected?(group_sym)
      @only.empty? || @only.include?(group_sym)
    end

    def excluded?(group_sym)
      @except.include?(group_sym)
    end

    def ignore?(group_name)
      group_sym = group_name.to_sym
      !expected?(group_sym) || excluded?(group_sym)
    end

    def on(name, &blk)
      group = Group.new(name.to_sym)
      @groups << group
      group
    end

    def apply(sideload, resource_class)
      @groups.each do |group|
        if group.calls.empty?
          group.belongs_to(group.name.to_s.underscore.to_sym)
        end
        group.calls.each do |call|
          args = call[1]
          opts = args.extract_options!
          opts.merge! as: sideload.name,
            parent: sideload,
            group_name: group.name,
            polymorphic_child: true
          unless sideload.resource.class.abstract_class?
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

  def self.group_by(name, opts = {}, &blk)
    self.grouper = Grouper.new(name, opts)
    grouper.instance_eval(&blk)
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

  def child_for_type!(type)
    if (child = child_for_type(type))
      child
    else
      err = ::Graphiti::Errors::PolymorphicSideloadTypeNotFound
      raise err.new(self, type)
    end
  end

  def resolve(parents, query, graph_parent)
    future_resolve(parents, query, graph_parent).value!
  end

  def future_resolve(parents, query, graph_parent)
    promises = parents.group_by(&grouper.field_name).filter_map do |(group_name, group)|
      next if group_name.nil? || grouper.ignore?(group_name)

      match = ->(c) { c.group_name == group_name.to_sym }
      if (sideload = children.values.find(&match))
        duped = remove_invalid_sideloads(sideload.resource, query)
        sideload.future_resolve(group, duped, graph_parent)
      else
        err = ::Graphiti::Errors::PolymorphicSideloadChildNotFound
        raise err.new(self, group_name)
      end
    end
    Concurrent::Promises.zip(*promises)
  end

  private

  # We may be requesting a relationship that some subclasses support,
  # but not others. Remove anything we don't support.
  # TODO: spec to ensure this dupe logic doesn't mutate the original
  def remove_invalid_sideloads(resource, query)
    duped = query.dup
    duped.instance_variable_set(:@hash, nil)
    duped.instance_variable_set(:@sideloads, ::Graphiti::Util::Hash.deep_dup(query.sideloads))
    duped.sideloads.each_pair do |key, value|
      unless resource.class.sideload(key)
        duped.sideloads.delete(key)
      end
    end
    duped
  end
end
