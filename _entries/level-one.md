---
sectionid: l-1
sectionclass: h4
parent-id: section-types
number: 3111
title: Level one
---
If you want to create one of the main sections, you will need to include the following front matter within your entry:

{% highlight yaml %}
---
sectionid: UNIQUE-ID
sectionclass: h1
title: TITLE
---
{% endhighlight %}

If you want your section to have subsections, add

{% highlight yaml %}
is-parent: yes
{% endhighlight %}

The ID is important, because it will be used as the anchor for the scrollToLinks and it is also used within the subsections. So each child needs to tell jekyll what its parent is, before it can be placed correctly.