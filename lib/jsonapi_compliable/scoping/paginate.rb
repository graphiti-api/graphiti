module JsonapiCompliable
  # Apply pagination logic to the scope
  #
  # If the user requests a page size greater than +MAX_PAGE_SIZE+,
  # a +JsonapiCompliable::Errors::UnsupportedPageSize+ error will be raised.
  #
  # Notably, this will not fire when the `default: false` option is passed.
  # This is the case for sideloads - if the user requests "give me the post
  # and its comments", we shouldn't implicitly limit those comments to 20.
  # *BUT* if the user requests, "give me the post and 3 of its comments", we
  # *should* honor that pagination.
  #
  # This can be confusing because there are also 'default' and 'customized'
  # pagination procs. The default comes 'for free'. Customized pagination
  # looks like
  #
  #   class PostResource < ApplicationResource
  #     paginate do |scope, current_page, per_page|
  #       # ... the custom logic ...
  #     end
  #   end
  #
  # We should use the default unless the user has customized.
  # @see Resource.paginate
  class Scoping::Paginate < Scoping::Base
    MAX_PAGE_SIZE = 1_000

    # Apply the pagination logic. Raise error if over the max page size.
    # @return the scope object we are chaining/modifying
    def apply
      if size > MAX_PAGE_SIZE
        raise JsonapiCompliable::Errors::UnsupportedPageSize
          .new(size, MAX_PAGE_SIZE)
      else
        super
      end
    end

    # We want to apply this logic unless we've explicitly received the
    # +default: false+ option. In that case, only apply if pagination
    # was explicitly specified in the request.
    #
    # @return [Boolean] should we apply this logic?
    def apply?
      if @opts[:default] == false
        not [page_param[:size], page_param[:number]].all?(&:nil?)
      else
        true
      end
    end

    # @return [Proc, Nil] the custom pagination proc
    def custom_scope
      resource.pagination
    end

    # Apply default pagination proc via the Resource adapter
    def apply_standard_scope
      resource.adapter.paginate(@scope, number, size)
    end

    # Apply the custom pagination proc
    def apply_custom_scope
      custom_scope.call(@scope, number, size, resource.context)
    end

    private

    def page_param
      @page_param ||= (query_hash[:page] || {})
    end

    def number
      (page_param[:number] || resource.default_page_number).to_i
    end

    def size
      (page_param[:size] || resource.default_page_size).to_i
    end
  end
end
