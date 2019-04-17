EMPLOYEE_CONTROLLER_BLOCK = lambda do |*args|
  def resource
    EmployeeResource
  end

  def create
    employee = resource.build(params)

    if employee.save
      render jsonapi: employee
    else
      render jsonapi_errors: employee
    end
  end

  def update
    employee = resource.find(params)

    if employee.update_attributes
      render jsonapi: employee
    else
      render jsonapi_errors: employee
    end
  end

  def destroy
    employee = resource.find(params)

    if employee.destroy
      render json: {meta: {}}
    else
      render jsonapi_errors: employee
    end
  end
end
