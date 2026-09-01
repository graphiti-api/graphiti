---
title: 'Tutorial'
---

<p align="center">
  <img src="/assets/img/legacy/legacy-0c75a16b3a.gif" />
</p>

# Tutorial
This tutorial serves as a deeper-dive into Graphiti development,
building an Employee Directory application. We purposefully built this
to illustrate common - but non-trivial - scenarios present in many
applications.

You'll need Ruby 3.2+ and Rails 7.1+ installed. Step 0 starts from an empty directory, so nothing else is assumed.

A core concept of Graphiti is **Test-First** - the most pleasant way to
develop Graphiti is by starting with an [integration test](/topics/testing). But that can add a lot of noise to a tutorial like this. Though we'll occasionally touch on testing - and the git diffs at the top of each section contain the necessary tests - we won't test first for the purposes of this tutorial.


### Server Side: Rails

[Rails Sample Application](https://github.com/graphiti-api/employee_directory)

* [Step 0: Bootstrapping](/tutorial/step_0)
* [Step 1: Initial Resource](/tutorial/step_1)
* [Step 2: Has Many](/tutorial/step_2)
* [Step 3: Belongs To](/tutorial/step_3)
* [Step 4: Customizing Queries](/tutorial/step_4)
* [Step 5: Has One](/tutorial/step_5)
* [Step 6: Customizing Writes](/tutorial/step_6)
* [Step 7: Many-to-Many](/tutorial/step_7)
* [Step 8: Polymorphic
Relationships](/tutorial/step_8)
* [Step 9: Polymorphic Resources](/tutorial/step_9)



### Client Side: VueJS (diff-only)

[VueJS Sample Application](https://github.com/graphiti-api/employee-directory-vue)


* [Step 0: Setup](https://github.com/graphiti-api/employee-directory-vue/commit/be690c3038380e17e326935d595a0b83fc8004f9)
  * Run after `vue create employee-directory-vue` using [Vue CLI](https://cli.vuejs.org).
* [Step 1: Define Models](https://github.com/graphiti-api/employee-directory-vue/compare/step_0_setup...step_1_models)
* [Step 2: Data Grid](https://github.com/graphiti-api/employee-directory-vue/compare/step_1_models...step_2_data_grid)
* [Step 3: Relationships](https://github.com/graphiti-api/employee-directory-vue/compare/step_2_data_grid...step_3_includes)
* [Step 4: Filtering](https://github.com/graphiti-api/employee-directory-vue/compare/step_3_includes...step_4_filtering)
* [Step 5: Sorting](https://github.com/graphiti-api/employee-directory-vue/compare/step_4_filtering...step_5_sorting)
* [Step 6: Total Count](https://github.com/graphiti-api/employee-directory-vue/compare/step_5_sorting...step_6_stats)
* [Step 7: Pagination](https://github.com/graphiti-api/employee-directory-vue/compare/step_6_stats...step_7_pagination)
* [Step 8: Basic Form Setup](https://github.com/graphiti-api/employee-directory-vue/compare/step_7_pagination...step_8_basic_form_setup)
* [Step 9: Dropdown](https://github.com/graphiti-api/employee-directory-vue/compare/step_8_basic_form_setup...step_9_dropdown)
* [Step 10: Nested Form Submission](https://github.com/graphiti-api/employee-directory-vue/compare/step_9_dropdown...step_10_nested_create)
* [Step 11: Validation Errors](https://github.com/graphiti-api/employee-directory-vue/compare/step_10_nested_create...step_11_validations)
* [Step 12: Nested Destroy](https://github.com/graphiti-api/employee-directory-vue/compare/step_11_validations...step_12_nested_destroy)
* [Step 13: Vue-Specific Glue Code](https://github.com/graphiti-api/employee-directory-vue/compare/step_12_nested_destroy...step_13_vue)
