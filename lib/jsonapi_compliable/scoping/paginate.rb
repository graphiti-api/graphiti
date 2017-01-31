module JsonapiCompliable
  class Scoping::Paginate < Scoping::Base
    MAX_PAGE_SIZE = 1_000

    def apply
      if size > MAX_PAGE_SIZE
        raise JsonapiCompliable::Errors::UnsupportedPageSize
          .new(size, MAX_PAGE_SIZE)
      else
        super
      end
    end

    def custom_scope
      dsl.pagination
    end

    def apply_standard_scope
      @scope.page(number).per(size)
    end

    def apply_custom_scope
      custom_scope.call(@scope, number, size)
    end

    private

    def page_param
      @page_param ||= (query_hash[:page] || {})
    end

    def number
      (page_param[:number] || dsl.default_page_number).to_i
    end

    def size
      (page_param[:size] || dsl.default_page_size).to_i
    end
  end
end
