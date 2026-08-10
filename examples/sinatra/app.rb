require "sinatra/base"
require "active_record"
require "kaminari"
require "graphiti"
require "rescue_registry"
require_relative "seeds"

class ApplicationResource < Graphiti::Resource
  self.abstract_class = true
  self.adapter = Graphiti::Adapters::ActiveRecord
  self.endpoint_namespace = "/api/v1"
  self.autolink = false
end

class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :age, :integer

  has_many :positions
end

class PositionResource < ApplicationResource
  attribute :employee_id, :integer, only: [:filterable]
  attribute :department_id, :integer, only: [:filterable]
  attribute :title, :string

  belongs_to :department
end

class DepartmentResource < ApplicationResource
  attribute :name, :string
end

Graphiti.setup!

class EmployeeDirectory < Sinatra::Base
  set :show_exceptions, :after_handler

  before "/api/*" do
    content_type "application/vnd.api+json"
  end

  get "/" do
    send_file File.join(__dir__, "public", "index.html")
  end

  get "/api/v1/employees" do
    EmployeeResource.all(params).to_jsonapi
  end

  get "/api/v1/employees/:id" do
    EmployeeResource.find(params).to_jsonapi
  end

  error Graphiti::Errors::RecordNotFound do
    handler = RescueRegistry::ExceptionHandler.new(env["sinatra.error"], status: 404)
    status 404
    handler.build_payload.to_json
  end
end
