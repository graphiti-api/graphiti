---
layout: page
---

Tutorial
==========

<p align="center">
<img src="https://user-images.githubusercontent.com/55264/45711831-c87dbd80-bb58-11e8-9c67-84ba9427d60a.gif">
</p>

<br />

This tutorial **reads a graph of data** and **writes a graph of data**,
performing common operations like sorting, filtering, and nested forms.

The sample applications are broken into step-by-step branches. See the diff
of each step to see what's going on.

<div class="clearfix">
<div markdown="1" class="tutorial col-md-6">

### Server Side: Rails

[Rails Sample Application](https://github.com/graphiti-api/employee_directory)

* [Step 1: Initial Resource](https://github.com/graphiti-api/employee_directory/commit/45c1c92e14fb1c3a47b8ed246ceb2cba50e97c72)
* [Step 2: Has Many](https://github.com/graphiti-api/employee_directory/compare/step_1_employees...step_2_positions)
* [Step 3: Belongs To](https://github.com/graphiti-api/employee_directory/compare/step_2_positions...step_3_departments)
* [Step 4: Customizing Queries](https://github.com/graphiti-api/employee_directory/compare/step_3_departments...step_4_customizations)
* [Step 5: Has One](https://github.com/graphiti-api/employee_directory/compare/step_4_customizations...step_5_has_one)
* [Step 6: Customizing Writes](https://github.com/graphiti-api/employee_directory/compare/step_5_has_one...step_6_write_customization)
* [Step 7: Many-to-Many](https://github.com/graphiti-api/employee_directory/compare/step_6_write_customization...step_7_many_to_many)
* [Step 8: Polymorphic Relationships](https://github.com/graphiti-api/employee_directory/compare/step_7_many_to_many...step_8_polymorphic_belongs_to)
* [Step 9: Polymorphic Resources](https://github.com/graphiti-api/employee_directory/compare/step_8_polymorphic_belongs_to...step_9_polymorphic_resource)

</div>

<div markdown="1" class="tutorial col-md-6">

### Client Side: VueJS

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

</div>
</div>

<br />
<br />
<br />
<br />
<br />
<br />
