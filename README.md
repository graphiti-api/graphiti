[official documentation](https://bbgithub.dev.bloomberg.com/pages/InfrastructureExperience/jsonapi_compliable)

### Getting Started
Please read below documentation related to [jsonapi](http://jsonapi.org/format/#document-resource-objects)


### Adding JSONAPICompliable
```
class ApplicationController < ActionController::Base
  include JSONAPICompliable
end

```
### Define whitelist includes
```
class AuthorsController < ApplicationController
  jsonapi do
    includes whitelist: { index: [{ books: :genre }, :state] }

    allow_filter :last_name

    allow_filter :first_name, aliases: [:title], if: :can_filter_first_name?

    allow_filter :first_name_prefix do |scope, filter|
      scope.where('first_name like ?', "#{filter}%")
    end
  end
end
```
Below url requesting state/foo as includes. 
But foo include is ignored as it is not whitelist. 
>authors?include=state,foo

### Defining filter field 

```
class AuthorsController < ApplicationController
  jsonapi do
    allow_filter :last_name
  end
end
```
will allow us make request as below
>/authors?filter[first_name]=john

### Defining filter field alias 

```
class AuthorsController < ApplicationController
  jsonapi do
    allow_filter :last_name, aliases: [:name]
  end
end
```
will allow us make request as below
>/authors?filter[name]=john

### Adding guard to filter

```
class AuthorsController < ApplicationController
  jsonapi do
    allow_filter :last_name if: :can_filter?
  end

  def can_filter?
    true
  end
end
```

### Defining default filter 

```
class AuthorsController < ApplicationController
  jsonapi do
    default_filter :first_name do |scope|
      scope.where(first_name: 'Willaim')
    end
  end
end
```
if no filter provided below request will filter authors first_name='Willaim'

>/authors

### Deserialize requests params which are coming jsonapi format

```
  class AuthorsController < ApplicationController
    before_action :deserialize_jsonapi!, only: [:update, :create]
  end
```
incoming parameters
```
  {
    data: {
      type: 'authors',
      attributes: {
        first_name: 'Stephen',
        last_name: 'King'
      },
      relationships: {
        books: {
          data: [
            { type: 'books', attributes: { title: 'The Shining' } }
          ]
        }
      }
    }
  }
```
will be deserialized to
```
  {
    authors: {
      first_name: 'Stephen',
      last_name: 'King'
      books_attributes: [{
        title: 'The Shingin'
      }]
    }
  }
```
