module JsonapiCompliable
  module Adapters
    # Adapters DRY up common resource logic.
    #
    # For instance, there's no reason to write ActiveRecord logic like this in
    # every Resource:
    #
    #   allow_filter :title do |scope, value|
    #     scope.where(title: value)
    #   end
    #
    #   sort do |scope, att, dir|
    #     scope.order(att => dir)
    #   end
    #
    #   paginate do |scope, current_page, per_page|
    #     scope.page(current_page).per(per_page)
    #   end
    #
    # This logic can be re-used through an *Adapter*:
    #
    #   use_adapter JsonapiCompliable::Adapters::ActiveRecord
    #   allow_filter :title
    #
    # Adapters are pretty simple to write. The corresponding code for the above
    # ActiveRecord adapter, which should look pretty familiar:
    #
    #   class JsonapiCompliable::Adapters::ActiveRecord
    #     def filter(scope, attribute, value)
    #       scope.where(attribute => value)
    #     end
    #
    #     def order(scope, attribute, direction)
    #       scope.order(attribute => direction)
    #     end
    #
    #     def paginate(scope, current_page, per_page)
    #       scope.page(current_page).per(per_page)
    #     end
    #   end
    #
    # An adapter can have a corresponding +sideloading_module+. This module
    # gets mixed in to a Sideload. In other words, *Resource* is to
    # *Adapter* as *Sideload* is to *Adapter#sideloading_module*. Use this
    # module to define DSL methods that wrap #allow_sideload:
    #
    #   class MyAdapter < JsonapiCompliable::Adapters::Abstract
    #     # ... code ...
    #     def sideloading_module
    #       MySideloadingAdapter
    #     end
    #   end
    #
    #   module MySideloadingAdapter
    #     def belongs_to(association_name)
    #       allow_sideload association_name do
    #         # ... code ...
    #       end
    #     end
    #   end
    #
    #   # And now in your Resource:
    #   class MyResource < ApplicationResource
    #     # ... code ...
    #     use_adapter MyAdapter
    #
    #     belongs_to :my_association
    #   end
    #
    # If you need the adapter to do *nothing*, because perhaps the API you
    # are hitting does not support sorting,
    # use +JsonapiCompliable::Adapters::Null+.
    #
    # @see Resource.use_adapter
    # @see Adapters::ActiveRecord
    # @see Adapters::ActiveRecordSideloading
    # @see Adapters::Null
    class Abstract
      # @param scope The scope object we are chaining
      # @param [Symbol] attribute The attribute name we are filtering
      # @param value The corresponding query parameter value
      # @return the scope
      #
      # @example ActiveRecord default
      #   def filter(scope, attribute, value)
      #     scope.where(attribute => value)
      #   end
      def filter(scope, attribute, value)
        raise 'you must override #filter in an adapter subclass'
      end

      def base_scope(model)
        raise 'you must override #base_scope in an adapter subclass'
      end

      # @param scope The scope object we are chaining
      # @param [Symbol] attribute The attribute name we are sorting
      # @param [Symbol] direction The direction we are sorting (asc/desc)
      # @return the scope
      #
      # @example ActiveRecord default
      #   def order(scope, attribute, direction)
      #     scope.order(attribute => direction)
      #   end
      def order(scope, attribute, direction)
        raise 'you must override #order in an adapter subclass'
      end

      # @param scope The scope object we are chaining
      # @param [Integer] current_page The current page number
      # @param [Integer] per_page The number of results per page
      # @return the scope
      #
      # @example ActiveRecord default
      #   # via kaminari gem
      #   def paginate(scope, current_page, per_page)
      #     scope.page(current_page).per(per_page)
      #   end
      def paginate(scope, current_page, per_page)
        raise 'you must override #paginate in an adapter subclass'
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the count of the scope
      # @example ActiveRecord default
      #   def count(scope, attr)
      #     column = attr == :total ? :all : attr
      #     scope.uniq.count(column)
      #   end
      def count(scope, attr)
        raise 'you must override #count in an adapter subclass'
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Float] the average of the scope
      # @example ActiveRecord default
      #   def average(scope, attr)
      #     scope.average(attr).to_f
      #   end
      def average(scope, attr)
        raise 'you must override #average in an adapter subclass'
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the sum of the scope
      # @example ActiveRecord default
      #   def sum(scope, attr)
      #     scope.sum(attr)
      #   end
      def sum(scope, attr)
        raise 'you must override #sum in an adapter subclass'
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the maximum value of the scope
      # @example ActiveRecord default
      #   def maximum(scope, attr)
      #     scope.maximum(attr)
      #   end
      def maximum(scope, attr)
        raise 'you must override #maximum in an adapter subclass'
      end

      # @param scope the scope object we are chaining
      # @param [Symbol] attr corresponding stat attribute name
      # @return [Numeric] the maximum value of the scope
      # @example ActiveRecord default
      #   def maximum(scope, attr)
      #     scope.maximum(attr)
      #   end
      def minimum(scope, attr)
        raise 'you must override #maximum in an adapter subclass'
      end

      # This method must +yield+ the code to run within the transaction.
      # This method should roll back the transaction if an error is raised.
      #
      # @param [Class] model_class The class we're operating on
      # @example ActiveRecord default
      #   def transaction(model_class)
      #     model_class.transaction do
      #       yield
      #     end
      #   end
      #
      # @see Resource.model
      def transaction(model_class)
        raise 'you must override #transaction in an adapter subclass, it must yield'
      end

      # Resolve the scope. This is where you'd actually fire SQL,
      # actually make an HTTP call, etc.
      #
      # @example ActiveRecordDefault
      #   def resolve(scope)
      #     scope.to_a
      #   end
      #
      # @example Suggested Customization
      #   # When making a service call, we suggest this abstraction
      #   # 'scope' here is a hash
      #   def resolve(scope)
      #     # The implementation of .where can be whatever you want
      #     SomeModelClass.where(scope)
      #   end
      #
      # @see Adapters::ActiveRecord#resolve
      # @param scope The scope object to resolve
      # @return an array of Model instances
      def resolve(scope)
        scope
      end

      # Probably want to override
      def associate(parent, child, association_name, association_type)
        if [:has_many, :many_to_many].include?(association_type)
          parent.send(:"#{association_name}") << child
        else
          parent.send(:"#{association_name}=", child)
        end
      end

      # Remove the association without destroying objects
      #
      # This is NOT needed in the standard use case. The standard use case would be:
      #
      #   def update(attrs)
      #     # attrs[:the_foreign_key] is nil, so updating the record disassociates
      #   end
      #
      # However, sometimes you need side-effect or elsewise non-standard behavior. Consider
      # using {{https://github.com/mbleigh/acts-as-taggable-on acts_as_taggable_on}} gem:
      #
      #   # Not actually needed, just an example
      #   def disassociate(parent, child, association_name, association_type)
      #     parent.tag_list.remove(child.name)
      #   end
      #
      # @example Basic accessor
      #   def disassociate(parent, child, association_name, association_type)
      #     if association_type == :has_many
      #       parent.send(association_name).delete(child)
      #     else
      #       child.send(:"#{association_name}=", nil)
      #     end
      #   end
      #
      # +association_name+ and +association_type+ come from your sideload
      # configuration:
      #
      #   allow_sideload :the_name, type: the_type do
      #     # ... code.
      #   end
      #
      # @param parent The parent object (via the JSONAPI 'relationships' graph)
      # @param child The child object (via the JSONAPI 'relationships' graph)
      # @param association_name The 'relationships' key we are processing
      # @param association_type The Sideload type (see Sideload#type). Usually :has_many/:belongs_to/etc
      def disassociate(parent, child, association_name, association_type)
        raise 'you must override #disassociate in an adapter subclass'
      end

      # You want to override this!
      # Map of association_type => sideload_class
      # e.g.
      # { has_many: Adapters::ActiveRecord::HasManySideload }
      def sideloading_classes
        {
          has_many: ::JsonapiCompliable::Sideload::HasMany,
          belongs_to: ::JsonapiCompliable::Sideload::BelongsTo,
          has_one: ::JsonapiCompliable::Sideload::HasOne,
          many_to_many: ::JsonapiCompliable::Sideload::ManyToMany,
          polymorphic_belongs_to: ::JsonapiCompliable::Sideload::PolymorphicBelongsTo
        }
      end

      # @param [Class] model_class The configured model class (see Resource.model)
      # @param [Hash] create_params Attributes + id
      # @return the model instance just created
      # @see Resource.model
      # @example ActiveRecord default
      #   def create(model_class, create_params)
      #     instance = model_class.new(create_params)
      #     instance.save
      #     instance
      #   end
      def create(model_class, create_params)
        raise 'you must override #create in an adapter subclass'
      end

      # @param [Class] model_class The configured model class (see Resource.model)
      # @param [Hash] update_params Attributes + id
      # @return the model instance just created
      # @see Resource.model
      # @example ActiveRecord default
      #   def update(model_class, update_params)
      #     instance = model_class.find(update_params.delete(:id))
      #     instance.update_attributes(update_params)
      #     instance
      #   end
      def update(model_class, update_params)
        raise 'you must override #update in an adapter subclass'
      end

      # @param [Class] model_class The configured model class (see Resource.model)
      # @param [Integer] id the id for this model
      # @return the model instance just destroyed
      # @see Resource.model
      # @example ActiveRecord default
      #   def destroy(model_class, id)
      #     instance = model_class.find(id)
      #     instance.destroy
      #     instance
      #   end
      def destroy(model_class, id)
        raise 'you must override #destroy in an adapter subclass'
      end
    end
  end
end
