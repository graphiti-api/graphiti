module Graphiti
  class Scoping::Paginate < Scoping::Base
    DEFAULT_PAGE_SIZE = 20
    VALID_QUERY_PARAMS = [:number, :size, :before, :after]

    def apply
      if size > resource.max_page_size
        raise Graphiti::Errors::UnsupportedPageSize
          .new(size, resource.max_page_size)
      elsif requested? && @opts[:sideload_parent_length].to_i > 1
        raise Graphiti::Errors::UnsupportedPagination
      elsif cursor? && !resource.cursor_paginatable?
        raise Graphiti::Errors::UnsupportedCursorPagination.new(resource)
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
      if @opts[:default_paginate] == false
        requested?
      else
        true
      end
    end

    # @return [Proc, Nil] the custom pagination proc
    def custom_scope
      cursor? ? resource.cursor_pagination : resource.pagination
    end

    # Apply default pagination proc via the Resource adapter
    def apply_standard_scope
      if cursor?
        # NB put in abstract adapter?

        # if after_cursor
        #   clause = nil
        #   after_cursor.each_with_index do |part, index|
        #     method = part[:direction] == "asc" ? :filter_gt : :filter_lt

        #     if index.zero?
        #       clause = resource.adapter.public_send(method, @scope, part[:attribute], [part[:value]])
        #     else
        #       sub_scope = resource.adapter
        #         .filter_eq(@scope, after_cursor[index-1][:attribute], [after_cursor[index-1][:value]])
        #       sub_scope = resource.adapter.filter_gt(sub_scope, part[:attribute], [part[:value]])

        #       # NB - AR specific (use offset?)
        #       # maybe in PR ask feedback
        #       clause = clause.or(sub_scope)
        #     end
        #   end
        #   @scope = clause
        # end
        # resource.adapter.paginate(@scope, 1, size)
        resource.adapter.cursor_paginate(@scope, after_cursor, size)
      else
        resource.adapter.paginate(@scope, number, size)
      end
    end

    # Apply the custom pagination proc
    def apply_custom_scope
      if cursor?
        resource.instance_exec \
          @scope,
          after_cursor,
          size,
          resource.context,
          &custom_scope
      else
        resource.instance_exec \
          @scope,
          number,
          size,
          resource.context,
          &custom_scope
      end
    end

    private

    def requested?
      ![page_param[:size], page_param[:number]].all?(&:nil?)
    end

    def page_param
      @page_param ||= (query_hash[:page] || {})
    end

    def number
      (page_param[:number] || 1).to_i
    end

    def size
      (page_param[:size] || resource.default_page_size || DEFAULT_PAGE_SIZE).to_i
    end

    def after_cursor
      if (after = page_param[:after])
        Util::Cursor.decode(resource, after)
      end
    end

    def cursor?
      !!page_param[:after]
    end
  end
end
