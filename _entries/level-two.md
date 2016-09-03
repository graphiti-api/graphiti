---
sectionid: l-2
sectionclass: h4
parent-id: section-types
number: 3112
title: Level two
---
A Subsection of a level-2 will look like this

{% highlight yaml %}
---
sectionid: UNIQUE-ID
sectionclass: h2
title: TITLE
parent-id: UNIQUE-ID-Of-PARENT
---
{% endhighlight %}

So the `parent-id` is where you will reference the anchor of the h1 section that's your subsections parent.

Level 2 sections can have children, the variable to use is the same. To have children add

{% highlight yaml %}
is-parent: yes
{% endhighlight %}