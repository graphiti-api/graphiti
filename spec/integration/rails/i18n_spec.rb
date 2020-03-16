if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "i18n features" do
    before(:all) do
      I18n.load_path << File.expand_path("../../support/locale/documentation_i18n.yml", __dir__)
    end

    describe "Type descriptions" do
      subject(:description) { resource.description }

      context "when the resource has a locally defined description" do
        let(:resource) { HomeOfficeResource }

        it "uses the local description" do
          expect(description).to eq("An employee's primary office location")
        end
      end

      context "when the type has a description defined in a locale file's graphiti_types section" do
        let(:resource) { EmployeeResource }

        it "uses the i18n description from the graphiti types section" do
          expect(description).to eq("An employee from i18n")
        end
      end

      context "when the resource has a description defined in a locale file's graphiti_resources section" do
        let(:resource) { DepartmentResource }

        it "uses the i18n description from the graphiti resources section" do
          expect(description).to eq("Resource-based i18n department description")
        end
      end

      context "when the resource has a description defined in a locale file's graphiti_resources and graphiti_types section" do
        let(:resource) { EmployeeSearchResource }

        it "uses the i18n description from the graphiti resources section" do
          expect(description).to eq("Search-based employee lookup")
        end
      end

      context "when the resource has a description defined on the resource AND in a locale file" do
        let(:resource) { SalaryResource }

        it "uses the resource description" do
          expect(description).to eq("An employee salary")
        end
      end
    end

    describe "Attribute descriptions" do
      let(:resource) { EmployeeResource }
      let(:description) { resource.attribute_description(attribute) }

      context "when the attribute has a locally defined description" do
        let(:attribute) { :first_name }

        it "uses the local description in the schema" do
          expect(description).to eq("The employee's first name")
        end
      end

      context "when the attribute has a description defined in a locale file's types section" do
        let(:attribute) { :nickname }

        it "uses the i18n description in the schema" do
          expect(description).to eq("Employee nickname from i18n")
        end
      end

      context "when the attribute has a description defined in a locale file's resources section" do
        let(:attribute) { :salutation }

        it "uses the i18n description in the schema" do
          expect(description).to eq("Employee salutation from i18n")
        end
      end

      context "when the attribute has a description defined in a locale file's resources AND types sections" do
        let(:attribute) { :professional_titles }

        it "uses the description from the resources section" do
          expect(description).to eq("Professional titles from resource")
        end
      end

      context "when the attribute has a description locally defined AND in a locale file" do
        let(:attribute) { :last_name }

        it "uses the local description in the schema" do
          expect(description).to eq("The employee's last name")
        end
      end

      context "when the attribute has no description" do
        let(:attribute) { :age }

        it "is nil" do
          expect(description).to be_nil
        end
      end
    end

    describe "Sideload descriptions" do
      let(:resource) { EmployeeResource }
      let(:description) { resource.sideload_description(sideload) }
      let(:schema) { Graphiti::Schema.generate([resource]) }
      # resource = schema[:resources].find {|i| i[:name] == 'EmployeeResource'}
      # resource[extra ? :extra_attributes : :attributes][attribute][:description]

      context "when the sideload has a locally defined description" do
        let(:sideload) { :workspace }

        it "uses the local description" do
          expect(description).to eq("The employee's primary work area")
        end
      end

      context "when the sideload has a description defined in a locale file's types section" do
        let(:sideload) { :positions }

        it "uses the i18n description" do
          expect(description).to eq("Employee positions from i18n")
        end
      end

      context "when the sideload has a description defined in a locale file's resources section" do
        let(:sideload) { :salary }

        it "uses the i18n description" do
          expect(description).to eq("Employee salary from i18n")
        end
      end

      context "when the sideload has a description defined in a locale file's resources AND types sections" do
        let(:sideload) { :classification }

        it "uses the description from the resources section" do
          expect(description).to eq("Employee classificiation from resource")
        end
      end

      context "when the sideload has a description locally defined AND in a locale file" do
        let(:sideload) { :teams }

        it "uses the local description in the schema" do
          expect(description).to eq("Teams the employee belongs to")
        end
      end

      context "when the sideload has no description" do
        let(:resource) { PositionResource }
        let(:sideload) { :department }

        it "is nil" do
          expect(description).to be_nil
        end
      end
    end

    describe "Schema output" do
      let(:resource_class) { EmployeeResource }
      let(:schema) { Graphiti::Schema.generate([resource_class]) }
      let(:resource_schema) { schema[:resources].find { |i| i[:name] == resource_class.name } }

      describe "Resource descriptions" do
        it "uses the resource description in the schema" do
          allow(resource_class).to receive(:description).and_return("Employee Resource Description")

          expect(resource_schema[:description]).to eq "Employee Resource Description"
        end
      end

      describe "Attribute descriptions" do
        context "regular attribute" do
          let(:attribute) { :age }

          it "uses the attribute description in the schema attribute section" do
            allow(resource_class).to receive(:attribute_description)
            allow(resource_class).to receive(:attribute_description).with(attribute).and_return("description of age")

            expect(resource_schema[:attributes][attribute][:description]).to eq "description of age"
          end
        end

        context "extra attribute" do
          let(:attribute) { :nickname }

          it "uses the attribute description in the schema extra_attributes section" do
            allow(resource_class).to receive(:attribute_description)
            allow(resource_class).to receive(:attribute_description).with(attribute).and_return("description of nickname")

            expect(resource_schema[:extra_attributes][attribute][:description]).to eq "description of nickname"
          end
        end
      end

      describe "relationships descriptions" do
        let(:sideload) { :teams }

        it "uses the sideload description in the schema" do
          allow(resource_class.sideloads[:teams]).to receive(:description).and_return("description of teams")

          expect(resource_schema[:relationships][sideload][:description]).to eq "description of teams"
        end
      end
    end
  end
end
