# Save the given Resource#model, and all of its nested relationships.
# @api private
class Graphiti::Util::Persistence
  # @param [Resource] resource the resource instance
  # @param [Hash] meta see (Deserializer#meta)
  # @param [Hash] attributes see (Deserializer#attributes)
  # @param [Hash] relationships see (Deserializer#relationships)
  # @param [Model] caller_model The persisted parent object in the request graph
  # @param [Symbol] foreign_key Attribute assigned by parent object in graph
  def initialize(resource, meta, attributes, relationships, caller_model, foreign_key = nil)
    @resource = resource
    @meta = meta
    @attributes = attributes
    @relationships = relationships
    @caller_model = caller_model
    @foreign_key = foreign_key

    # Find the correct child resource for a given jsonapi type
    if (meta_type = @meta[:type].try(:to_sym))
      if @resource.type != meta_type && @resource.polymorphic?
        @resource = @resource.class.resource_for_type(meta_type).new
      end
    end
  end

  # Perform the actual save logic.
  #
  # belongs_to must be processed before/separately from has_many -
  # we need to know the primary key value of the parent before
  # persisting the child.
  #
  # Flow:
  # * process parents
  # * update attributes to reflect parent primary keys
  # * persist current object
  # * associate temp id with current object
  # * associate parent objects with current object
  # * process children
  # * associate children
  # * record hooks for later playback
  # * run post-process sideload hooks
  # * return current object
  #
  # @return a model instance
  def run
    parents = process_belongs_to(@relationships)
    update_foreign_key_for_parents(parents)

    persisted = persist_object(@meta[:method], @attributes)
    @resource.decorate_record(persisted)
    assign_temp_id(persisted, @meta[:temp_id])

    associate_parents(persisted, parents)

    children = process_has_many(@relationships, persisted) { |x|
      update_foreign_key(persisted, x[:attributes], x)
    }

    associate_children(persisted, children) unless @meta[:method] == :destroy

    post_process(persisted, parents)
    post_process(persisted, children)
    after_graph_persist = -> { @resource.after_graph_persist(persisted, metadata) }
    add_hook(after_graph_persist, :after_graph_persist)
    before_commit = -> { @resource.before_commit(persisted, metadata) }
    add_hook(before_commit, :before_commit)
    after_commit = -> { @resource.after_commit(persisted, metadata) }
    add_hook(after_commit, :after_commit)
    persisted
  end

  private

  def add_hook(prc, lifecycle_event)
    ::Graphiti::Util::TransactionHooksRecorder.add(prc, lifecycle_event)
  end

  # The child's attributes should be modified to nil-out the
  # foreign_key when the parent is being destroyed or disassociated
  #
  # This is not the case for HABTM, whose "foreign key" is a join table
  def update_foreign_key(parent_object, attrs, x)
    return if x[:sideload].type == :many_to_many

    if [:destroy, :disassociate].include?(x[:meta][:method])
      if x[:sideload].polymorphic_has_one? || x[:sideload].polymorphic_has_many?
        attrs[:"#{x[:sideload].polymorphic_as}_type"] = nil
      end
      attrs[x[:foreign_key]] = nil
      update_foreign_type(attrs, x, null: true) if x[:is_polymorphic]
    else
      if x[:sideload].polymorphic_has_one? || x[:sideload].polymorphic_has_many?
        attrs[:"#{x[:sideload].polymorphic_as}_type"] = parent_object.class.name
      end
      attrs[x[:foreign_key]] = parent_object.send(x[:primary_key])
      update_foreign_type(attrs, x) if x[:is_polymorphic]
    end
  end

  def update_foreign_type(attrs, x, null: false)
    grouping_field = x[:sideload].parent.grouper.field_name
    attrs[grouping_field] = null ? nil : x[:sideload].group_name
  end

  def update_foreign_key_for_parents(parents)
    parents.each do |x|
      update_foreign_key(x[:object], @attributes, x)
    end
  end

  def associate_parents(object, parents)
    # No need to associate to destroyed objects
    parents = parents.select { |x| x[:meta][:method] != :destroy }

    parents.each do |x|
      if x[:object] && object
        if x[:meta][:method] == :disassociate
          if x[:sideload].type == :belongs_to
            x[:sideload].disassociate(object, x[:object])
          else
            x[:sideload].disassociate(x[:object], object)
          end
        elsif x[:sideload].type == :belongs_to
          x[:sideload].associate(object, x[:object])
        elsif [:has_many, :many_to_many].include?(x[:sideload].type)
          x[:sideload].associate_all(object, Array(x[:object]))
        else
          x[:sideload].associate(x[:object], object)
        end
      end
    end
  end

  def associate_children(object, children)
    children.each do |x|
      if x[:object] && object
        if x[:meta][:method] == :disassociate
          x[:sideload].disassociate(object, x[:object])
        elsif x[:meta][:method] == :destroy
          if x[:sideload].type == :many_to_many
            x[:sideload].disassociate(object, x[:object])
          end
          # otherwise, no need to disassociate destroyed objects
        elsif [:has_many, :many_to_many].include?(x[:sideload].type)
          x[:sideload].associate_all(object, Array(x[:object]))
        else
          x[:sideload].associate(object, x[:object])
        end
      end
    end
  end

  def persist_object(method, attributes)
    case method
      when :destroy
        call_resource_method(:destroy, attributes[:id], @caller_model)
      when :update, nil, :disassociate
        call_resource_method(:update, attributes, @caller_model)
      else
        call_resource_method(:create, attributes, @caller_model)
    end
  end

  def process_has_many(relationships, caller_model)
    [].tap do |processed|
      iterate(except: [:polymorphic_belongs_to, :belongs_to]) do |x|
        yield x

        x[:object] = x[:resource]
          .persist_with_relationships(x[:meta], x[:attributes], x[:relationships], caller_model, x[:foreign_key])

        processed << x
      end
    end
  end

  def process_belongs_to(relationships)
    [].tap do |processed|
      iterate(only: [:polymorphic_belongs_to, :belongs_to]) do |x|
        begin
          id = x.dig(:attributes, :id)
          x[:object] = x[:resource]
            .persist_with_relationships(x[:meta], x[:attributes], x[:relationships])
          processed << x
        rescue Graphiti::Errors::RecordNotFound
          path = "relationships/#{x.dig(:meta, :jsonapi_type)}"
          raise Graphiti::Errors::RecordNotFound.new(x[:sideload].name, id, path)
        end
      end
    end
  end

  def post_process(caller_model, processed)
    groups = processed.group_by { |x| x[:meta][:method] }
    groups.each_pair do |method, group|
      group.group_by { |g| g[:sideload] }.each_pair do |sideload, members|
        objects = members.map { |x| x[:object] }
        hook = -> { sideload.fire_hooks!(caller_model, objects, method) }
        add_hook(hook, :before_commit)
      end
    end
  end

  def assign_temp_id(object, temp_id)
    object.instance_variable_set(:@_jsonapi_temp_id, temp_id)
  end

  def iterate(only: [], except: [])
    opts = {
      resource: @resource,
      relationships: @relationships
    }.merge(only: only, except: except)

    Graphiti::Util::RelationshipPayload.iterate(opts) do |x|
      yield x
    end
  end

  def metadata
    {
      method: @meta[:method],
      temp_id: @meta[:temp_id],
      caller_model: @caller_model,
      attributes: @attributes,
      relationships: @relationships
    }
  end

  def call_resource_method(method_name, attributes, caller_model)
    method = @resource.method(method_name)

    if method.arity == 1
      method.call(attributes)
    else
      method.call(attributes, metadata)
    end
  end
end
