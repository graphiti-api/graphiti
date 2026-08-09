require "spec_helper"

RSpec.describe Graphiti::Audit do
  def audit(resource_class)
    described_class.findings([resource_class])
  end

  def finding(resource_class, check)
    audit(resource_class).find { |f| f.check == check }
  end

  describe "missing association method" do
    let(:resource) do
      Class.new(PORO::TeamResource) do
        def self.name
          "PORO::TeamResource"
        end

        has_many :employees
      end
    end

    it "reports the resource, the relationship and the model" do
      row = described_class.run([resource]).find { |r| r.relationship == :employees }

      expect(row.resource).to eq("PORO::TeamResource")
      expect(row.type).to eq(:has_many)
      expect(row.resource_ids_source).to eq(:none)
      expect(row.severity).to eq(:error)
      expect(row.findings.first.message).to eq("PORO::Team has no #employees method")
    end

    it "accepts a private method, since rendering only needs it to exist" do
      PORO::Team.class_eval { private def employees() = [] }

      expect(finding(resource, :missing_association_method)).to be_nil
    ensure
      PORO::Team.send(:remove_method, :employees)
    end

    it "follows `as:` rather than the relationship name" do
      klass = Class.new(PORO::TeamResource) do
        def self.name
          "PORO::TeamResource"
        end

        has_many :staff, as: :employees, resource: PORO::EmployeeResource
      end

      expect(finding(klass, :missing_association_method).message)
        .to eq("PORO::Team has no #employees method")
    end
  end

  describe "missing guard method" do
    it "reports a readable guard defined on neither resource" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, readable: :nobody_defines_this?
      end

      found = finding(klass, :missing_guard_method)

      expect(found.severity).to eq(:error)
      expect(found.message).to match(/#nobody_defines_this\? is defined on neither/)
    end

    it "accepts a guard defined on the declaring resource" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, readable: :admin?

        def admin?
          true
        end
      end

      expect(finding(klass, :missing_guard_method)).to be_nil
    end

    it "ignores a proc guard, which has no name to look up" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, readable: -> { true }
      end

      expect(finding(klass, :missing_guard_method)).to be_nil
    end
  end

  describe "rendering ids by loading" do
    def row_for(resource_class)
      described_class.run([resource_class]).find { |row| row.relationship == :employee }
    end

    it "reports :load without a finding, since opting in is a choice, not a defect" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, resource_ids: true do
          scope { |ids| {type: :employees, conditions: {id: ids}} }
        end
      end

      row = row_for(klass)

      expect(row.resource_ids_source).to eq(:load)
      expect(row.findings).to eq([])
    end

    describe "whether base_scope preloads the loaded association" do
      let(:scope_class) { Struct.new(:includes_values, :preload_values, :eager_load_values) }

      def loading_resource(base_scope)
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          define_method(:base_scope) { base_scope }

          belongs_to :employee, resource_ids: true do
            scope { |ids| {type: :employees, conditions: {id: ids}} }
          end
        end
      end

      it "sees a preload, including a nested one" do
        row = row_for(loading_resource(scope_class.new([{employee: :department}], [], [])))

        expect(row.preloaded).to eq(true)
      end

      it "sees a missing preload" do
        row = row_for(loading_resource(scope_class.new([:other], [], [])))

        expect(row.preloaded).to eq(false)
      end

      it "answers nil for a scope with no preload lists to read" do
        row = row_for(loading_resource({type: :positions}))

        expect(row.preloaded).to be_nil
      end
    end

    it "reports :load under an API-wide :always" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        self.belongs_to_resource_ids_by_default = :always

        belongs_to :employee, primary_key: :first_name
      end

      expect(row_for(klass).resource_ids_source).to eq(:load)
    end

    it "reports :key for a relationship reading ids off the foreign key" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee
      end

      expect(row_for(klass).resource_ids_source).to eq(:key)
    end

    it "notes nothing under :never, which asked for exactly this" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        self.belongs_to_resource_ids_by_default = :never

        belongs_to :employee do
          scope { |ids| {type: :employees, conditions: {id: ids}} }
        end
      end

      row = row_for(klass)

      expect(row.resource_ids_source).to eq(:none)
      expect(row.would_start_loading?).to eq(false)
    end

    it "reports :none for a relationship rendering no ids at all" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee do
          scope { |ids| {type: :employees, conditions: {id: ids}} }
        end
      end

      expect(row_for(klass).resource_ids_source).to eq(:none)
    end
  end

  describe "a relationship that raises while being inspected" do
    let(:resource) do
      Class.new(PORO::PositionResource) do
        def self.name
          "NotNamespacedResource"
        end

        belongs_to :employee
      end
    end

    it "reports it rather than taking the whole report down" do
      rows = described_class.run([resource])
      row = rows.find { |r| r.relationship == :employee }

      expect(row.severity).to eq(:error)
      expect(row.findings.first.check).to eq(:broken_relationship)
      expect(row.findings.first.message)
        .to match(/Could not find resource class for sideload 'employee'/)
    end

    it "still reports the resource's other relationships" do
      expect(described_class.run([resource]).map(&:relationship)).to include(:department)
    end
  end

  describe "a clean resource" do
    it "reports nothing" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee
      end

      expect(audit(klass)).to eq([])
    end
  end
end

RSpec.describe Graphiti::Audit::Report do
  let(:rows) do
    klass = Class.new(PORO::PositionResource) do
      def self.name
        "PORO::PositionResource"
      end

      belongs_to :employee
    end

    Graphiti::Audit.run([klass])
  end

  describe "a relationship loading to render ids" do
    def output_for(base_scope)
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        define_method(:base_scope) { base_scope }

        belongs_to :employee, resource_ids: true do
          scope { |ids| {type: :employees, conditions: {id: ids}} }
        end
      end

      described_class.new(Graphiti::Audit.run([klass]), color: false).to_s
    end

    let(:scope_class) { Struct.new(:includes_values, :preload_values, :eager_load_values) }

    it "warns when base_scope does not preload the association" do
      output = output_for(scope_class.new([], [], []))

      expect(output).to include("WARNING rendering resource ids by loading an association the base_scope does not preload")
      expect(output).to include("fix: preload the association in base_scope, or drop `resource_ids`")
      expect(output).to include("1 loading ids without preloading")
    end

    it "says nothing when base_scope preloads it" do
      output = output_for(scope_class.new([:employee], [], []))

      expect(output).to_not include("WARNING")
      expect(output).to include("✓ all id-rendering loads preloaded")
      expect(output).to_not include("(none)")
    end

    it "drops the check when nothing loads to render ids" do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        self.belongs_to_resource_ids_by_default = :never

        belongs_to :employee
      end

      output = described_class.new(Graphiti::Audit.run([klass]), color: false).to_s

      expect(output).to_not include("id-rendering loads")
    end

    it "says nothing when the scope cannot be inspected" do
      expect(output_for({type: :positions})).to_not include("WARNING")
    end
  end

  it "lists every check, with a count for the failed ones" do
    output = described_class.new(rows, color: false).to_s

    expect(output).to include("checks")
    expect(output).to include("✓ all association methods defined")
    expect(output).to include("✓ all sideload filters declared")
  end

  it "marks a failed check with a red x and the count" do
    klass = Class.new(PORO::TeamResource) do
      def self.name
        "PORO::TeamResource"
      end

      has_many :employees
    end

    output = described_class.new(Graphiti::Audit.run([klass]), color: false).to_s

    expect(output).to include("✗ 1 association method missing")
    expect(output).to include("✗ 1 sideload filter missing")
  end

  it "shows only the passed checks when there is nothing wrong" do
    output = described_class.new(rows, color: false).to_s

    expect(output).to_not include("ERROR")
    expect(output).to_not include("FYI")
    expect(output.scan(/^  ✓ /).size).to eq(Graphiti::Audit::Report::CHECKLIST.size - 1)
    expect(output).to_not include("✗")
  end

  it "repeats back the options that differ from the defaults" do
    klass = Class.new(PORO::PositionResource) do
      def self.name
        "PORO::PositionResource"
      end

      belongs_to :employee, primary_key: :first_name, single: true, link: false
    end

    output = described_class.new(Graphiti::Audit.run([klass]), color: false).to_s

    expect(output).to include("belongs_to :employee, primary_key: :first_name, single: true, link: false")
  end

  it "summarises" do
    output = described_class.new(rows, color: false).to_s

    expect(output).to match(/1 resource, \d+ relationships, 0 errors/)
  end

  it "says so when there is nothing to report" do
    expect(described_class.new([]).to_s).to eq("graphiti: no relationships found.\n")
  end

  describe "the :always column" do
    let(:rows) do
      klass = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee do
          scope { |ids| {type: :employees, conditions: {id: ids}} }
        end
      end

      Graphiti::Audit.run([klass])
    end

    let(:row) { rows.find { |r| r.relationship == :employee } }

    it "shows what a relationship would cost without changing what it does now" do
      expect(row.resource_ids_source).to eq(:none)
      expect(row.resource_ids_source_if_always).to eq(:load)
      expect(row.would_start_loading?).to eq(true)
    end

    it "leaves the resource's own setting untouched" do
      rows

      expect(PORO::PositionResource.belongs_to_resource_ids_by_default).to eq(:foreign_key)
    end

    it "shows which relationships would start loading, and why" do
      output = described_class.new(rows, color: false).to_s

      expect(output).to include("1 belongs_to relationship renders no resource ids")
      expect(output).to include("To render ids on every response, opt in:")
      expect(output).to match(/^    resource_ids: true\s+on one relationship$/)
      expect(output).to match(/^  PORO::PositionResource\n    belongs_to :employee/)
      expect(output).to include("Nothing to fix.")
      expect(output).to match(/1 without resource ids/)
    end
  end
end

RSpec.describe "Graphiti::Audit::Report colour" do
  let(:rows) do
    klass = Class.new(PORO::TeamResource) do
      def self.name
        "PORO::TeamResource"
      end

      has_many :employees
    end

    Graphiti::Audit.run([klass])
  end

  it "is off when the output is not a terminal" do
    expect(Graphiti::Audit::Report.new(rows, color: false).to_s).to_not include("\e[")
  end

  it "paints an error row red when it is" do
    output = Graphiti::Audit::Report.new(rows, color: true).to_s

    expect(output).to include("\e[31;1mERROR")
  end

  it "keeps columns aligned regardless of colour" do
    plain = Graphiti::Audit::Report.new(rows, color: false).to_s
    painted = Graphiti::Audit::Report.new(rows, color: true).to_s.gsub(/\e\[[\d;]+m/, "")

    expect(painted).to eq(plain)
  end
end

RSpec.describe "Graphiti::Audit::Report layout" do
  let(:rows) do
    visa = PORO::VisaResource
    klass = Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end

      has_many :positions
      belongs_to :classification
      polymorphic_belongs_to :credit_card do
        group_by(:credit_card_type) do
          on(:Visa).belongs_to :visa, resource: visa
        end
      end
    end

    Graphiti::Audit.run([klass])
  end

  it "groups relationships with the same issue under one heading, stating the fix once" do
    team = Class.new(PORO::TeamResource) do
      def self.name
        "PORO::TeamResource"
      end

      has_many :employees
    end
    position = Class.new(PORO::PositionResource) do
      def self.name
        "PORO::PositionResource"
      end

      has_many :teams, resource: PORO::TeamResource
    end

    output = Graphiti::Audit::Report.new(Graphiti::Audit.run([team, position]), color: false).to_s

    expect(output.scan("ERROR will raise when the relationship is included: the model has no association method").size).to eq(1)
    expect(output.scan(/^  fix: define it/).size).to eq(1)
    expect(output).to match(/PORO::PositionResource\s+has_many :teams\s+PORO::Position has no #teams method/)
    expect(output).to match(/PORO::TeamResource\s+has_many :employees\s+PORO::Team has no #employees method/)
  end

  it "names the children of a polymorphic_belongs_to rather than nothing" do
    row = rows.find { |r| r.relationship == :credit_card }

    expect(row.target).to eq("VisaResource")
  end
end

RSpec.describe "Graphiti::Audit new checks" do
  def finding(resource_class, check, relationship: :positions)
    row = Graphiti::Audit.run([resource_class]).find { |r| r.relationship == relationship }
    row.findings.find { |f| f.check == check }
  end

  describe "missing sideload filter" do
    let(:unfilterable) do
      Class.new(Graphiti::Resource) do
        def self.name
          "PORO::PositionResource"
        end
        self.model = PORO::Position
        self.adapter = Graphiti::Adapters::Null
        self.type = :positions
        attribute :title, :string
      end
    end

    it "reports a has_many whose resource cannot be filtered by the foreign key" do
      target = unfilterable
      klass = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end

        has_many :positions, resource: target
      end

      found = finding(klass, :missing_sideload_filter)

      expect(found.severity).to eq(:error)
      expect(found.message).to match(/is missing `filter :employee_id`/)
      expect(found.remedy).to eq("declare the filter on the related resource")
    end

    it "says nothing when a params block builds the query, since it can replace the filter" do
      target = unfilterable
      klass = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end

        has_many :positions, resource: target do
          params do |hash|
            hash[:filter] = {id: 1}
          end
        end
      end

      expect(finding(klass, :missing_sideload_filter)).to be_nil
    end

    it "says nothing when a scope block builds the query" do
      target = unfilterable
      klass = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end

        has_many :positions, resource: target do
          scope { |ids| {type: :positions, conditions: {employee_id: ids}} }
        end
      end

      expect(finding(klass, :missing_sideload_filter)).to be_nil
    end

    it "says nothing when the filter is there" do
      klass = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end

        has_many :positions
      end

      expect(finding(klass, :missing_sideload_filter)).to be_nil
    end
  end
end
