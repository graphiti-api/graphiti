---
sectionclass: h2
sectionid: navigation
parent-id: content
number: 3200
title: Navigation
---
The navigation is dynamic, so you don't have to manually add every page.

In this section I'll just quickly plop in the code, in case you would like to have the fourth level displayed as well.

**default 3-level:**

{% highlight html %}
{% raw %}
<ul id="nav">
    {% assign level-1 = site.entries | where: "sectionclass", "h1" | sort: "number"%}
    {% for entry in level-1 %}
    <li {% if entry.is-parent or forloop.first %} class="{% if entry.is-parent %}parent{% endif %}{% if forloop.first %} current{% endif %}"{% endif %}>
        <a href="#{{ entry.sectionid }}">{{ entry.title }}</a>
        {% if entry.is-parent %}
            <ul>
                {% assign level-2 = site.entries | where: "parent-id", entry.sectionid | sort: "number" %}
                {% for child in level-2 %}
                    <li {% if child.is-parent %}class="parent"{% endif %}>
                        <a href="#{{ child.sectionid }}">{{ child.title }}</a>
                        {% if child.is-parent %}
                            <ul>
                                {% assign level-3 = site.entries | where: "parent-id", child.sectionid | sort: "number" %}
                                {% for grandchild in level-3 %}
                                <li>
                                    <a href="#{{ grandchild.sectionid }}">{{ grandchild.title }}</a>
                                </li>
                                {% endfor %}
                            </ul>
                        {% endif %}
                    </li>
                {% endfor %}
            </ul>
        {% endif %}
    </li>
    {% endfor %}
</ul>
{% endraw %}
{% endhighlight %}

**4-level nav:**

{% highlight html %}
{% raw %}
<ul id="nav">
    {% assign level-1 = site.entries | where: "sectionclass", "h1" | sort: "number"%}
    {% for entry in level-1 %}
    <li {% if entry.is-parent or forloop.first %} class="{% if entry.is-parent %}parent{% endif %}{% if forloop.first %} current{% endif %}"{% endif %}>
        <a href="#{{ entry.sectionid }}">{{ entry.title }}</a>
        {% if entry.is-parent %}
            <ul>
                {% assign level-2 = site.entries | where: "parent-id", entry.sectionid | sort: "number" %}
                {% for child in level-2 %}
                    <li {% if child.is-parent %}class="parent"{% endif %}>
                        <a href="#{{ child.sectionid }}">{{ child.title }}</a>
                        {% if child.is-parent %}
                            <ul>
                                {% assign level-3 = site.entries | where: "parent-id", child.sectionid | sort: "number" %}
                                {% for grandchild in level-3 %}
                                <li>
                                    <a href="#{{ grandchild.sectionid }}">{{ grandchild.title }}</a>
                                    {% if grandchild.is-parent %}
                                    <ul>
                                        {% assign level-4 = site.entries | where: "parent-id", grandchild.sectionid | sort: "number" %}
                                        {% for great-grandchild in level-4 %}
                                        <li>
                                            <a href="#{{ great-grandchild.sectionid }}">{{ great-grandchild.title }}</a>
                                        </li>
                                        {% endfor %}
                                    </ul>
                                    {% endif %}
                                </li>
                                {% endfor %}
                            </ul>
                        {% endif %}
                    </li>
                {% endfor %}
            </ul>
        {% endif %}
    </li>
    {% endfor %}
</ul>
{% endraw %}
{% endhighlight %}