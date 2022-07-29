if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "persistence", type: :controller do
    include GraphitiSpecHelpers

    # defined in spec/supports/rails/employee_controller.rb
    controller(ApplicationController, &EMPLOYEE_CONTROLLER_BLOCK)

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    let(:path) { "/employees" }

    before do
      @request.headers["Accept"] = Mime[:json]
      @request.headers["Content-Type"] = Mime[:json].to_s

      routes.draw {
        post "create" => "anonymous#create"
        put "update" => "anonymous#update"
        delete "destroy" => "anonymous#destroy"
      }
    end

    describe "basic create" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Joe"}
          }
        }
      end

      subject(:make_request) do
        do_create(payload)
      end

      it "persists the employee" do
        expect {
          make_request
        }.to change { Employee.count }.by(1)
        employee = Employee.first
        expect(employee.first_name).to eq("Joe")
      end

      it "responds with the persisted data" do
        make_request
        expect(jsonapi_data["id"]).to eq(Employee.first.id.to_s)
        expect(jsonapi_data["first_name"]).to eq("Joe")
      end

      context "when validation error" do
        before do
          payload[:data][:attributes][:first_name] = nil
        end

        it "returns validation error response" do
          make_request
          expect(json["errors"].first).to match(
            "code" => "unprocessable_entity",
            "status" => "422",
            "source" => {"pointer" => "/data/attributes/first_name"},
            "detail" => "First name can't be blank",
            "title" => "Validation Error",
            "meta" => hash_including(
              "attribute" => "first_name",
              "message" => "can't be blank"
            )
          )
        end
      end
    end

    describe "basic update" do
      let(:employee) { Employee.create(first_name: "Joe") }

      let(:payload) do
        {
          data: {
            id: employee.id,
            type: "employees",
            attributes: {first_name: "Jane"}
          }
        }
      end

      let(:path) { "/employees/#{employee.id}" }

      subject(:make_request) do
        do_update(payload)
      end

      it "updates the data correctly" do
        expect {
          make_request
        }.to change { employee.reload.first_name }.from("Joe").to("Jane")
      end

      it "responds with the persisted data" do
        make_request
        expect(jsonapi_data["id"]).to eq(employee.id.to_s)
        expect(jsonapi_data["first_name"]).to eq("Jane")
      end

      context "when reserved parameter used" do
        before do
          resource = Class.new(EmployeeResource) do
            self.validate_endpoints = false
            attribute :page, :integer
          end
          allow(controller).to receive(:resource) { resource }
          Employee.class_eval do
            attr_accessor :page
          end
          payload[:data][:attributes].merge!(page: 1)
        end

        after do
          Employee.class_eval do
            undef :page
            undef :page=
          end
        end

        it "works as normal" do
          expect {
            make_request
          }.to change { employee.reload.first_name }.from("Joe").to("Jane")
        end
      end

      context "when there is a validation error" do
        before do
          payload[:data][:attributes][:first_name] = nil
        end

        it "responds with error" do
          make_request
          expect(json["errors"].first).to match(
            "code" => "unprocessable_entity",
            "status" => "422",
            "source" => {"pointer" => "/data/attributes/first_name"},
            "detail" => "First name can't be blank",
            "title" => "Validation Error",
            "meta" => hash_including(
              "attribute" => "first_name",
              "message" => "can't be blank"
            )
          )
        end
      end

      context "when there is an invalid request payload" do
        before do
          payload[:data][:type] = ""
        end

        it "raises a Graphiti::Errors::ConflictRequest" do
          expect {
            make_request
          }.to raise_error(Graphiti::Errors::ConflictRequest)
        end
      end
    end

    describe "basic destroy" do
      let!(:employee) { Employee.create!(first_name: "Joe") }

      let(:path) { "/employees/#{employee.id}" }

      before do
        allow_any_instance_of(Employee)
          .to receive(:force_validation_error) { force_validation_error }
      end

      let(:force_validation_error) { false }

      it "deletes the object" do
        expect {
          do_destroy({id: employee.id})
        }.to change { Employee.count }.by(-1)
        expect { employee.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "responds with 200, empty meta" do
        do_destroy({id: employee.id})
        expect(response.status).to eq(200)
        expect(json).to eq({"meta" => {}})
      end

      context "when validation errors" do
        let(:force_validation_error) { true }

        it "responds with correct error payload" do
          expect {
            do_destroy({id: employee.id})
          }.to_not(change { Employee.count })
          expect(json["errors"].first).to match(
            "code" => "unprocessable_entity",
            "status" => "422",
            "source" => {"pointer" => nil},
            "detail" => "Forced validation error",
            "title" => "Validation Error",
            "meta" => hash_including(
              "attribute" => "base",
              "message" => "Forced validation error"
            )
          )
        end
      end
    end

    describe "non-writable association" do
      subject(:make_request) { do_update(payload) }

      context "when has_many" do
        let(:klass) do
          Class.new(EmployeeResource) do
            self.validate_endpoints = false
          end
        end

        let(:position_resource) do
          Class.new(PositionResource) do
            self.model = ::Position
          end
        end

        let(:employee) { Employee.create!(first_name: "Jane") }

        let(:payload) do
          {
            data: {
              type: "employees",
              id: employee.id.to_s,
              relationships: {
                positions: {
                  data: [{
                    'temp-id': "abc123",
                    type: "positions",
                    method: "create"
                  }]
                }
              }
            },
            included: [
              {
                'temp-id': "abc123",
                type: "positions",
                attributes: {title: "foo"}
              }
            ]
          }
        end

        before do
          klass.has_many :positions, resource: position_resource, writable: false
          allow(controller).to receive(:resource) { klass }
        end

        it "raises error" do
          expect {
            make_request
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.relationships.positions is unwritable relationship"]
          })
        end
      end

      context "when belongs_to" do
        let(:klass) do
          Class.new(EmployeeResource) do
            self.validate_endpoints = false
            belongs_to :classification, writable: false
          end
        end

        let(:employee) { Employee.create!(first_name: "Jane") }
        let(:classification) { Classification.create!(description: "foo") }

        let(:payload) do
          {
            data: {
              type: "employees",
              id: employee.id.to_s,
              relationships: {
                classification: {
                  data: {
                    id: classification.id.to_s,
                    type: "classifications"
                  }
                }
              }
            }
          }
        end

        before do
          allow(controller).to receive(:resource) { klass }
        end

        it "raises error" do
          expect {
            make_request
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.relationships.classification is unwritable relationship"]
          })
        end
      end
    end

    describe "after graph persisted validation" do
      subject(:make_request) { do_update(payload) }

      let(:klass) do
        Class.new(EmployeeResource) do
          self.validate_endpoints = false

          after_graph_persist do |model|
            model.valid?(:after_graph_persisted)
          end
        end
      end

      let(:polyvalentEmployee) do
        Class.new(Employee) do
          def self.model_name
            ActiveModel::Name.new(self, nil, "PolyvalentEmployee")
          end
          validates :positions, length: {minimum: 2, too_short: "too short, minimum is 2"}, on: :after_graph_persisted
        end
      end

      let(:employee) { Employee.create!(first_name: "Jane") }

      let(:payload) do
        {
          data: {
            type: "employees",
            id: employee.id.to_s,
            relationships: {
              positions: {
                data: [
                  {'temp-id': "pos1", type: "positions", method: "create"},
                  {'temp-id': "pos2", type: "positions", method: "create"}
                ]
              }
            }
          },
          included: [
            {
              'temp-id': "pos1",
              type: "positions",
              attributes: {title: "foo"}
            },
            {
              'temp-id': "pos2",
              type: "positions",
              attributes: {title: "bar"}
            }
          ]
        }
      end

      before do
        klass.model = polyvalentEmployee
        allow(controller).to receive(:resource) { klass }
      end

      context "when valid" do
        it "responds with the persisted data" do
          make_request
          expect(jsonapi_included.count).to eq(2)
          expect(jsonapi_included.map { |inc| inc.attributes["title"] }).to eq(["foo", "bar"])
        end
      end

      context "when validation error" do
        before do
          payload[:data][:relationships][:positions][:data].pop
        end

        it "returns validation error response" do
          make_request
          expect(json["errors"].first).to match(
            "code" => "unprocessable_entity",
            "status" => "422",
            "source" => {"pointer" => "/data/relationships/positions"},
            "detail" => "Positions too short, minimum is 2",
            "title" => "Validation Error",
            "meta" => hash_including(
              "attribute" => "positions",
              "message" => "too short, minimum is 2"
            )
          )
        end
      end
    end

    describe "non-writable foreign keys" do
      context "when belongs_to" do
        let(:klass) do
          Class.new(EmployeeResource) do
            self.validate_endpoints = false
            attribute :classification_id, :integer, writable: false
          end
        end

        let!(:employee) { Employee.create!(first_name: "Jane") }
        let!(:classification) { Classification.create!(description: "foo") }

        let(:payload) do
          {
            data: {
              type: "employees",
              attributes: {
                first_name: "foo"
              },
              relationships: {
                classification: {
                  data: {
                    id: classification.id.to_s,
                    type: "classifications"
                  }
                }
              }
            }
          }
        end

        before do
          allow(controller).to receive(:resource) { klass }

          classification_resource = Class.new(ClassificationResource) do
            def self.name
              "ClassificationResource"
            end
            attribute :id, :integer_id, writable: false
          end
          klass.belongs_to :classification, resource: classification_resource
        end

        context "and overall action is create" do
          subject(:make_request) { do_create(payload) }

          it "does not require the FK to be a writable attribute" do
            expect {
              make_request
            }.to change { Employee.count }.by(1)
            employee = Employee.last
            expect(employee.classification_id).to eq(classification.id)
          end
        end

        context "and overall action is update" do
          subject(:make_request) { do_update(payload) }

          before do
            payload[:data][:id] = employee.id.to_s
          end

          it "does not require the FK to be a writable attribute" do
            make_request
            expect(employee.reload.classification_id).to eq(classification.id)
          end
        end
      end

      context "when has_many" do
        let(:klass) do
          Class.new(EmployeeResource) do
            self.validate_endpoints = false
          end
        end

        let(:position_resource) do
          Class.new(PositionResource) do
            self.model = ::Position
            attribute :employee_id, :integer, writable: false
          end
        end

        let(:employee) { Employee.create!(first_name: "Jane") }

        let(:payload) do
          {
            data: {
              type: "employees",
              attributes: {
                first_name: "foo"
              },
              relationships: {
                positions: {
                  data: [{
                    'temp-id': "abc123",
                    type: "positions",
                    method: "create"
                  }]
                }
              }
            },
            included: [
              {
                'temp-id': "abc123",
                type: "positions",
                attributes: {title: "foo"}
              }
            ]
          }
        end

        before do
          klass.has_many :positions, resource: position_resource
          allow(controller).to receive(:resource) { klass }
        end

        context "and the overall request is create" do
          subject(:make_request) { do_create(payload) }

          it "does not require the FK to be a writable attribute" do
            expect {
              make_request
            }.to change { Employee.count }.by(1)
            employee = Employee.last
            expect(employee.positions.map(&:title)).to eq(["foo"])
          end
        end

        context "and the overall request is update" do
          subject(:make_request) { do_update(payload) }

          before do
            payload[:data][:id] = employee.id.to_s
          end

          it "does not require the FK to be a writable attribute" do
            make_request
            expect(employee.reload.positions.map(&:title)).to eq(["foo"])
          end
        end
      end
    end

    describe "has_one nested relationship" do
      context "for new records" do
        let(:payload) do
          {
            data: {
              type: "employees",
              attributes: {
                first_name: "Joe",
                last_name: "Smith",
                age: 30
              },
              relationships: {
                salary: {
                  data: {
                    'temp-id': "abc123",
                    type: "salaries",
                    method: "create"
                  }
                }
              }
            },
            included: [
              {
                'temp-id': "abc123",
                type: "salaries",
                attributes: {
                  base_rate: 15.00,
                  overtime_rate: 30.00
                }
              }
            ]
          }
        end

        it "can create" do
          expect {
            do_create(payload)
          }.to change { Salary.count }.by(1)

          salary = Employee.first.salary
          expect(salary.base_rate).to eq(15.0)
          expect(salary.overtime_rate).to eq(30.0)
        end

        context "when the association is null" do
          let(:payload) do
            {
              data: {
                type: "employees",
                attributes: {
                  first_name: "Joe",
                  last_name: "Smith",
                  age: 30
                },
                relationships: {
                  salary: {
                    data: {
                      type: "salaries",
                      id: nil
                    }
                  }
                }
              }
            }
          end

          let!(:existing_salary) { Salary.create(base_rate: 1, overtime_rate: 2) }

          it "blows up" do
            expect {
              do_create(payload)
            }.to raise_error(Graphiti::Errors::UndefinedIDLookup)
          end
        end
      end

      context "for existing records" do
        let(:employee) { Employee.create!(first_name: "Joe") }
        let(:salary) { Salary.new(base_rate: 15.0, overtime_rate: 30.00) }

        before do
          employee.salary = salary
          employee.save!
        end

        subject(:make_request) do
          do_update(payload)
        end

        context "on update" do
          let(:path) { "/employees/#{employee.id}" }

          let(:payload) do
            {
              data: {
                id: employee.id,
                type: "employees",
                relationships: {
                  salary: {
                    data: {
                      id: salary.id,
                      type: "salaries",
                      method: "update"
                    }
                  }
                }
              },
              included: [
                {
                  id: salary.id,
                  type: "salaries",
                  attributes: {
                    base_rate: 15.75
                  }
                }
              ]
            }
          end

          it "can update" do
            expect {
              make_request
            }.to change { employee.reload.salary.base_rate }.from(15.0).to(15.75)
          end
        end

        context "on destroy" do
          let(:path) { "/employees/#{employee.id}" }

          let(:payload) do
            {
              data: {
                id: employee.id,
                type: "employees",
                relationships: {
                  salary: {
                    data: {
                      id: salary.id,
                      type: "salaries",
                      method: "destroy"
                    }
                  }
                }
              }
            }
          end

          it "can destroy" do
            make_request
            employee.reload

            expect(employee.salary).to be_nil
            expect { salary.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context "on disassociate" do
          let(:payload) do
            {
              data: {
                id: employee.id,
                type: "employees",
                relationships: {
                  salary: {
                    data: {
                      id: salary.id,
                      type: "salaries",
                      method: "disassociate"
                    }
                  }
                }
              }
            }
          end

          let(:path) { "/employees/#{employee.id}" }

          it "can disassociate" do
            make_request
            salary.reload

            expect(salary.employee_id).to be_nil
          end
        end
      end
    end

    describe "nested create" do
      subject(:make_request) do
        do_create(payload)
      end

      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Joe"},
            relationships: {
              positions: {
                data: [
                  {type: "positions", 'temp-id': "pos1", method: "create"},
                  {type: "positions", 'temp-id': "pos2", method: "create"}
                ]
              },
              teams: {
                data: [
                  {type: "teams", 'temp-id': "team1", method: "create"}
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
            },
            {
              type: "teams",
              'temp-id': "team1",
              attributes: {name: "Team 1"}
            }
          ]
        }
      end

      it "creates the objects" do
        expect {
          make_request
        }.to change { Employee.count }.by(1)
        employee = Employee.first
        positions = employee.positions
        department = employee.positions[0].department
        team = employee.teams[0]

        expect(employee.first_name).to eq("Joe")
        expect(positions.length).to eq(2)
        expect(positions[0].title).to eq("specialist")
        expect(positions[1].title).to eq("manager")
        expect(department.name).to eq("safety")
        expect(team.name).to eq("Team 1")
      end

      context "when a has_many relationship has validation error" do
        around do |e|
          Position.validates :title, presence: true
          e.run
        ensure
          Position.clear_validators!
        end

        before do
          payload[:included][0][:attributes].delete(:title)
        end

        it "rolls back the entire transaction" do
          expect {
            make_request
          }.to_not(change { Employee.count + Position.count + Department.count + Team.count })
          error = json["errors"].find do |err|
            err.fetch("meta", {}).fetch("relationship", {}).fetch("type", nil) == "positions"
          end

          expect(error).to match(
            "code" => "unprocessable_entity",
            "detail" => "Title can't be blank",
            "meta" => {
              "relationship" => hash_including(
                "attribute" => "title",
                "message" => "can't be blank",
                "name" => "positions",
                "temp-id" => "pos1",
                "type" => "positions"
              )
            },
            "source" => {"pointer" => "/data/attributes/title"},
            "status" => "422",
            "title" => "Validation Error"
          )
        end
      end

      context "when a belongs_to relationship has a validation error" do
        around do |e|
          Department.validates :name, presence: true
          e.run
        ensure
          Department.clear_validators!
        end

        before do
          payload[:included][1][:attributes].delete(:name)
        end

        it "rolls back the entire transaction" do
          expect {
            make_request
          }.to_not(change { Employee.count + Position.count + Department.count + Team.count })
          error = json["errors"].find do |err|
            err.fetch("meta", {}).fetch("relationship", {}).fetch("type", nil) == "departments"
          end

          expect(error).to match(
            "code" => "unprocessable_entity",
            "detail" => "Name can't be blank",
            "meta" => {
              "relationship" => hash_including(
                "attribute" => "name",
                "message" => "can't be blank",
                "name" => "department",
                "temp-id" => "dep1",
                "type" => "departments"
              )
            },
            "source" => {"pointer" => "/data/attributes/name"},
            "status" => "422",
            "title" => "Validation Error"
          )
        end
      end

      context "when a many_to_many relationship has a validation error" do
        around do |e|
          Team.validates :name, presence: true
          e.run
        ensure
          Team.clear_validators!
        end

        before do
          payload[:included][3][:attributes].delete(:name)
        end

        it "rolls back the entire transaction" do
          expect {
            make_request
          }.to_not(change { Employee.count + Position.count + Department.count + Team.count })
          error = json["errors"].find do |err|
            err.fetch("meta", {}).fetch("relationship", {}).fetch("type", nil) == "teams"
          end

          expect(error).to match(
            "code" => "unprocessable_entity",
            "detail" => "Name can't be blank",
            "meta" => {
              "relationship" => hash_including(
                "attribute" => "name",
                "message" => "can't be blank",
                "name" => "teams",
                "temp-id" => "team1",
                "type" => "teams"
              )
            },
            "source" => {"pointer" => "/data/attributes/name"},
            "status" => "422",
            "title" => "Validation Error"
          )
        end
      end

      context "when associating to an existing record" do
        let!(:classification) { Classification.create!(description: "senior") }

        let(:payload) do
          {
            data: {
              type: "employees",
              attributes: {first_name: "Joe"},
              relationships: {
                classification: {
                  data: {
                    type: "classifications", id: classification.id.to_s
                  }
                }
              }
            }
          }
        end

        it "associates to existing record" do
          make_request
          employee = Employee.first
          expect(employee.classification).to eq(classification)
        end
      end

      context "when associating to a nonexistant record" do
        context "and raise_on_missing_sidepost is false" do
          before do
            Graphiti.config.raise_on_missing_sidepost = false
          end

          after do
            Graphiti.config.raise_on_missing_sidepost = true
          end

          let(:payload) do
            {
              data: {
                type: "employees",
                attributes: {first_name: "Joe"},
                relationships: {
                  classification: {
                    data: {
                      type: "classifications", id: "99999"
                    }
                  }
                }
              }
            }
          end

          it "returns validation error" do
            make_request
            if ::Rails::VERSION::MAJOR == 4
              expect(json.deep_symbolize_keys).to eq({
                errors: [{
                  code: "unprocessable_entity",
                  status: "422",
                  title: "Validation Error",
                  detail: "could not be found",
                  source: {pointer: nil},
                  meta: {
                    relationship: {
                      attribute: "base",
                      message: "could not be found",
                      name: "classification",
                      type: "classifications",
                      id: "99999"
                    }
                  }
                }]
              })
            else
              expect(json.deep_symbolize_keys).to eq({
                errors: [{
                  code: "unprocessable_entity",
                  status: "422",
                  title: "Validation Error",
                  detail: "could not be found",
                  source: {pointer: nil},
                  meta: {
                    relationship: {
                      attribute: "base",
                      message: "could not be found",
                      code: "not_found",
                      name: "classification",
                      type: "classifications",
                      id: "99999"
                    }
                  }
                }]
              })
            end
          end
        end

        context "and raise_on_missing_sidepost is true" do
        end
      end

      context "when no method specified" do
        let!(:position) { Position.create!(title: "specialist") }
        let!(:department) { Department.create!(name: "safety") }

        let(:payload) do
          {
            data: {
              type: "employees",
              attributes: {first_name: "Joe"},
              relationships: {
                positions: {
                  data: [
                    {type: "positions", id: position.id.to_s}
                  ]
                }
              }
            },
            included: [
              {
                type: "positions",
                id: position.id.to_s,
                relationships: {
                  department: {
                    data: {type: "departments", id: department.id, method: "destroy"}
                  }
                }
              }
            ]
          }
        end

        it "updates" do
          make_request

          employee = Employee.first
          expect(employee.positions[0]).to eq(position)
          expect(position.department_id).to be_nil
          expect { department.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe "nested update" do
      let!(:employee) { Employee.create!(first_name: "original", positions: [position1, position2]) }
      let!(:position1) { Position.create!(title: "unchanged") }
      let!(:position2) { Position.create!(title: "original", department: department) }
      let!(:department) { Department.create!(name: "original") }

      let(:path) { "/employees/#{employee.id}" }

      subject(:make_request) do
        do_update(payload)
      end

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
            }
          ]
        }
      end

      it "updates the objects" do
        make_request
        employee.reload
        expect(employee.first_name).to eq("updated first name")
        expect(employee.positions[0].title).to eq("unchanged")
        expect(employee.positions[1].title).to eq("updated title")
        expect(employee.positions[1].department.name).to eq("updated name")
      end

      # NB - should only sideload updated position, not all positions
      it "sideloads the objects in response" do
        make_request
        expect(included("positions").length).to eq(1)
        expect(included("positions")[0].id).to eq(position2.id)
        expect(included("departments").length).to eq(1)
      end
    end

    describe "nested deletes" do
      let!(:employee) { Employee.create!(first_name: "Joe") }
      let!(:position) { Position.create!(department_id: department.id, employee_id: employee.id) }
      let!(:department) { Department.create! }

      subject(:make_request) do
        do_update(payload)
      end

      let(:payload) do
        {
          data: {
            id: employee.id,
            type: "employees",
            attributes: {first_name: "updated first name"},
            relationships: {
              positions: {
                data: [
                  {type: "positions", id: position.id.to_s, method: method}
                ]
              }
            }
          },
          included: [
            {
              type: "positions",
              id: position.id.to_s,
              relationships: {
                department: {
                  data: {
                    type: "departments", id: department.id.to_s, method: method
                  }
                }
              }
            }
          ]
        }
      end

      context "when disassociating" do
        let(:method) { "disassociate" }

        let(:path) { "/employees/#{employee.id}" }

        it "belongs_to: updates the foreign key on child" do
          expect {
            make_request
          }.to(change { position.reload.department_id }.to(nil))
        end

        it "has_many: updates the foreign key on the child" do
          expect {
            make_request
          }.to(change { position.reload.employee_id }.to(nil))
        end

        it "does not delete the objects" do
          make_request
          expect { position.reload }.to_not raise_error
          expect { department.reload }.to_not raise_error
        end

        it "does not sideload the objects in the response" do
          make_request
          expect(json).to_not have_key("included")
        end
      end

      context "when destroying" do
        let(:method) { "destroy" }
        let(:path) { "/employees/#{employee.id}" }

        it "deletes the objects" do
          make_request
          expect { position.reload }
            .to raise_error(ActiveRecord::RecordNotFound)
          expect { department.reload }
            .to raise_error(ActiveRecord::RecordNotFound)
        end

        it "does not sideload the objects in the response" do
          make_request
          expect(json).to_not have_key("included")
        end
      end
    end

    describe "nested validation errors" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Joe"},
            relationships: {
              positions: {
                data: [
                  {'temp-id': "a", type: "positions", method: "create"}
                ]
              }
            }
          },
          included: [
            {
              'temp-id': "a",
              type: "positions",
              attributes: {},
              relationships: {
                department: {
                  data: {
                    'temp-id': "b", type: "departments", method: "create"
                  }
                }
              }
            },
            {
              'temp-id': "b",
              type: "departments",
              attributes: {}
            }
          ]
        }
      end

      let(:expected) do
        [
          {
            "code" => "unprocessable_entity",
            "detail" => "Forced validation error",
            "meta" => hash_including("attribute" => "base", "message" => "Forced validation error"),
            "source" => {"pointer" => nil},
            "status" => "422",
            "title" => "Validation Error"
          },
          {
            "code" => "unprocessable_entity",
            "detail" => "Forced validation error",
            "meta" => {
              "relationship" => hash_including(
                "attribute" => "base",
                "message" => "Forced validation error",
                "name" => "positions",
                "temp-id" => "a",
                "type" => "positions"
              )
            },
            "source" => {"pointer" => nil},
            "status" => "422",
            "title" => "Validation Error"
          },
          {
            "code" => "unprocessable_entity",
            "detail" => "Forced validation error",
            "meta" => {
              "relationship" => hash_including(
                "attribute" => "base",
                "message" => "Forced validation error",
                "name" => "department",
                "temp-id" => "b",
                "type" => "departments"
              )
            },
            "source" => {"pointer" => nil},
            "status" => "422",
            "title" => "Validation Error"
          }
        ]
      end

      before do
        allow_any_instance_of(Employee)
          .to receive(:force_validation_error)
          .and_return(true)
        allow_any_instance_of(Position)
          .to receive(:force_validation_error)
          .and_return(true)
        allow_any_instance_of(Department)
          .to receive(:force_validation_error)
          .and_return(true)
      end

      it "displays validation errors for each nested object" do
        do_create(payload)
        expect(json["errors"]).to match_array(expected)
      end
    end

    describe "many_to_many nested relationship" do
      let(:employee) { Employee.create!(first_name: "Joe") }
      let(:prior_team) { Team.new(name: "prior") }
      let(:disassociate_team) { Team.new(name: "disassociate") }
      let(:destroy_team) { Team.new(name: "destroy") }
      let(:associate_team) { Team.create!(name: "preexisting") }

      before do
        employee.teams << prior_team
        employee.teams << disassociate_team
        employee.teams << destroy_team
      end

      let(:path) { "/employees/#{employee.id}" }

      subject(:make_request) do
        do_update(payload)
      end

      let(:payload) do
        {
          data: {
            id: employee.id,
            type: "employees",
            relationships: {
              teams: {
                data: [
                  {'temp-id': "abc123", type: "teams", method: "create"},
                  {id: prior_team.id.to_s, type: "teams", method: "update"},
                  {id: disassociate_team.id.to_s, type: "teams", method: "disassociate"},
                  {id: destroy_team.id.to_s, type: "teams", method: "destroy"},
                  {id: associate_team.id.to_s, type: "teams", method: "update"}
                ]
              }
            }
          },
          included: [
            {
              'temp-id': "abc123",
              type: "teams",
              attributes: {name: "Team #1"}
            },
            {
              id: prior_team.id.to_s,
              type: "teams",
              attributes: {name: "Updated!"}
            },
            {
              id: associate_team.id.to_s,
              type: "teams"
            }
          ]
        }
      end

      it "can create/update/disassociate/associate/destroy" do
        expect(employee.teams).to include(destroy_team)
        expect(employee.teams).to include(disassociate_team)
        make_request

        # Should properly delete/create from the through table
        combos = EmployeeTeam.all.map { |et| [et.employee_id, et.team_id] }
        expect(combos.uniq.length).to eq(combos.length)

        employee.reload
        expect(employee.teams).to_not include(disassociate_team)
        expect(employee.teams).to_not include(destroy_team)
        expect { disassociate_team.reload }.to_not raise_error
        expect { destroy_team.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(prior_team.reload.name).to include("Updated!")
        expect(employee.teams).to include(associate_team)
        expect((employee.teams - [prior_team, associate_team]).first.name)
          .to eq("Team #1")
      end
    end

    describe "nested relationship to polymorphic resource" do
      subject(:make_request) do
        do_create(payload)
      end

      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Joe"},
            relationships: {
              tasks: {
                data: [
                  {'temp-id': "abc123", type: "features", method: "create"},
                  {'temp-id': "abc456", type: "bugs", method: "create"}
                ]
              }
            }
          },
          included: [
            {
              'temp-id': "abc123",
              type: "features",
              attributes: {name: "test feature"}
            },
            {
              'temp-id': "abc456",
              type: "bugs",
              attributes: {name: "test bug"}
            }
          ]
        }
      end

      it "creates correct records" do
        make_request
        employee = Employee.last
        expect(employee.features.length).to eq(1)
        expect(employee.bugs.length).to eq(1)
      end
    end

    describe "nested polymorphic_has_one relationship" do
      subject(:make_request) { do_update(payload) }
      let!(:employee) { Employee.create!(first_name: "Jane") }
      let(:path) { "/employees/#{employee.id}" }

      let(:payload) do
        {
          data: {
            type: "employees",
            id: employee.id,
            attributes: {first_name: "Jane"},
            relationships: {
              location: {
                data: {
                  location_id_key => location_id, :type => "locations", :method => method
                }
              }
            }
          },
          included: [
            {
              :type => "locations",
              location_id_key => location_id,
              :attributes => {latitude: "45.12345", longitude: "24.12345"}
            }
          ]
        }
      end

      context "when creating" do
        let(:location_id) { "abc123" }
        let(:location_id_key) { :'temp-id' }
        let(:method) { "create" }

        it "works" do
          make_request
          expect(employee.reload.location.latitude).to eq("45.12345")
          expect(employee.reload.location.longitude).to eq("24.12345")
        end
      end

      context "when updating" do
        let!(:location) { Location.create(latitude: "45.12345", longitude: "24.12345") }
        let(:location_id) { location.id.to_s }
        let(:location_id_key) { :id }
        let(:method) { :update }

        it "works" do
          make_request
          expect(employee.reload.location.latitude).to eq("45.12345")
          expect(employee.reload.location.longitude).to eq("24.12345")
        end
      end

      context "when destroying" do
        let!(:location) do
          Location.create locatable_id: employee.id,
            locatable_type: "Employee"
        end
        let(:location_id) { location.id.to_s }
        let(:location_id_key) { :id }
        let(:method) { :destroy }

        it "works" do
          make_request
          expect(employee.reload.location).to be_nil
        end
      end

      context "when disassociating" do
        let!(:location) do
          Location.create locatable_id: employee.id,
            locatable_type: "Employee"
        end
        let(:location_id) { location.id.to_s }
        let(:location_id_key) { :id }
        let(:method) { :disassociate }

        it "works" do
          make_request
          expect(employee.reload.location).to be_nil
          expect { location.reload }.to_not raise_error
          expect(location.locatable_id).to be_nil
          expect(location.locatable_type).to be_nil
        end
      end
    end

    describe "nested polymorphic_has_many relationship" do
      subject(:make_request) { do_update(payload) }
      let!(:employee) { Employee.create!(first_name: "Jane") }
      let(:path) { "/employees/#{employee.id}" }

      let(:payload) do
        {
          data: {
            type: "employees",
            id: employee.id,
            attributes: {first_name: "Jane"},
            relationships: {
              notes: {
                data: [{
                  note_id_key => note_id, :type => "notes", :method => method
                }]
              }
            }
          },
          included: [
            {
              :type => "notes",
              note_id_key => note_id,
              :attributes => {body: "foo"}
            }
          ]
        }
      end

      context "when creating" do
        let(:note_id) { "abc123" }
        let(:note_id_key) { :'temp-id' }
        let(:method) { "create" }

        it "works" do
          make_request
          expect(employee.reload.notes.map(&:body)).to eq(["foo"])
        end
      end

      context "when updating" do
        let!(:note) { Note.create(body: "bar") }
        let(:note_id) { note.id.to_s }
        let(:note_id_key) { :id }
        let(:method) { :update }

        it "works" do
          make_request
          expect(employee.reload.notes.map(&:body)).to eq(["foo"])
        end
      end

      context "when destroying" do
        let!(:note) do
          Note.create notable_id: employee.id,
            notable_type: "Employee"
        end
        let(:note_id) { note.id.to_s }
        let(:note_id_key) { :id }
        let(:method) { :destroy }

        it "works" do
          expect {
            make_request
          }.to change { employee.reload.notes.count }.by(-1)
            .and change { Note.count }.by(-1)
        end
      end

      context "when disassociating" do
        let!(:note) do
          Note.create notable_id: employee.id,
            notable_type: "Employee"
        end
        let(:note_id) { note.id.to_s }
        let(:note_id_key) { :id }
        let(:method) { :disassociate }

        it "works" do
          expect {
            make_request
          }.to change { employee.reload.notes.count }.by(-1)
          expect { note.reload }.to_not raise_error
          expect(note.notable_id).to be_nil
          expect(note.notable_type).to be_nil
        end
      end
    end

    describe "nested polymorphic_belongs_to relationship" do
      let(:workspace_type) { "offices" }

      subject(:make_request) do
        do_create(payload)
      end

      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Joe"},
            relationships: {
              workspace: {
                data: {
                  'temp-id': "work1", type: workspace_type, method: "create"
                }
              }
            }
          },
          included: [
            {
              type: workspace_type,
              'temp-id': "work1",
              attributes: {
                address: "Fake Workspace Address"
              }
            }
          ]
        }
      end

      context 'with jsonapi type "offices"' do
        it "associates workspace as office" do
          make_request

          employee = Employee.first
          expect(employee.workspace).to be_a(Office)
        end
      end

      context 'with jsonapi type "home_offices"' do
        let(:workspace_type) { "home_offices" }

        it "associates workspace as home office" do
          make_request

          employee = Employee.first
          expect(employee.workspace).to be_a(HomeOffice)
        end
      end

      it "saves the relationship correctly" do
        expect {
          make_request
        }.to change { Employee.count }.by(1)
        employee = Employee.first
        workspace = employee.workspace
        expect(workspace.address).to eq("Fake Workspace Address")
      end
    end

    describe "delete nested item" do
      subject(:make_request) { do_update(payload) }

      let!(:employee) { Employee.create!(first_name: "original", positions: [position1, position2, position3]) }
      let!(:position1) { Position.create!(title: "pos1") }
      let!(:position2) { Position.create!(title: "pos2") }
      let!(:position3) { Position.create!(title: "pos3") }

      let(:path) { "/employees/#{employee.id}" }

      let(:payload) do
        {
          data: {
            id: employee.id,
            type: "employees",
            attributes: {},
            relationships: {
              positions: {
                data: [
                  {type: "positions", id: position2.id.to_s, method: "destroy"}
                ]
              }
            }
          }
        }
      end

      it "works" do
        expect(employee.positions.count).to eq(3)
        expect { make_request }.to change { employee.positions.count }.by(-1)
      end
    end
  end
end
