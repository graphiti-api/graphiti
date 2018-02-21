---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Authentication

JSORM supports [JSON Web Tokens](https://jwt.io/introduction). These can
be set manually, or automatically fetched from `localStorage`.

To set manually:

{% highlight typescript %}
ApplicationRecord.jwt = 'myt0k3n'
{% endhighlight %}
> All requests will now send the header:<br/>
> `Authorization: Token token="myt0k3n"`.

To set via `localStorage`, simply store the token with a key of `jwt`
and it will be set automatically. To customize the `localStorage` key:

{% highlight typescript %}
ApplicationRecord.jwtStorage = "authtoken"
{% endhighlight %}

...or to opt-out of `localStorage` altogether:

{% highlight typescript %}
ApplicationRecord.jwtStorage = false
{% endhighlight %}

You can control the format of the header that is sent to the
server:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  class ApplicationRecord extends JSORMBase {
    // ... code ...
    static generateAuthHeader(token) {
      return `Bearer ${token}`
    }
  }
  {% endhighlight %}

  {% highlight javascript %}
  var ApplicationRecord = JSORMBase.extend({
    // ... code ...
    static: {
      generateAuthHeader: function(token) {
        return "Bearer " + token;
      }
    }
  });
  {% endhighlight %}
</div>

Finally, if your server returns a refreshed JWT within the `X-JWT`
header, it will be used in all subsequent requests (and `localStorage`
will be updated automatically if you're using it).

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/state-syncing">
      NEXT:
      <small>State Syncing</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}

