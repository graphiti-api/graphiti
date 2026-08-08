if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "belongs_to resource linkage" do
    include Graphiti::SpecHelpers

    let!(:employee) { Employee.create!(first_name: "Jane") }
    let!(:position) do
      Position.create!(employee: employee, title: "Engineer")
    end

    def queries_while
      queries = []
      subscriber = ActiveSupport::Notifications
        .subscribe("sql.active_record") do |_, _, _, _, payload|
          sql = payload[:sql]
          next if payload[:name].to_s == "SCHEMA"
          next if sql.start_with?("PRAGMA", "begin", "commit")
          queries << sql
        end
      yield
      queries
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # Filter to the record under test: examples in this file share a database.
    def linkage_for(resource_class, record = position)
      json = JSON.parse(resource_class.all(filter: {id: record.id}).to_jsonapi)
      json["data"][0]["relationships"]["employee"]
    end

    context "when the relationship is a plain belongs_to" do
      let(:resource_class) do
        Class.new(PositionResource) do
          def self.name
            "PositionResource"
          end

          belongs_to :employee, resource_ids: true
        end
      end

      it "renders the linkage" do
        expect(linkage_for(resource_class)).to eq(
          "data" => {"type" => "employees", "id" => employee.id.to_s}
        )
      end

      it "does not query employees to do it" do
        queries = queries_while { linkage_for(resource_class) }

        expect(queries.grep(/FROM .employees./)).to be_empty
      end

      it "renders null when the foreign key is nil" do
        # update_column, not update!: the loaded belongs_to association writes
        # its id back over the nil on save.
        position.update_column(:employee_id, nil)
        expect(linkage_for(resource_class)).to eq("data" => nil)
      end

      it "still renders correct linkage when the relationship is included" do
        json = JSON.parse(
          resource_class.all(
            filter: {id: position.id}, include: "employee"
          ).to_jsonapi
        )

        expect(json["data"][0]["relationships"]["employee"]["data"]).to eq(
          "type" => "employees", "id" => employee.id.to_s
        )
        expect(json["included"].map { |r| r["type"] }).to include("employees")
      end

      it "matches what loading the association produces" do
        from_foreign_key = linkage_for(resource_class)

        loaded = Class.new(PositionResource) do
          def self.name
            "PositionResource"
          end

          belongs_to :employee, resource_ids: true
        end
        loaded.sideloads[:employee]
          .define_singleton_method(:resource_ids_from_foreign_key?) { false }

        expect(from_foreign_key).to eq(linkage_for(loaded))
      end
    end

    context "when the relationship could resolve to a different record" do
      def sideload_for(&blk)
        klass = Class.new(PositionResource) do
          def self.name
            "PositionResource"
          end
        end
        klass.instance_eval(&blk)
        klass.sideloads[:employee]
      end

      it "loads the association when a params block is present" do
        sideload = sideload_for do
          belongs_to :employee do
            params do |hash|
              hash[:filter][:active] = true
            end
          end
        end

        expect(sideload.resource_ids_from_foreign_key?).to eq(false)
      end

      it "loads the association when a base_scope is present" do
        sideload = sideload_for do
          belongs_to :employee, base_scope: -> { Employee.all }
        end

        expect(sideload.resource_ids_from_foreign_key?).to eq(false)
      end

      it "loads the association when the target resource is polymorphic" do
        sideload = sideload_for do
          belongs_to :employee, resource: TaskResource
        end

        expect(sideload.resource_ids_from_foreign_key?).to eq(false)
      end
    end

    context "when the target is keyed by something other than :id" do
      # Examples in this file share a database, so this may already exist.
      let!(:region) do
        Region.find_or_create_by!(code: "rg-1") { |r| r.name = "Northeast" }
      end

      before { position.update_column(:region_name, "Northeast") }

      let(:resource_class) do
        Class.new(PositionResource) do
          def self.name
            "PositionResource"
          end

          belongs_to :region,
            resource: RegionResource,
            foreign_key: :region_name,
            primary_key: :name,
            resource_ids: true
        end
      end

      def region_linkage
        json = JSON.parse(
          resource_class.all(filter: {id: position.id}).to_jsonapi
        )
        json["data"][0]["relationships"]["region"]
      end

      it "renders the related id, not the foreign key" do
        expect(region_linkage["data"]).to eq(
          "type" => "regions", "id" => region.id.to_s
        )
      end

      it "loads the association to get it" do
        queries = queries_while { region_linkage }

        expect(queries.grep(/FROM .regions./)).to_not be_empty
      end
    end

    context "for relationship types other than belongs_to" do
      it "never derives linkage from a foreign key" do
        expect(EmployeeResource.sideloads[:positions].resource_ids_from_foreign_key?)
          .to eq(false)
      end
    end
  end
end
