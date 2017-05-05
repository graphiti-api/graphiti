# Save the given Resource#model, and all of its nested relationships.
# @api private
class JsonapiCompliable::Util::Persistence
  # @param [Resource] resource the resource instance
  # @param [Hash] meta see (Deserializer#meta)
  # @param [Hash] attributes see (Deserializer#attributes)
  # @param [Hash] relationships see (Deserializer#relationships)
  def initialize(resource, meta, attributes, relationships)
    @resource      = resource
    @meta          = meta
    @attributes    = attributes
    @relationships = relationships
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
  # * return current object
  #
  # @return the persisted model instance
  def run
    parents = process_belongs_to(@relationships)
    update_foreign_key_for_parents(parents)

    persisted = persist_object(@meta[:method], @attributes)
    assign_temp_id(persisted, @meta[:temp_id])
    associate_parents(persisted, parents)

    children = process_has_many(@relationships) do |x|
      update_foreign_key(persisted, x[:attributes], x)
    end

    associate_children(persisted, children)
    persisted unless @meta[:method] == :destroy
  end

  private

  # The child's attributes should be modified to nil-out the
  # foreign_key when the parent is being destroyed or disassociated
  def update_foreign_key(parent_object, attrs, x)
    if [:destroy, :disassociate].include?(x[:meta][:method])
      attrs[x[:foreign_key]] = nil
    else
      attrs[x[:foreign_key]] = parent_object.send(x[:primary_key])
    end
  end

  def update_foreign_key_for_parents(parents)
    parents.each do |x|
      update_foreign_key(x[:object], @attributes, x)
    end
  end

  def associate_parents(object, parents)
    parents.each do |x|
      x[:sideload].associate(x[:object], object) if x[:object] && object
    end
  end

  def associate_children(object, children)
    children.each do |x|
      x[:sideload].associate(object, x[:object]) if x[:object] && object
    end
  end

  def persist_object(method, attributes)
    case method
      when :destroy
        @resource.destroy(attributes[:id])
      when :disassociate, nil
        @resource.update(attributes)
      else
        @resource.send(method, attributes)
    end
  end

  def process_has_many(relationships)
    [].tap do |processed|
      iterate(except: [:belongs_to]) do |x|
        yield x
        x[:object] = x[:sideload].resource
          .persist_with_relationships(x[:meta], x[:attributes], x[:relationships])
        processed << x
      end
    end
  end

  def process_belongs_to(relationships)
    [].tap do |processed|
      iterate(only: [:belongs_to]) do |x|
        x[:object] = x[:sideload].resource
          .persist_with_relationships(x[:meta], x[:attributes], x[:relationships])
        processed << x
      end
    end
  end

  def assign_temp_id(object, temp_id)
    object.instance_variable_set(:@_jsonapi_temp_id, temp_id)
  end

  def iterate(only: [], except: [])
    opts = {
      resource: @resource,
      relationships: @relationships,
    }.merge(only: only, except: except)

    JsonapiCompliable::Util::RelationshipPayload.iterate(opts) do |x|
      yield x
    end
  end
end
