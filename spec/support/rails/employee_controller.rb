EMPLOYEE_CONTROLLER_BLOCK = lambda do |*args|
  def resource
    EmployeeResource
  end

  def create
    employee = resource.build(params)

    if employee.save
      render jsonapi: employee
    else
      render json: {
        errors: {
          employee: employee.errors,
          positions: employee.data.positions.map(&:errors),
          departments: employee.data.positions.map(&:department).compact.map(&:errors)
        }
      }
    end
  end

  def update
    employee = resource.find(params)

    if employee.update_attributes
      render jsonapi: employee
    else
      render json: { error: employee.errors }
    end
  end

  def destroy
    employee = resource.find(params)

    if employee.destroy
      render json: { meta: {} }
    else
      render json: { error: employee.errors }
    end
  end
end
