---
layout: page
---

<div markdown="1" class="toc col-md-3">
Testing
==========

* 1 [Overview](#overview)
* 2 [API Tests](#resource-tests)
* 3 [Resource Tests](#resource-tests)
* 3 [Dealing With Dependencies]

</div>

<div markdown="1" class="col-md-8">
## 1 Overview

Test first.

Wait, hear me out!

[Even if you're not a fan of TDD](http://david.heinemeierhansson.com/2014/tdd-is-dead-long-live-testing.html), Graphiti *integration* tests just make development easier. In fact, much Graphiti development happens without even opening a browser...and as a side effect, you get a reliable test suite.

Let's say, we want Employees to be sortable by `title`, which comes from
the `positions` table. Start with a spec:

{% highlight ruby %}
describe 'sorting' do
  describe 'by title' do
    # GIVEN some data
    let!(:employee1) { create(:employee) }
    let!(:employee2) { create(:employee) }
    let!(:position1) { create(:position, title: 'z', employee: employee1) }
    let!(:position2) { create(:position, title: 'a', employee: employee2) }

    # WHEN a condition
    context 'when asc' do
      before do
        params[:sort] = 'title'
      end

      # THEN we get the correct result
      it 'works' do
        render
        expect(d.map(&:id)).to eq([employee2.id, employee1.id])
      end
    end

    context 'when desc' do
      before do
        params[:sort] = '-title'
      end

      it 'works' do
        render
        expect(d.map(&:id)).to eq([employee1.id, employee2.id])
      end
    end
  end
end
{% endhighlight %}
