---
layout: page
---

<div markdown="1" class="toc col-md-3">
Testing
==========

* 1 [Overview](#overview)
  * [API vs Resource](#api-vs-resource)
  * Factories
  * RSpec
* 2 [API Tests](#resource-tests)
  * Reads
    * Index
    * Show
  * Writes
    * Create
    * Update
    * Destroy
* 3 [Resource Tests](#resource-tests)
  * Reads
    * Serialization
    * Sorting
    * Filtering
    * Sideloading
  * Writes
    * Create
    * Update
    * Destroy
* 4 Testing Spectrum
* 3 [Dealing With Dependencies]

</div>

<div markdown="1" class="col-md-8">
## 1 Overview

Test first.

Wait, hear me out!

[Even if you're not a fan of TDD](http://david.heinemeierhansson.com/2014/tdd-is-dead-long-live-testing.html), Graphiti *integration* tests are simply the easiest, most pleasant way to develop. In fact, most Graphiti development can happen without even opening a browser...and as a side effect, you get a reliable test suite.

Let's say we want to filter Employees by `title`, which comes from
the `positions` table. Start with a spec:

{% highlight ruby %}
RSpec.describe EmployeeResource, type: :resource do
  describe 'filtering' do
    context 'by title' do
      # GIVEN some seed data
      let!(:employee1) { create(:employee) }
      let!(:employee2) { create(:employee) }
      let!(:position1) do
        create :position,
          title: 'foo',
          employee: employee1
      end
      let!(:position2) do
        create :position,
          title: 'bar',
          employee: employee2
      end

      # WHEN a parameter is set
      before do
        params[:filter] = { title: 'bar' }
      end

      # THEN the query results will be correct
      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end
  end
end
{% endhighlight %}

By developing test-first:

* We don't need to struggle with seeding local development data - we can
seed randomized data on-the-fly with [factories](https://github.com/thoughtbot/factory_bot).
* There's no need to spin up a server and refresh browser pages,
mentally parsing the response payload.
* We get a high-confidence test "for free".
* Because our integration test is separate from implementation, we don't
need to worry about [test-induced design damage](http://david.heinemeierhansson.com/2014/test-induced-design-damage.html).

### 1.1 API vs Resource

There are two types of Graphiti tests: **API tests** and **Resource
tests**.

This is because the same Resource logic can be re-used at multiple
endpoints. PostResource can be referenced at `/posts` and `/top_posts`
and `/admin/posts`, but we shouldn't have to test the same filtering and
sorting logic over and over. Querying, Persistence and Serialization are
all Resource responsibilities, tested in Resource tests.
