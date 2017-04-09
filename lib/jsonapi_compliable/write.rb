class JsonapiCompliable::Write
  attr_reader :resource

  def initialize(opts = {})
    @resource = opts[:resource]
  end

  def persist

  end
end

resource.persist(obj, persistence_query, opts)

p = Persistence.new(obj, resource: resource, params: params, opts: opts)
p.persist


allow_nested_write :books, resource: BookResource do
  # rdefault to using BookResource in these
  # hooks, but user can override to save
  # via author
  #
  # assign temp id AFTER
  # must handle NESTING genre
  create do |author, book_params|
    book_params[:author_id] = author.id
    BookResource.create(book_params)
    #book = Book.new(book_params)
    #book.author_id = author.id
    # instance variable set new id?
    # # should be outside this method
    #book.save!
    #book
  end

  # HOW TO REUSE THIS ON /books
  # should it be? i guess update, but not create
  update do |author, book_params|
    BookResource.update(book_params)
    #book = Book.find(book_params[:id])
    #book.update_attributes(book_params)
    #book
  end

  # Might be fair to say you can remove rel
  # but not destroy it
  # if needed, add destroy hook later
  delete do |author, book_params|
    book_params[:author_id] = nil
    BookResource.update(book_params)
  end

  destroy do |author, book_params|
    BookResource.destroy(book_params)
  end
end

    #def jsonapi_scope(scope, opts = {})
      #resource.build_scope(scope, query, opts)
    #end

# controller
#
# book = Book.new(params)
#
# if jsonapi_persist(book)
#   render_jsonapi(book)
# else
#   render_errors_for(book)
# end



class Writer
      def initialize(parent)
      end

      def doit
        relationships.each do |name, data|
          if has_many?
            created = Child.new(data, fk: fk)
            created.TEMP_ID = data['temp_id']
            created = created.save
            mapping {data['temp_id'] => created.id}
            parent.name 4<< created
            parent.
          else

          end
        end
      end
    end
