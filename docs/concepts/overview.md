---
title: 'Lifecycle of a Request'
---

# Lifecycle of a Request

A request goes down through a Resource to your data, and comes back up as a serialized response.

<figure>
<svg viewBox="0 0 790 300" role="img" aria-label="A request reaches an Endpoint (your Rails controller), then a Resource. The Resource builds a scope from the request, queries your Backend through an Adapter, resolves the results into Models, and serializes them into the JSON:API response that goes back to the client. The Resource and the JSON:API response are Graphiti. The Endpoint and Backend are yours." style={{width: '100%', height: 'auto'}}>
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0 0 L10 5 L0 10 z" fill="var(--ifm-color-emphasis-500)"/>
    </marker>
    <marker id="arrowStart" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M10 0 L0 5 L10 10 z" fill="var(--ifm-color-emphasis-500)"/>
    </marker>
  </defs>

  <g fill="none" stroke="var(--ifm-color-emphasis-500)" strokeWidth="1.5">
    <path d="M150 64 H176" markerEnd="url(#arrow)"/>
    <path d="M310 64 H336" markerEnd="url(#arrow)"/>
    <path d="M574 96 H626" markerEnd="url(#arrow)" markerStart="url(#arrowStart)"/>
    <path d="M336 230 H156" markerEnd="url(#arrow)"/>
    <path d="M85 206 V92" markerEnd="url(#arrow)"/>
  </g>

  <g stroke="var(--ifm-color-emphasis-300)" fill="var(--ifm-background-surface-color)">
    <rect x="20" y="40" width="130" height="48" rx="6"/>
    <rect x="180" y="40" width="130" height="48" rx="6"/>
    <rect x="630" y="70" width="140" height="52" rx="6"/>
  </g>
  <g stroke="var(--ifm-color-primary)" strokeWidth="1.5" fill="none">
    <rect x="340" y="30" width="230" height="230" rx="8"/>
    <rect x="20" y="206" width="130" height="48" rx="6"/>
  </g>

  <g fontFamily="var(--ifm-font-family-base)" fontSize="15" fill="var(--ifm-font-color-base)" textAnchor="middle">
    <text x="85" y="70">Request</text>
    <text x="245" y="70">Endpoint</text>
    <text x="700" y="102">Backend</text>
    <text x="85" y="236">JSON:API</text>
  </g>
  <g fontFamily="var(--ifm-font-family-base)" fontSize="15" fill="var(--ifm-color-primary)" textAnchor="middle">
    <text x="455" y="62">Resource</text>
  </g>

  <g fontFamily="var(--ifm-font-family-base)" fontSize="12.5" fill="var(--ifm-color-emphasis-700)" textAnchor="middle">
    <text x="455" y="104">base_scope + filters,</text>
    <text x="455" y="122">sorts, pagination</text>
    <text x="455" y="163">resolve(scope)</text>
    <text x="455" y="181">to your Models</text>
    <text x="455" y="222">serialize</text>
    <text x="600" y="86">Adapter</text>
  </g>
  <g fontFamily="var(--ifm-font-family-base)" fontSize="12.5" fill="var(--ifm-color-emphasis-700)">
    <text x="95" y="152">response</text>
  </g>
</svg>
</figure>

Graphiti is the highlighted part: the Resource, and the JSON:API it renders. The Endpoint is your Rails controller, which handles routing, response codes and MIME types. The Backend is yours too.

| Piece | What it does |
| --- | --- |
| [Endpoint](/concepts/endpoints) | Your controller. Graphiti registers its path and actions, which drives link generation and endpoint validation, and lets you vary a Resource's behavior per route. |
| [Resource](/concepts/resources) | Turns request params into a **scope**, resolves that scope into Models, and serializes them on the way back out. |
| Adapter | Reusable glue between a Resource and a Backend. Defaults to `Graphiti::Adapters::ActiveRecord`. |
| [Backend](/concepts/backends-and-models) | Whatever you query: a database, a search index, an HTTP service. |
| [Model](/concepts/backends-and-models) | What you return and serialize. With ActiveRecord, the same object as the Backend. |

## The graph

Resources connect to other Resources:

* **Sideloading**: fetch an employee, her positions, and those positions' departments in one request
* **Sideposting**: *save* an employee and her positions in one request
* **[Links](/concepts/links)**: a URL to lazy-load positions in a separate request

Query logic written for one Resource applies at every level of that graph, so you can ask for an employee and her last three positions ordered by `created_at`. That's [deep querying](/concepts/relationships#deep-queries).
