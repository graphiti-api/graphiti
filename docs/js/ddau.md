---
title: 'Ddau'
sidebar_position: 9
---

### Data Down, Actions Up

It's a [popular pattern](http://www.samselikoff.com/blog/data-down-actions-up) to pass data **down** to components, avoid modifying state within the component, and instead pass **actions up** to modify state. This can make complex applications easier to track and reason about, and you'll see it in client-side frameworks like React.

To follow this pattern, use `#dup()` when passing down to your component:

```bash
<my-component something="model.dup()" />
```

This will create a new instance of the model with all the same state.
Avoid modifying this instance in your component and instead pass
**actions up**.

When opting-in to [state-syncing](/js/state-syncing) these instances will sync-up whenever one of these is instances is persisted. You won't have to worry about updating the child component when the parent instance is saved.
