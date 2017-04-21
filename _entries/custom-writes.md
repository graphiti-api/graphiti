---
sectionid: custom-writes
sectionclass: h2
title: Custom Writes
parent-id: writes
number: 17
---

Use your Resource to customize write logic. Here's where you could use
something other than ActiveRecord, send an email after a record is
created, etc:

```ruby
  def create(attributes)
    employee = Employee.create(attributes)
    log('Created', employee)
    employee
  end

  def update(attributes)
    employee = Employee.find(attributes[:id])
    employee.update_attributes(attributes.except(:id))
    log('Updated', employee)
    employee
  end

  def destroy(id)
    employee = Employee.find(id)
    employee.destroy
    log('Deleted', employee)
    employee
  end

  private

  def log(prefix, employee)
    Rails.logger.info "#{prefix} #{employee.first_name} Employee via API"
    end
````
