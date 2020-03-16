if ENV["APPRAISAL_INITIALIZED"]
  ::PersistenceTestsController = Class.new(ApplicationController, &EMPLOYEE_CONTROLLER_BLOCK)

  RSpec.describe "persisting and retrieving in a single request", type: :request do
    before do
      Rails.application.routes.draw do
        post "/employees", to: PersistenceTestsController.action(:create)
        put "/employees/:id", to: PersistenceTestsController.action(:update)
      end
    end

    after do
      Rails.application.reload_routes!
    end

    let(:params) { {} }

    subject(:make_request) do
      if Rails::VERSION::MAJOR == 4
        send(request_method, request_path, payload)
      else
        send(request_method, request_path, params: payload)
      end
    end

    let(:request_path) { "#{path}?#{params.to_param}" }

    describe "create" do
      let(:request_method) { :post }
      let(:path) { "/employees" }

      describe "basic create" do
        let(:payload) do
          {
            data: {
              type: "employees",
              attributes: {first_name: "Joe"}
            }
          }
        end

        context "when stats are requested" do
          let(:params) do
            {
              stats: {
                total: "count"
              }
            }
          end

          it "should include the stats in the response" do
            make_request

            expect(json["meta"]).to eq({
              "stats" => {
                "total" => {
                  "count" => 1
                }
              }
            })
          end
        end

        context "when specific fields are requested" do
          let(:params) do
            {
              fields: {
                employees: "first_name"
              }
            }
          end

          it "should only return the requested fields" do
            make_request

            expect(jsonapi_data.attributes).to eq({
              "id" => Employee.last.id.to_s,
              "jsonapi_type" => "employees",
              "first_name" => "Joe"
            })
          end
        end
      end

      describe "nested create" do
        let(:payload) do
          {
            data: {
              type: "employees",
              'temp-id': "empl1",
              attributes: {first_name: "Joe"},
              relationships: {
                positions: {
                  data: [
                    {type: "positions", 'temp-id': "pos1", method: "create"},
                    {type: "positions", 'temp-id': "pos2", method: "create"}
                  ]
                }
              }
            },
            included: [
              {
                type: "positions",
                'temp-id': "pos1",
                attributes: {title: "specialist"},
                relationships: {
                  department: {
                    data: {type: "departments", 'temp-id': "dep1", method: "create"}
                  }
                }
              },
              {
                type: "departments",
                'temp-id': "dep1",
                attributes: {name: "safety"}
              },
              {
                type: "positions",
                'temp-id': "pos2",
                attributes: {title: "manager"}
              }
            ]
          }
        end

        context "when specific fields are specified" do
          let(:params) do
            {
              fields: {
                employees: "first_name",
                positions: "title",
                departments: "name"
              }
            }
          end

          it "still returns the temporary IDs" do
            make_request

            raw_json = JSON.parse(response.body)
            includes_temp_ids = raw_json["included"].map { |i| i["temp-id"] }

            expect(raw_json["data"]["temp-id"]).to eq("empl1")
            expect(includes_temp_ids.sort).to eq(["dep1", "pos1", "pos2"])
          end
        end

        context "when associating to an existing record" do
          let!(:department) { Department.create!(name: "Parks & Recreation") }
          let!(:position) { Position.create!(title: "Deputy Director", department: department) }

          let(:payload) do
            {
              data: {
                type: "employees",
                attributes: {first_name: "Leslie"},
                relationships: {
                  positions: {
                    data: {
                      type: "positions", id: position.id.to_s
                    }
                  }
                }
              }
            }
          end

          let(:params) do
            {
              include: "positions.department"
            }
          end

          it "allows sideloading nested records" do
            make_request

            expect(included("departments")[0].attributes).to eq({
              "id" => department.id.to_s,
              "name" => department.name,
              "jsonapi_type" => "departments"
            })
          end
        end
      end
    end

    describe "update" do
      let(:request_method) { :put }
      let(:path) { "/employees/#{employee.id}" }

      let(:employee) do
        Employee.create(first_name: "Joe", last_name: "Blow", nickname: "Slugger")
      end

      let(:payload) do
        {
          data: {
            id: employee.id,
            type: "employees",
            attributes: {first_name: "Jane"}
          }
        }
      end

      it "updates the data correctly" do
        expect {
          make_request
        }.to change { employee.reload.first_name }.from("Joe").to("Jane")
      end

      context "when specific fields and sideloads are requested" do
        let!(:salary) { Salary.create!(base_rate: 80, overtime_rate: 800, employee: employee) }

        let(:params) do
          {
            fields: {
              employees: "first_name",
              salaries: "base_rate"
            },
            extra_fields: {
              employees: "nickname"
            },
            include: "salary"
          }
        end

        it "responds with only the requested fields" do
          make_request

          expect(jsonapi_data.attributes).to eq({
            "id" => employee.id.to_s,
            "jsonapi_type" => "employees",
            "first_name" => "Jane",
            "nickname" => "Slugger"
          })
        end

        it "includes requested sideloads and their requested fields" do
          make_request

          expect(included("salaries").first.attributes).to eq({
            "id" => salary.id.to_s,
            "jsonapi_type" => "salaries",
            "base_rate" => 80.0
          })
        end
      end

      describe "nested update" do
        let!(:employee) { Employee.create!(first_name: "original", positions: [position1, position2], teams: teams) }
        let!(:position1) { Position.create!(title: "unchanged") }
        let!(:position2) { Position.create!(title: "original", department: department) }
        let!(:department) { Department.create!(name: "original") }
        let!(:salary) { Salary.create!(base_rate: 80, overtime_rate: 800, employee: employee) }
        let!(:teams) { [Team.create!(name: "The A Team"), Team.create!(name: "The X Men")] }

        let(:path) { "/employees/#{employee.id}" }

        let(:payload) do
          {
            data: {
              id: employee.id,
              type: "employees",
              attributes: {first_name: "updated first name"},
              relationships: {
                positions: {
                  data: [
                    {type: "positions", id: position2.id.to_s, method: "update"}
                  ]
                },
                salary: {
                  data: {type: "salaries", id: salary.id.to_s, method: "update"}
                }
              }
            },
            included: [
              {
                type: "positions",
                id: position2.id.to_s,
                attributes: {title: "updated title"},
                relationships: {
                  department: {
                    data: {type: "departments", id: department.id.to_s, method: "update"}
                  }
                }
              },
              {
                type: "departments",
                id: department.id.to_s,
                attributes: {name: "updated name"}
              },
              {
                type: "salaries",
                id: salary.id.to_s,
                attributes: {base_rate: 600}
              }
            ]
          }
        end

        context "when positions and teams are included in requested output" do
          let(:params) do
            {
              include: "positions,teams"
            }
          end

          it "updates only the provided objects" do
            expect {
              make_request
            }.not_to(change { employee.teams })

            employee.reload
            expect(employee.first_name).to eq("updated first name")
            expect(employee.positions[0].title).to eq("unchanged")
            expect(employee.positions[1].title).to eq("updated title")
            expect(employee.positions[1].department.name).to eq("updated name")
            expect(employee.salary.base_rate).to eq(600)
          end

          it "sideloads the updated objects plus included objects" do
            make_request

            expect(included("teams").length).to eq(2)
            expect(included("positions").length).to eq(2)
            expect(included("departments").length).to eq(1)
            expect(included("salaries").length).to eq(1)
          end
        end
      end
    end
  end
end
