---
sectionid: l-4
sectionclass: h4
parent-id: section-types
number: 3114
title: Level four
---
A Subsection of a level 4 will look like this

{% highlight yaml %}
---
sectionid: UNIQUE-ID
sectionclass: h4
title: TITLE
parent-id: UNIQUE-ID-Of-PARENT
---
{% endhighlight %}

So the `parent-id` is where you will reference the anchor of the h3 section that's your subsections parent.

Level 4 sections can't have any more children within sections, but you if you add a h5 title, it will still have the numbering.

##### Proof here

Told ya! (it will not work on h6 though )
