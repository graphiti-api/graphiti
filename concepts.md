---
layout: page
---
<div id="docs">
  <div id="guide">
    <h1 class="logo">
      <a href="index.html">JSONAPI Suite</a>
    </h1>
    <ul class="menu nav">
      {% for doc in site.data.docs %}
        <li>
          <a href="#{{ doc.id }}">{{ doc.title }}</a>
        </li>
      {% endfor %}
    </ul>
  </div>

  <div id="api-docs">
    <div id="methods">
      {% for doc in site.data.docs %}
        <div class="method" id="{{ doc.id }}">
          <div class="method-section clearfix">
            <div class="method-description">
              <h3>{{ doc.title }}</h3>
              {% include docs/{{doc.id}}/description.html %}
            </div>
            <div class="method-example">
              <pre>
                <code class="ruby">
{% include docs/{{doc.id}}/example.html %}
                </code>
              </pre>
            </div>
          </div>
        </div>
      {% endfor %}
    </div>
  </div>
</div>

{% include highlight.html %}
