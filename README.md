### Adding JSONAPICompliable
```
class ApplicationController < ActionController::Base
  include JSONAPICompliable
end
```
### Define whitelist includes/filters per controller.
```
class BooksController < ApplicationController
  jsonapi do
    includes whitelist: { index: [{ books: :genre }, :state] }
  end
end
```
Below url requesting state/foo as includes. 
But foo include is ignored as it is not whitelist. 
```
/books?include=state%2Cfoo
```
