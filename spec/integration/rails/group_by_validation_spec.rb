if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "stats[group_by] on an attribute declared readable: false" do
    let!(:position1) { Position.create!(title: "a", employee_id: 11) }
    let!(:position2) { Position.create!(title: "b", employee_id: 12) }

    after { Position.delete_all }

    it "is not readable" do
      expect(PositionResource.attributes[:employee_id][:readable]).to be false

      expect(PositionResource.all({}).as_json[:data])
        .to eq([{id: "1", title: "a"}, {id: "2", title: "b"}])

      expect { PositionResource.all(sort: "employee_id").to_a }
        .to raise_error(Graphiti::Errors::InvalidAttributeAccess)
    end

    it "is refused by stats[group_by] too" do
      expect { PositionResource.all(stats: {total: "count", group_by: :employee_id}).stats }
        .to raise_error(Graphiti::Errors::InvalidAttributeAccess)
    end

    it "refuses a column no resource declares" do
      expect { PositionResource.all(stats: {total: "count", group_by: :workspace_id}).stats }
        .to raise_error(Graphiti::Errors::UnknownAttribute)
    end
  end
end
