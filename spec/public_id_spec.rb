require "spec_helper"

RSpec.describe "public_id" do
  include_context "resource testing"
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end

      public_id :public_id
    end
  end
  let(:base_scope) { {type: :employees} }

  let!(:employee1) do
    PORO::Employee.create(first_name: "Jane", public_id: "emp-abc")
  end
  let!(:employee2) do
    PORO::Employee.create(first_name: "John", public_id: "emp-def")
  end

  describe "every id the payload exposes" do
    let!(:position) do
      PORO::Position.create(employee_id: employee1.id, title: "Engineer")
    end

    let(:position_resource) do
      employee_resource = resource
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, resource: employee_resource
      end
    end

    around do |e|
      previous = Graphiti.config.context_for_endpoint
      Graphiti.config.context_for_endpoint = ->(path, action) { double("context") }
      e.run
      Graphiti.config.context_for_endpoint = previous
    end

    it "renders the public id, never the primary key" do
      resource.has_many :positions
      params[:include] = "positions"
      render

      employee = jsonapi_data.find { |node| node.id == "emp-abc" }
      expect(employee).to be_present
      expect(jsonapi_data.map(&:id)).to_not include(employee1.id.to_s)
    end

    it "generates a related link naming the parent by public id" do
      resource.has_many :positions, resource: position_resource, link: true
      render

      expect(json["data"][0]["relationships"]["positions"]["links"]["related"])
        .to eq("/poro/positions?filter[employee_id]=emp-abc")
    end

    it "resolves the public id when a client follows that link" do
      positions = position_resource.all(filter: {employee_id: "emp-abc"})

      expect(positions.data.map(&:id)).to eq([position.id])
    end

    it "matches nothing when the link filter is given a primary key" do
      positions = position_resource.all(filter: {employee_id: employee1.id})

      expect(positions.data).to be_empty
    end

    it "still sideloads through the real foreign key" do
      resource.has_many :positions, resource: position_resource
      params[:include] = "positions"
      render

      expect(jsonapi_included("positions").map(&:rawid)).to eq([position.id.to_s])
    end

    it "translates for a subclass of the child too" do
      subclass = Class.new(position_resource) do
        def self.name
          "PORO::PositionResource"
        end
      end

      positions = subclass.all(filter: {employee_id: "emp-abc"})

      expect(positions.data.map(&:id)).to eq([position.id])
    end

    it "lets a redeclaration by a resource of the same name take over the entry" do
      other_resource = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end

        public_id :public_id
      end
      other_resource.has_many :positions, resource: position_resource, link: true
      resource.has_many :positions, resource: position_resource, link: true

      expect(other_resource.sideload(:positions).link?).to eq(false)
      expect(resource.sideload(:positions).link?).to eq(true)
    end

    it "raises when a differently named parent claims the same child filter" do
      other_resource = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::ManagerResource"
        end

        self.model = PORO::Employee
        public_id :public_id
      end
      resource.has_many :positions, resource: position_resource

      expect {
        other_resource.has_many :positions, resource: position_resource
      }.to raise_error(Graphiti::Errors::ConflictingPublicIdSource, /employee_id.*PORO::EmployeeResource.*PORO::ManagerResource/)
    end

    it "waits for the parent's model before claiming the child filter" do
      other_resource = Class.new(PORO::ApplicationResource) do
        def self.name
          "PORO::ManagerResource"
        end

        public_id :public_id
      end
      resource.has_many :positions, resource: position_resource
      other_resource.has_many :positions, resource: position_resource

      expect {
        other_resource.model = PORO::Employee
      }.to raise_error(Graphiti::Errors::ConflictingPublicIdSource, /employee_id.*PORO::EmployeeResource.*PORO::ManagerResource/)
    end

    it "links an unpaired has_many, whose child declares no belongs_to back" do
      resource.has_many :positions, link: true
      render

      expect(json["data"][0]["relationships"]["positions"]["links"]["related"])
        .to eq("/poro/positions?filter[employee_id]=emp-abc")
      expect(PORO::PositionResource.all(filter: {employee_id: "emp-abc"}).data.map(&:id)).to eq([position.id])
    end

    it "resolves for a subclass of an unpaired child" do
      resource.has_many :positions
      subclass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::SeniorPositionResource"
        end

        self.model = PORO::Position
      end

      positions = subclass.all(filter: {employee_id: "emp-abc"})

      expect(positions.data.map(&:id)).to eq([position.id])
    end

    it "types a generated many_to_many filter like the public id, which is what clients send it" do
      team_resource = Class.new(PORO::TeamResource) do
        def self.name
          "PORO::TeamResource"
        end
      end
      resource.many_to_many :teams,
        resource: team_resource,
        foreign_key: {employee_teams: :owner_id}

      expect(team_resource.filters[:owner_id][:type]).to eq(:string)
      expect(team_resource.public_id_source_for(:owner_id)).to eq(resource)
    end

    it "still honours a link block, which can use the public id" do
      resource.has_many :positions do
        link { |employee| "/employees/#{employee.public_id}/positions" }
      end
      render

      expect(json["data"][0]["relationships"]["positions"]["links"]["related"])
        .to eq("/employees/emp-abc/positions")
    end

    it "leaves a belongs_to linkable, since that link carries the target's id" do
      classification = PORO::Classification.create(description: "Engineering")
      employee1.update_attributes(classification_id: classification.id)
      resource.belongs_to :classification, link: true
      render

      relationship = json["data"][0]["relationships"]["classification"]
      expect(relationship["links"]["related"]).to include(classification.id.to_s)
    end

    it "leaves relationships keyed on something else linkable" do
      resource.has_many :positions, primary_key: :first_name, foreign_key: :title, link: true
      render

      relationship = json["data"][0]["relationships"]["positions"]
      expect(relationship["links"]["related"]).to include("filter[title]=Jane")
    end

    describe "a custom block on the child's foreign key filter" do
      let(:seen) { [] }

      it "receives the value as the client sent it" do
        seen_ref = seen
        position_resource.filter :employee_id, :string do
          eq { |scope, value|
            seen_ref << value
            scope
          }
        end

        position_resource.all(filter: {employee_id: "emp-abc"}).data

        expect(seen).to eq([["emp-abc"]])
      end

      it "gets the decoded value when it takes primary_keys:" do
        seen_ref = seen
        position_resource.filter :employee_id, :string do
          eq { |scope, value, primary_keys:|
            seen_ref << [value, primary_keys]
            scope
          }
        end

        position_resource.all(filter: {employee_id: "emp-abc,emp-def"}).data

        expect(seen).to eq([[%w[emp-abc emp-def], [employee1.id, employee2.id]]])
      end

      it "gets the value itself as primary_keys: when the parent has no public id" do
        seen_ref = seen
        plain_positions = Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          filter :employee_id, :integer do
            eq { |scope, value, primary_keys:|
              seen_ref << [value, primary_keys]
              scope
            }
          end
        end
        expect(PORO::EmployeeResource).to_not receive(:translate_ids)

        plain_positions.all(filter: {employee_id: employee1.id}).data

        expect(seen).to eq([[[employee1.id], [employee1.id]]])
      end

      it "still receives the real key from a sideload, and as primary_keys: too" do
        seen_ref = seen
        position_resource.filter :employee_id, :integer do
          eq { |scope, value, primary_keys:|
            seen_ref << [value, primary_keys]
            scope
          }
        end
        resource.has_many :positions, resource: position_resource
        params[:include] = "positions"
        render

        expect(seen).to eq([[[employee1.id, employee2.id], [employee1.id, employee2.id]]])
      end

      it "suppresses the parent's link when the block does not take primary_keys:, and the audit says so" do
        position_resource.filter :employee_id, :string do
          eq { |scope, value| scope }
        end
        resource.has_many :positions, resource: position_resource, link: true
        render

        expect(json["data"][0]["relationships"]).to_not have_key("positions")
        finding = Graphiti::Audit.findings([resource]).find { |candidate| candidate.check == :link_hidden }
        expect(finding.remedy).to include("take `primary_keys:`")
      end

      it "keeps the parent's link when the block takes primary_keys:" do
        position_resource.filter :employee_id, :string do
          eq { |scope, value, primary_keys:| scope }
        end
        resource.has_many :positions, resource: position_resource, link: true
        render

        expect(json["data"][0]["relationships"]["positions"]["links"]["related"])
          .to eq("/poro/positions?filter[employee_id]=emp-abc")
      end

      it "leaves the generated many_to_many filter taking primary keys" do
        team_resource = Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end
        end
        resource.many_to_many :teams, resource: team_resource, foreign_key: {employee_teams: :owner_id}

        expect(team_resource.filter_accepts_public_ids?(:owner_id)).to eq(true)
      end
    end

    it "translates without gathering foreign keys for the target's own relationships" do
      resource.sideloads.each_value { |sideload| expect(sideload).to_not receive(:collect_foreign_keys) }

      positions = position_resource.all(filter: {employee_id: "emp-abc"})

      expect(positions.data.map(&:id)).to eq([position.id])
    end

    describe "writing the parent's key" do
      around do |example|
        Graphiti.with_context({}, :create) { example.run }
      end

      before do
        position_resource.attribute :employee_id, :integer, readable: false
      end

      it "decodes a public id posted as a foreign key attribute" do
        proxy = position_resource.build(data: {type: "positions", attributes: {title: "Lead", employee_id: "emp-def"}})

        expect(proxy.save).to eq(true)
        expect(proxy.data.employee_id).to eq(employee2.id)
      end

      it "rejects a foreign key that names no record" do
        proxy = position_resource.build(data: {type: "positions", attributes: {title: "Lead", employee_id: employee2.id}})

        expect { proxy.save }.to raise_error(Graphiti::Errors::RecordNotFound, /'employees' with id '#{employee2.id}'.*employee_id/)
      end

      it "decodes a foreign key typed as the target's id, not the key's" do
        position_resource.attribute :employee_id, :integer, readable: false
        proxy = position_resource.build(data: {type: "positions", attributes: {title: "Lead", employee_id: "emp-def"}})

        expect(proxy.save).to eq(true)
        expect(proxy.data.employee_id).to eq(employee2.id)
      end

      it "resolves a relationship reference by public id" do
        payload = {
          data: {
            type: "positions",
            attributes: {title: "Lead"},
            relationships: {employee: {data: {type: "employees", id: "emp-def"}}}
          }
        }
        proxy = position_resource.build(payload)

        expect(proxy.save).to eq(true)
        expect(proxy.data.employee_id).to eq(employee2.id)
      end

      it "destroys a parent referenced by public id" do
        position = PORO::Position.create(title: "Lead", employee_id: employee2.id)
        payload = {
          data: {
            type: "positions",
            id: position.id.to_s,
            relationships: {employee: {data: {type: "employees", id: "emp-def", method: "destroy"}}}
          }
        }
        proxy = Graphiti.with_context({}, :update) { position_resource.find(payload) }

        expect(proxy.update_attributes).to eq(true)
        expect(proxy.data.employee_id).to be_nil
        expect(PORO::DB.data[:employees].map { |employee| employee[:public_id] }).not_to include("emp-def")
      end
    end

    describe "a readable attribute holding the parent's primary key" do
      it "raises when the has_many is declared after it" do
        unpaired_resource = Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          attribute :employee_id, :integer
        end

        expect {
          resource.has_many :positions, resource: unpaired_resource
        }.to raise_error(Graphiti::Errors::PublicIdLeak, /PORO::PositionResource: attribute :employee_id.*PORO::EmployeeResource/)
      end

      it "raises when it is declared after the has_many" do
        resource.has_many :positions, resource: position_resource

        expect {
          position_resource.attribute :employee_id, :integer
        }.to raise_error(Graphiti::Errors::PublicIdLeak)
      end

      it "raises when only the child's belongs_to names the parent" do
        expect {
          position_resource.attribute :employee_id, :integer
        }.to raise_error(Graphiti::Errors::PublicIdLeak)
      end

      it "raises when the belongs_to is declared after it" do
        employee_resource = resource

        expect {
          Class.new(PORO::PositionResource) do
            def self.name
              "PORO::PositionResource"
            end

            attribute :employee_id, :integer
            belongs_to :employee, resource: employee_resource
          end
        }.to raise_error(Graphiti::Errors::PublicIdLeak)
      end

      it "waits for the model when the belongs_to is declared before it" do
        employee_resource = resource
        anonymous = Class.new(PORO::ApplicationResource) do
          attribute :employee_id, :integer
          belongs_to :employee, resource: employee_resource
        end

        expect { anonymous.model = PORO::Position }.to raise_error(Graphiti::Errors::PublicIdLeak)
      end

      it "allows the key as a filter-only attribute" do
        position_resource.attribute :employee_id, :integer, only: [:filterable]

        expect {
          resource.has_many :positions, resource: position_resource
        }.to_not raise_error
      end

      it "queries a string-rendered key by its decoded integer, not as a string" do
        recording = Class.new(PORO::Adapter) do
          def self.calls
            @calls ||= []
          end

          def filter_integer_eq(scope, attribute, value)
            self.class.calls << [attribute, value]
            filter(scope, attribute, value)
          end
        end
        position_resource.adapter = recording
        position_resource.attribute :employee_id, :string do
          "emp-#{@object.employee_id}"
        end
        resource.has_many :positions, resource: position_resource

        position_resource.all(filter: {employee_id: "emp-def"}).data

        expect(recording.calls).to eq([[:employee_id, [employee2.id.to_s]]])
      end

      it "allows a readable key with a block, since the block decides what it renders" do
        position_resource.attribute :employee_id, :string do
          "emp-#{@object.employee_id}"
        end

        expect {
          resource.has_many :positions, resource: position_resource
        }.to_not raise_error
      end
    end
  end

  describe "declared on an abstract resource" do
    let(:public_base) do
      Class.new(PORO::ApplicationResource) do
        def self.name
          "PublicApplicationResource"
        end

        self.abstract_class = true
        public_id :public_id
      end
    end

    let(:resource) do
      Class.new(public_base) do
        def self.name
          "PORO::EmployeeResource"
        end

        self.model = PORO::Employee
        self.type = :employees
      end
    end

    it "carries the remap down to every subclass" do
      render

      expect(jsonapi_data.map(&:rawid)).to eq(%w[emp-abc emp-def])
      expect(resource.config[:public_id]).to eq(:public_id)
      expect(resource.config[:attributes][:id][:type]).to eq(:string)
    end

    it "filters and sorts through it too" do
      expect(resource.all(filter: {id: "emp-def"}).data.map(&:id))
        .to eq([employee2.id])
      expect(resource.all(sort: "-id").data.map(&:id))
        .to eq([employee2.id, employee1.id])
    end
  end

  describe "the public id type" do
    def model_with_column(column_type)
      Class.new do
        define_singleton_method(:primary_key) { "id" }
        define_singleton_method(:type_for_attribute) { |_name| Struct.new(:type).new(column_type) }
      end
    end

    it "is a string when the model cannot answer" do
      expect(resource.attributes[:id][:type]).to eq(:string)
    end

    it "reads the column type off the model" do
      model = model_with_column(:integer)
      resource = Class.new(PORO::ApplicationResource) do
        self.model = model
        public_id :code
      end

      expect(resource.attributes[:id][:type]).to eq(:integer)
    end

    it "lets an explicit type win" do
      model = model_with_column(:integer)
      resource = Class.new(PORO::ApplicationResource) do
        self.model = model
        public_id :code, :string
      end

      expect(resource.attributes[:id][:type]).to eq(:string)
    end

    it "reads the column once a model assigned after the declaration is known" do
      resource = Class.new(PORO::ApplicationResource) { public_id :code }
      resource.model = model_with_column(:uuid)

      expect(resource.attributes[:id][:type]).to eq(:uuid)
    end

    it "never casts what reaches the hidden primary key filter" do
      params[:filter] = {_primary_key: Graphiti::Util::InternalParam.new(["not-an-integer"])}
      expect(records).to eq([])
    end
  end

  describe "serialization" do
    it "renders the public id as the jsonapi id" do
      render
      expect(jsonapi_data.map(&:rawid)).to eq(%w[emp-abc emp-def])
    end

    it "survives a later attribute :id declaration" do
      resource.attribute :id, :string
      render
      expect(jsonapi_data.map(&:rawid)).to eq(%w[emp-abc emp-def])
    end
  end

  describe "filtering on id" do
    it "queries the public id attribute" do
      params[:filter] = {id: "emp-def"}
      expect(records.map(&:first_name)).to eq(["John"])
    end

    it "goes through the adapter's public id comparison, which is exact where the adapter can be" do
      exact = Class.new(PORO::Adapter) do
        def self.calls
          @calls ||= []
        end

        def filter_public_id_eq(scope, attribute, value)
          self.class.calls << [attribute, value]
          filter_string_eq(scope, attribute, value)
        end
      end
      resource.adapter = exact
      params[:filter] = {id: "emp-def"}

      expect(records.map(&:first_name)).to eq(["John"])
      expect(exact.calls).to eq([[:public_id, ["emp-def"]]])
    end

    it "hands a custom id filter the primary keys when it asks" do
      resource.filter :id, :string do
        eq { |scope, value, primary_keys:| scope.merge(conditions: {id: primary_keys.first}) }
      end
      params[:filter] = {id: "emp-def"}
      expect(records.map(&:first_name)).to eq(["John"])
    end

    it "lets a custom id filter decode through the resource without recursing" do
      klass = resource
      resource.filter :id, :string do
        eq { |scope, value| scope.merge(conditions: {id: klass.decode_public_id(value.first)}) }
      end
      params[:filter] = {id: "emp-def"}
      expect(records.map(&:first_name)).to eq(["John"])
    end

    it "accepts several public ids" do
      params[:filter] = {id: "emp-abc,emp-def"}
      expect(records.map(&:first_name)).to match_array(%w[Jane John])
    end
  end

  describe "sorting on id" do
    it "sorts by the public id attribute" do
      params[:sort] = "-id"
      expect(records.map(&:public_id)).to eq(%w[emp-def emp-abc])
    end
  end

  describe "the hidden :_primary_key filter" do
    it "rejects values from request params" do
      params[:filter] = {_primary_key: employee2.id}
      expect { records }.to raise_error(Graphiti::Errors::InvalidAttributeAccess)
    end

    it "accepts values wrapped by graphiti itself" do
      params[:filter] = {_primary_key: Graphiti::Util::InternalParam.new([employee2.id])}
      expect(records.map(&:first_name)).to eq(["John"])
    end

    it "is excluded from the schema" do
      previous = Graphiti.config.context_for_endpoint
      Graphiti.config.context_for_endpoint = ->(path, action) {
        double("context", sideload_allowlist: nil)
      }
      schema = Graphiti::Schema.generate([resource])
      employee_schema = schema[:resources].find { |r| r[:name] == "PORO::EmployeeResource" }
      expect(employee_schema[:filters]).to_not have_key(:_primary_key)
      expect(employee_schema[:attributes]).to_not have_key(:_primary_key)
    ensure
      Graphiti.config.context_for_endpoint = previous
    end
  end

  describe "persistence" do
    around do |example|
      Graphiti.with_context({}, :create) do
        example.run
      end
    end

    it "keeps a linked parent on a model that was assigned before save" do
      employees = resource
      positions = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, resource: employees
      end
      proxy = positions.build(
        data: {
          type: "positions",
          attributes: {title: "Engineer"},
          relationships: {employee: {data: {type: "employees", id: "emp-def"}}}
        }
      )
      proxy.data

      expect(proxy.save).to eq(true)
      expect(proxy.data.employee_id).to eq(employee2.id)
    end

    describe "updating by public id" do
      let(:payload) do
        {
          data: {
            type: "employees",
            id: "emp-def",
            attributes: {first_name: "Johnny"}
          }
        }
      end

      it "finds the record via the public id" do
        proxy = resource.find(payload)
        expect(proxy.update_attributes).to eq(true)
        expect(PORO::Employee.find(employee2.id).first_name).to eq("Johnny")
      end
    end

    describe "destroying by public id" do
      it "finds the record via the public id" do
        proxy = resource.find(id: "emp-def")
        expect(proxy.destroy).to eq(true)
        expect(PORO::Employee.find(employee2.id)).to be_nil
      end
    end

    describe "creating with a client-supplied id" do
      let(:payload) do
        {
          data: {
            type: "employees",
            id: "emp-xyz",
            attributes: {first_name: "Jake"}
          }
        }
      end

      it "assigns the public id attribute, not the primary key" do
        proxy = resource.build(payload)
        expect(proxy.save).to eq(true)
        expect(proxy.data.public_id).to eq("emp-xyz")
        expect(proxy.data.id).to_not eq("emp-xyz")
      end
    end
  end

  describe "belongs_to sideload of a remapped resource" do
    let(:department_resource) do
      Class.new(PORO::DepartmentResource) do
        def self.name
          "PORO::DepartmentResource"
        end

        public_id :public_id
      end
    end

    let(:resource) do
      department_resource_class = department_resource
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :department, resource: department_resource_class, link: true
      end
    end
    let(:base_scope) { {type: :positions} }

    let!(:department) do
      PORO::Department.create(name: "Engineering", public_id: "dep-abc")
    end
    let!(:position) do
      PORO::Position.create(title: "Developer", department_id: department.id)
    end

    it "loads via the real primary key and renders the public id" do
      params[:include] = "department"
      render
      expect(jsonapi_included("departments").map(&:rawid)).to eq(["dep-abc"])
      expect(jsonapi_data[0].sideload(:department).rawid).to eq("dep-abc")
    end

    it "links to the target by public id, not the foreign key" do
      render

      expect(jsonapi_data[0].relationships["department"]["links"]["related"])
        .to eq("/poro/departments/dep-abc")
    end

    it "renders the public id as linkage without loading the association" do
      render

      expect(jsonapi_data[0].relationships["department"]["data"])
        .to eq({"type" => "departments", "id" => "dep-abc"})
      expect(json).to_not have_key("included")
    end

    it "renders neither linkage nor a link when the foreign key no longer resolves" do
      position.update_attributes(department_id: 999)
      render

      expect(jsonapi_data[0].relationships["department"])
        .to eq({"data" => nil, "links" => {"related" => nil}})
    end

    context "on a sideloaded resource" do
      let(:employee_resource) do
        position_resource = resource
        Class.new(PORO::EmployeeResource) do
          def self.name
            "PORO::EmployeeResource"
          end

          has_many :positions, resource: position_resource
        end
      end
      let!(:employee) { PORO::Employee.create(first_name: "Jane") }

      before do
        position.update_attributes(employee_id: employee.id)
      end

      it "resolves the sideloaded records' foreign keys, not the top-level ones" do
        json = JSON.parse(employee_resource.all(include: "positions").to_jsonapi)

        expect(json["included"][0]["relationships"]["department"]["data"])
          .to eq({"type" => "departments", "id" => "dep-abc"})
      end

      it "resolves a nested record's key that no top-level record carries" do
        employee_resource_class = employee_resource
        resource.belongs_to :employee, resource: employee_resource_class
        other_department = PORO::Department.create(name: "Sales", public_id: "dep-def")
        other_position = PORO::Position.create(
          title: "Seller",
          employee_id: employee.id,
          department_id: other_department.id
        )
        params[:filter] = {id: position.id}
        params[:include] = "employee.positions"
        render

        nested = jsonapi_included("positions").find { |node| node.rawid == other_position.id.to_s }
        expect(nested.relationships["department"]["data"])
          .to eq({"type" => "departments", "id" => "dep-def"})
      end
    end

    it "resolves more foreign keys than one page of the target holds" do
      25.times do |index|
        other_department = PORO::Department.create(name: "D#{index}", public_id: "dep-#{index}")
        PORO::Position.create(title: "P#{index}", department_id: other_department.id)
      end
      params[:page] = {size: 30}
      render

      ids = jsonapi_data.map { |node| node.relationships["department"]["data"]&.dig("id") }
      expect(ids).to_not include(nil)
      expect(ids.uniq.size).to eq(26)
    end

    it "resolves through a target with a required filter" do
      department_resource.filter :name, :string, required: true
      render

      expect(jsonapi_data[0].relationships["department"]["data"])
        .to eq({"type" => "departments", "id" => "dep-abc"})
    end

    it "resolves through a target whose default filter hides the row" do
      department_resource.default_filter :name do |scope|
        scope[:conditions][:name] = "Nothing"
        scope
      end
      render

      expect(jsonapi_data[0].relationships["department"]["data"])
        .to eq({"type" => "departments", "id" => "dep-abc"})
    end
  end

  describe "declared with a block" do
    let(:resource) do
      Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end

        public_id do
          encode { |primary_key| "enc-#{primary_key}" }
          decode { |public_id| public_id[/\Aenc-(\d+)\z/, 1]&.to_i }
        end
      end
    end

    let(:position_resource) do
      employee_resource = resource
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, resource: employee_resource
      end
    end

    let!(:position) do
      PORO::Position.create(employee_id: employee1.id, title: "Engineer")
    end

    around do |e|
      previous = Graphiti.config.context_for_endpoint
      Graphiti.config.context_for_endpoint = ->(path, action) { double("context", sideload_allowlist: nil) }
      e.run
      Graphiti.config.context_for_endpoint = previous
    end

    it "renders the encoded primary key as the jsonapi id" do
      render
      expect(jsonapi_data.map(&:rawid)).to eq(["enc-#{employee1.id}", "enc-#{employee2.id}"])
    end

    it "decodes filter[id]" do
      params[:filter] = {id: "enc-#{employee2.id}"}
      expect(records.map(&:first_name)).to eq(["John"])
    end

    it "matches nothing when filter[id] does not decode" do
      params[:filter] = {id: employee2.id}
      expect(records).to be_empty
    end

    it "matches nothing when a decoded id does not encode back to what was sent" do
      resource.config[:public_id_decode] = ->(public_id) { public_id.to_i }
      params[:filter] = {id: employee2.id.to_s}
      expect(records).to be_empty
    end

    it "sorts by the primary key" do
      params[:sort] = "-id"
      expect(records.map(&:id)).to eq([employee2.id, employee1.id])
    end

    it "updates and destroys by encoded id" do
      Graphiti.with_context({}, :update) do
        proxy = resource.find(data: {type: "employees", id: "enc-#{employee2.id}", attributes: {first_name: "Johnny"}})
        expect(proxy.update_attributes).to eq(true)
      end
      expect(PORO::Employee.find(employee2.id).first_name).to eq("Johnny")

      Graphiti.with_context({}, :destroy) do
        expect(resource.find(id: "enc-#{employee2.id}").destroy).to eq(true)
      end
      expect(PORO::Employee.find(employee2.id)).to be_nil
    end

    it "decodes a client-supplied id on create into the primary key" do
      Graphiti.with_context({}, :create) do
        proxy = resource.build(data: {type: "employees", id: "enc-900", attributes: {first_name: "Jake"}})
        expect(proxy.save).to eq(true)
        expect(proxy.data.id).to eq(900)
      end
    end

    it "rejects a create whose id does not decode, rather than dropping it" do
      Graphiti.with_context({}, :create) do
        proxy = resource.build(data: {type: "employees", id: employee1.id.to_s, attributes: {first_name: "Jake"}})

        expect { proxy.save }.to raise_error(Graphiti::Errors::ConflictRequest, /data.id does not name a record/)
      end
    end

    it "links a has_many by encoded id and decodes it on the way back" do
      resource.has_many :positions, resource: position_resource, link: true
      render

      expect(json["data"][0]["relationships"]["positions"]["links"]["related"])
        .to eq("/poro/positions?filter[employee_id]=enc-#{employee1.id}")
      expect(position_resource.all(filter: {employee_id: "enc-#{employee1.id}"}).data.map(&:id)).to eq([position.id])
      expect(position_resource.all(filter: {employee_id: employee1.id}).data).to be_empty
    end

    it "renders belongs_to linkage and link by encoded id without a query" do
      expect(resource).to_not receive(:translate_ids)
      position_resource.sideload(:employee).instance_variable_set(:@link, true)
      json = JSON.parse(position_resource.all(resource_ids: true).to_jsonapi)

      relationship = json["data"][0]["relationships"]["employee"]
      expect(relationship["data"]).to eq("type" => "employees", "id" => "enc-#{employee1.id}")
      expect(relationship["links"]["related"]).to eq("/poro/employees/enc-#{employee1.id}")
    end

    it "still guards a readable foreign key attribute" do
      expect {
        position_resource.attribute :employee_id, :integer
      }.to raise_error(Graphiti::Errors::PublicIdLeak)
    end

    it "records itself in the schema as true" do
      schema = Graphiti::Schema.generate([resource])
      expect(schema[:resources][0][:public_id]).to eq(true)
    end

    it "rejects a column name and a block together" do
      expect {
        Class.new(PORO::EmployeeResource) do
          public_id :public_id do
            encode { |primary_key| primary_key }
            decode { |public_id| public_id }
          end
        end
      }.to raise_error(Graphiti::Errors::InvalidPublicId, /not both/)
    end

    it "rejects a block missing decode" do
      expect {
        Class.new(PORO::EmployeeResource) do
          public_id do
            encode { |primary_key| primary_key }
          end
        end
      }.to raise_error(Graphiti::Errors::InvalidPublicId, /both encode and decode/)
    end

    it "rejects a declaration with neither" do
      expect {
        Class.new(PORO::EmployeeResource) { public_id }
      }.to raise_error(Graphiti::Errors::InvalidPublicId, /needs a column name or a block/)
    end
  end

  describe "one publishing resource among plain ones" do
    let(:resource) do
      Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end
      end
    end

    let(:position_resource) do
      employee_resource = resource
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        public_id do
          encode { |primary_key| "pos-#{primary_key}" }
          decode { |public_id| public_id[/\Apos-(\d+)\z/, 1]&.to_i }
        end

        belongs_to :employee, resource: employee_resource, link: true
      end
    end

    let!(:position) { PORO::Position.create(employee_id: employee1.id, title: "Engineer") }

    around do |e|
      previous = Graphiti.config.context_for_endpoint
      Graphiti.config.context_for_endpoint = ->(path, action) { double("context", sideload_allowlist: nil) }
      e.run
      Graphiti.config.context_for_endpoint = previous
    end

    before do
      resource.has_many :positions, resource: position_resource, link: true
    end

    it "leaves the plain parent's ids and links alone" do
      render

      expect(jsonapi_data.map(&:rawid)).to eq([employee1.id.to_s, employee2.id.to_s])
      expect(json["data"][0]["relationships"]["positions"]["links"]["related"])
        .to eq("/poro/positions?filter[employee_id]=#{employee1.id}")
    end

    it "sideloads the publishing child and renders its ids encoded" do
      params[:include] = "positions"
      render

      expect(jsonapi_included("positions").map(&:rawid)).to eq(["pos-#{position.id}"])
    end

    it "nests back through the child to the plain parent" do
      params[:include] = "positions.employee"
      render

      included_position = json["included"].find { |node| node["type"] == "positions" }
      expect(included_position["id"]).to eq("pos-#{position.id}")
      expect(included_position["relationships"]["employee"]["data"]).to eq("type" => "employees", "id" => employee1.id.to_s)
    end

    it "names the plain parent by primary key in the child's belongs_to" do
      json = JSON.parse(position_resource.all(resource_ids: true).to_jsonapi)

      relationship = json["data"][0]["relationships"]["employee"]
      expect(relationship["data"]).to eq("type" => "employees", "id" => employee1.id.to_s)
      expect(relationship["links"]["related"]).to eq("/poro/employees/#{employee1.id}")
    end

    it "finds the child by encoded id and its parent by primary key" do
      json = JSON.parse(position_resource.find(id: "pos-#{position.id}", include: "employee").to_jsonapi)

      expect(json["data"]["id"]).to eq("pos-#{position.id}")
      expect(json["included"][0]["id"]).to eq(employee1.id.to_s)
    end
  end
end
