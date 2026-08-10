require "rack/test"
require "json"
require_relative "app"

class Smoke
  include Rack::Test::Methods

  def app
    EmployeeDirectory
  end

  def assert(condition, message)
    raise message unless condition
  end

  def run
    get "http://localhost/"
    assert last_response.status == 200, "expected 200 from the index page"
    assert last_response.body.include?("Graphiti on Sinatra"), "expected the explorer page"
    assert last_response.content_type.include?("text/html"), "browsers won't render the page as #{last_response.content_type}"

    get "http://localhost/api/v1/employees", filter: {age: {gt: 30}}, sort: "-id", include: "positions.department"
    assert last_response.status == 200, "expected 200, got #{last_response.status}"
    payload = JSON.parse(last_response.body)
    names = payload["data"].map { |d| d["attributes"]["first_name"] }
    assert names == ["Saul", "Walter"], "expected Saul and Walter, got #{names}"
    included = payload["included"].map { |i| i["type"] }.sort.uniq
    assert included == ["departments", "positions"], "expected sideloaded positions and departments"

    get "http://localhost/api/v1/employees/1"
    assert last_response.status == 200, "expected 200, got #{last_response.status}"
    assert last_response.content_type == "application/vnd.api+json", "expected the JSON:API content type, got #{last_response.content_type}"

    get "http://localhost/api/v1/employees/999"
    assert last_response.status == 404, "expected 404, got #{last_response.status}"
    assert JSON.parse(last_response.body).key?("errors"), "expected a JSON:API errors payload"

    puts "Sinatra example OK"
  end
end

Smoke.new.run
