---
sectionid: association-queries
sectionclass: h4
title: Querying Associations
parent-id: sideloading
number: 15
---

Sideloads can be thought of as nested Resources - in fact, a Sideload
probably has an associated Resource object. Because of this, we can
query our associations as well:

* Filtering: `/employees?include=positions&filter[positions][title]=Manager`
* Sorting: `/employees?include=positions&sort=positions.title`
* Sparse fieldsets:
  `/employees?include=positions&fields[positions]=title,salary`
* Pagination:
  `/employees/123?include=positions&page[positions][size]=10`

Note - in our pagination example, we're hitting the `show` action. Due
to the nature of sideloading, paginating relationships of an array may
have issues.
