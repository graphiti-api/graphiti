if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "stats" do
    let!(:pos1) { Position.create!(title: "a", employee_id: 1) }
    let!(:pos2) { Position.create!(title: "b", employee_id: 2) }
    let!(:pos3) { Position.create!(title: "c", employee_id: 2) }
    let!(:pos4) { Position.create!(title: "d", employee_id: 2) }
    let!(:pos5) { Position.create!(title: "e", employee_id: 3) }
    let!(:pos6) { Position.create!(title: "f", employee_id: 3) }

    after do
      Position.delete_all
    end

    context "basic" do
      it "works" do
        proxy = PositionResource.all(stats: {total: "count"})
        expect(proxy.stats).to eq({
          total: {
            count: 6
          }
        })
      end
    end

    context "when a filter joins and duplicates rows" do
      let!(:employee) { Employee.create!(first_name: "Jane") }

      let(:resource) do
        Class.new(EmployeeResource) do
          self.model = Employee

          filter :has_positions, :boolean do
            eq do |scope, value|
              scope.joins(:positions)
            end
          end

          def self.name
            "EmployeeResource"
          end
        end
      end

      before do
        3.times { |i| Position.create!(title: "p#{i}", employee_id: employee.id) }
      end

      it "counts each row once" do
        proxy = resource.all(filter: {has_positions: true}, stats: {total: "count"})
        expect(proxy.stats[:total][:count]).to eq(1)
      end
    end

    context "when grouping" do
      let(:resource) do
        Class.new(PositionResource) do
          attribute :employee_id, :integer

          def self.name
            "PositionResource"
          end
        end
      end

      it "works" do
        proxy = resource.all(stats: {total: "count", group_by: :employee_id})
        expect(proxy.stats).to eq({
          total: {
            count: {
              1 => 1,
              2 => 3,
              3 => 2
            }
          }
        })
      end
    end
  end
end
