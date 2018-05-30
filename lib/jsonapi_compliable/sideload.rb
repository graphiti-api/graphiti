module JsonapiCompliable
  # @attr_reader [Symbol] name The name of the sideload
  # @attr_reader [Class] resource_class The corresponding Resource class
  # @attr_reader [Boolean] polymorphic Is this a polymorphic sideload?
  # @attr_reader [Hash] polymorphic_groups The subgroups, when polymorphic
  # @attr_reader [Hash] sideloads The associated sibling sideloads
  # @attr_reader [Proc] scope_proc The configured 'scope' block
  # @attr_reader [Proc] assign_proc The configured 'assign' block
  # @attr_reader [Symbol] grouping_field The configured 'group_by' symbol
  # @attr_reader [Symbol] foreign_key The attribute used to match objects - need not be a true database foreign key.
  # @attr_reader [Symbol] primary_key The attribute used to match objects - need not be a true database primary key.
  # @attr_reader [Symbol] type One of :has_many, :belongs_to, etc
  class Sideload
    attr_reader :name,
      :resource_class,
      :polymorphic,
      :polymorphic_groups,
      :parent,
      :sideloads,
      :scope_proc,
      :assign_proc,
      :grouping_field,
      :foreign_key,
      :primary_key,
      :type

    # NB - the adapter's +#sideloading_module+ is mixed in on instantiation
    #
    # An anonymous Resource will be assigned when none provided.
    #
    # @see Adapters::Abstract#sideloading_module
    def initialize(name, type: nil, resource: nil, polymorphic: false, primary_key: :id, foreign_key: nil, parent: nil)
      @name               = name
      @resource_class     = (resource || Class.new(Resource))
      @sideloads          = {}
      @polymorphic        = !!polymorphic
      @polymorphic_groups = {} if polymorphic?
      @parent             = parent
      @primary_key        = primary_key
      @foreign_key        = foreign_key
      @type               = type

      extend @resource_class.config[:adapter].sideloading_module
    end

    # @see #resource_class
    # @return [Resource] an instance of +#resource_class+
    def resource
      @resource ||= resource_class.new
    end

    # Is this sideload polymorphic?
    #
    # Polymorphic sideloads group the parent objects in some fashion,
    # so different 'types' can be resolved differently. Let's say an
    # +Office+ has a polymorphic +Organization+, which can be either a
    # +Business+ or +Government+:
    #
    #   allow_sideload :organization, :polymorphic: true do
    #     group_by :organization_type
    #
    #     allow_sideload 'Business', resource: BusinessResource do
    #       # ... code ...
    #     end
    #
    #     allow_sideload 'Governemnt', resource: GovernmentResource do
    #       # ... code ...
    #     end
    #   end
    #
    # You probably want to extract this code into an Adapter. For instance,
    # with ActiveRecord:
    #
    #   polymorphic_belongs_to :organization,
    #     group_by: :organization_type,
    #     groups: {
    #       'Business' => {
    #         scope: -> { Business.all },
    #         resource: BusinessResource,
    #         foreign_key: :organization_id
    #       },
    #       'Government' => {
    #         scope: -> { Government.all },
    #         resource: GovernmentResource,
    #         foreign_key: :organization_id
    #       }
    #     }
    #
    # @see Adapters::ActiveRecordSideloading#polymorphic_belongs_to
    # @return [Boolean] is this sideload polymorphic?
    def polymorphic?
      @polymorphic == true
    end

    # Build a scope that will be used to fetch the related records
    # This scope will be further chained with filtering/sorting/etc
    #
    # You probably want to wrap this logic in an Adapter, instead of
    # specifying in your resource directly.
    #
    # @example Default ActiveRecord
    #   class PostResource < ApplicationResource
    #     # ... code ...
    #     allow_sideload :comments, resource: CommentResource do
    #       scope do |posts|
    #         Comment.where(post_id: posts.map(&:id))
    #       end
    #       # ... code ...
    #     end
    #   end
    #
    # @example Custom Scope
    #   # In this example, our base scope is a Hash
    #   scope do |posts|
    #     { post_ids: posts.map(&:id) }
    #   end
    #
    # @example ActiveRecord via Adapter
    #   class PostResource < ApplicationResource
    #     # ... code ...
    #     has_many :comments,
    #       scope: -> { Comment.all },
    #       resource: CommentResource,
    #       foreign_key: :post_id
    #   end
    #
    # @see Adapters::Abstract
    # @see Adapters::ActiveRecordSideloading#has_many
    # @see #allow_sideload
    # @yieldparam parents - The resolved parent records
    def scope(&blk)
      @scope_proc = blk
    end

    # The proc used to assign the resolved parents and children.
    #
    # You probably want to wrap this logic in an Adapter, instead of
    # specifying in your resource directly.
    #
    # @example Default ActiveRecord
    #   class PostResource < ApplicationResource
    #     # ... code ...
    #     allow_sideload :comments, resource: CommentResource do
    #       # ... code ...
    #       assign do |posts, comments|
    #         posts.each do |post|
    #           relevant_comments = comments.select { |c| c.post_id == post.id }
    #           post.comments = relevant_comments
    #         end
    #       end
    #     end
    #   end
    #
    # @example ActiveRecord via Adapter
    #   class PostResource < ApplicationResource
    #     # ... code ...
    #     has_many :comments,
    #       scope: -> { Comment.all },
    #       resource: CommentResource,
    #       foreign_key: :post_id
    #   end
    #
    # @see Adapters::Abstract
    # @see Adapters::ActiveRecordSideloading#has_many
    # @see #allow_sideload
    # @yieldparam parents - The resolved parent records
    # @yieldparam children - The resolved child records
    def assign(&blk)
      @assign_proc = blk
    end

    # Configure how to associate parent and child records.
    # Delegates to #resource
    #
    # @see #name
    # @see #type
    # @api private
    def associate(parent, child)
      association_name = @parent ? @parent.name : name
      resource.associate(parent, child, association_name, type)
    end

    # Configure how to disassociate parent and child records.
    # Delegates to #resource
    #
    # @see #name
    # @see #type
    # @api private
    def disassociate(parent, child)
      association_name = @parent ? @parent.name : name
      resource.disassociate(parent, child, association_name, type)
    end

    HOOK_ACTIONS = [:save, :create, :update, :destroy, :disassociate]

    # Configure post-processing hooks
    #
    # In particular, helpful for bulk operations. "after_save" will fire
    # for any persistence method - +:create+, +:update+, +:destroy+, +:disassociate+.
    # Use "only" and "except" keyword arguments to fire only for a
    # specific persistence method.
    #
    # @example Bulk Notify Users on Invite
    #   class ProjectResource < ApplicationResource
    #     # ... code ...
    #     allow_sideload :users, resource: UserResource do
    #       # scope {}
    #       # assign {}
    #       after_save only: [:create] do |project, users|
    #         UserMailer.invite(project, users).deliver_later
    #       end
    #     end
    #   end
    #
    # @see #hooks
    # @see Util::Persistence
    def after_save(only: [], except: [], &blk)
      actions = HOOK_ACTIONS - except
      actions = only & actions
      actions = [:save] if only.empty? && except.empty?
      actions.each do |a|
        hooks[:"after_#{a}"] << blk
      end
    end

    # Get the hooks the user has configured
    # @see #after_save
    # @return hash of hooks, ie +{ after_create: #<Proc>}+
    def hooks
      @hooks ||= {}.tap do |h|
        HOOK_ACTIONS.each do |a|
          h[:"after_#{a}"] = []
          h[:"before_#{a}"] = []
        end
      end
    end

    # Define an attribute that groups the parent records. For instance, with
    # an ActiveRecord polymorphic belongs_to there will be a +parent_id+
    # and +parent_type+. We would want to group on +parent_type+:
    #
    #  allow_sideload :organization, polymorphic: true do
    #    # group parent_type, parent here is 'organization'
    #    group_by :organization_type
    #  end
    #
    # @see #polymorphic?
    def group_by(grouping_field)
      @grouping_field = grouping_field
    end

    # Resolve the sideload.
    #
    # * Uses the 'scope' proc to build a 'base scope'
    # * Chains additional criteria onto that 'base scope'
    # * Resolves that scope (see Scope#resolve)
    # * Assigns the resulting child objects to their corresponding parents
    #
    # @see Scope#resolve
    # @param [Object] parents The resolved parent models
    # @param [Query] query The Query instance
    # @param [Symbol] namespace The current namespace (see Resource#with_context)
    # @see Query
    # @see Resource#with_context
    # @return [void]
    # @api private
    def resolve(parents, query, namespace)
      if polymorphic?
        resolve_polymorphic(parents, query)
      else
        resolve_basic(parents, query, namespace)
      end
    end

    # Configure a relationship between Resource objects
    #
    # You probably want to extract this logic into an adapter
    # rather than using directly
    #
    # @example Default ActiveRecord
    #   # What happens 'under the hood'
    #   class CommentResource < ApplicationResource
    #     # ... code ...
    #     allow_sideload :post, resource: PostResource do
    #       scope do |comments|
    #         Post.where(id: comments.map(&:post_id))
    #       end
    #
    #       assign do |comments, posts|
    #         comments.each do |comment|
    #           relevant_post = posts.find { |p| p.id == comment.post_id }
    #           comment.post = relevant_post
    #         end
    #       end
    #     end
    #   end
    #
    #   # Rather than writing that code directly, go through the adapter:
    #   class CommentResource < ApplicationResource
    #     # ... code ...
    #     use_adapter JsonapiCompliable::Adapters::ActiveRecord
    #
    #     belongs_to :post,
    #       scope: -> { Post.all },
    #       resource: PostResource,
    #       foreign_key: :post_id
    #   end
    #
    # @see Adapters::ActiveRecordSideloading#belongs_to
    # @see #assign
    # @see #scope
    # @return void
    def allow_sideload(name, opts = {}, &blk)
      sideload = Sideload.new(name, opts)
      sideload.instance_eval(&blk) if blk

      if polymorphic?
        @polymorphic_groups[name] = sideload
      else
        @sideloads[name] = sideload
      end
    end

    # Fetch a Sideload object by its name
    # @param [Symbol] name The name of the corresponding sideload
    # @see +allow_sideload
    # @return the corresponding Sideload object
    def sideload(name)
      @sideloads[name]
    end

    # @api private
    def all_sideloads
      {}.tap do |all|
        if polymorphic?
          polymorphic_groups.each_pair do |type, sl|
            all.merge!(sl.resource.sideloading.all_sideloads)
          end
        else
          all.merge!(@sideloads.merge(resource.sideloading.sideloads))
        end
      end
    end

    def association_names(memo = [])
      all_sideloads.each_pair do |name, sl|
        unless memo.include?(sl.name)
          memo << sl.name
          memo |= sl.association_names(memo)
        end
      end

      memo
    end

    # @api private
    def polymorphic_child_for_type(type)
      polymorphic_groups.values.find do |v|
        v.resource_class.config[:type] == type.to_sym
      end
    end

    def fire_hooks!(parent, objects, method)
      return unless self.hooks

      hooks = self.hooks[:"after_#{method}"] + self.hooks[:after_save]
      hooks.compact.each do |hook|
        resource.instance_exec(parent, objects, &hook)
      end
    end

    private

    def polymorphic_grouper(grouping_field)
      lambda do |record|
        if record.is_a?(Hash)
          if record.keys[0].is_a?(Symbol)
            record[grouping_field]
          else
            record[grouping_field.to_s]
          end
        else
          record.send(grouping_field)
        end
      end
    end

    def resolve_polymorphic(parents, query)
      grouper = polymorphic_grouper(@grouping_field)

      parents.group_by(&grouper).each_pair do |group_type, group_members|
        sideload_for_group = @polymorphic_groups[group_type]
        if sideload_for_group
          sideload_for_group.resolve(group_members, query, name)
        end
      end
    end

    def resolve_basic(parents, query, namespace)
      sideload_scope   = scope_proc.call(parents)
      sideload_scope   = Scope.new(sideload_scope, resource_class.new, query, default_paginate: false, namespace: namespace)
      sideload_scope.resolve do |sideload_results|
        assign_proc.call(parents, sideload_results)
      end
    end
  end
end
