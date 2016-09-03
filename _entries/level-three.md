---
sectionid: l-3
sectionclass: h4
parent-id: section-types
number: 3113
title: Level three
---
A Subsection of a level 3 will look like this

{% highlight yaml %}
---
sectionid: UNIQUE-ID
sectionclass: h3
title: TITLE
parent-id: UNIQUE-ID-Of-PARENT
---
{% endhighlight %}

So the `parent-id` is where you will reference the anchor of the h2 section that's your subsections parent.

Level 3 sections can have children, the variable to use is the same. To have children add

{% highlight yaml %}
is-parent: yes
{% endhighlight %}