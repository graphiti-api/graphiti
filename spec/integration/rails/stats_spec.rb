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

    context "when grouping" do
      it "works" do
        proxy = PositionResource.all(stats: {total: "count", group_by: :employee_id})
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
