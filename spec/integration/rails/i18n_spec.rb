if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe 'i18n features' do
    before(:all) do
      I18n.load_path << File.expand_path("../../support/locale/documentation_i18n.yml", __dir__)
    end

    describe 'Type descriptions' do
      subject(:description) { resource.description }

      context 'when the resource has a locally defined description' do
        let(:resource) { HomeOfficeResource }

        it 'uses the local description' do
          expect(description).to eq("An employee's primary office location")
        end
      end

      context "when the type has a description defined in a locale file's graphiti_types section" do
        let(:resource) { EmployeeResource }

        it 'uses the i18n description from the graphiti types section' do
          expect(description).to eq("An employee from i18n")
        end
      end

      context "when the resource has a description defined in a locale file's graphiti_resources section" do
        let(:resource) { DepartmentResource }

        it 'uses the i18n description from the graphiti resources section' do
          expect(description).to eq("Resource-based i18n department description")
        end
      end

      context "when the resource has a description defined in a locale file's graphiti_resources and graphiti_types section" do
        let(:resource) { EmployeeSearchResource }

        it 'uses the i18n description from the graphiti resources section' do
          expect(description).to eq("Search-based employee lookup")
        end
      end

      context 'when the resource has a description defined on the resource AND in a locale file' do
        let(:resource) { SalaryResource }

        it 'uses the resource description' do
          expect(description).to eq("An employee salary")
        end
      end
    end

    describe 'Attribute descriptions' do
      let(:schema) { Graphiti::Schema.generate([EmployeeResource]) }
      let(:description) do
        resource = schema[:resources].find {|i| i[:name] == 'EmployeeResource'}
        resource[extra ? :extra_attributes : :attributes][attribute][:description]
      end
      let(:extra) { false }

      context 'when the attribute has a locally defined description' do
        let(:attribute) { :first_name }

        it 'uses the local description in the schema' do
          expect(description).to eq("The employee's first name")
        end
      end

      context "when the attribute has a description defined in a locale file's types section" do
        let(:attribute) { :nickname }
        let(:extra) { true }

        it 'uses the i18n description in the schema' do
          expect(description).to eq("Employee nickname from i18n")
        end
      end

      context "when the attribute has a description defined in a locale file's resources section" do
        let(:attribute) { :salutation }
        let(:extra) { true }

        it 'uses the i18n description in the schema' do
          expect(description).to eq("Employee salutation from i18n")
        end
      end

      context "when the attribute has a description defined in a locale file's resources AND types sections" do
        let(:attribute) { :professional_titles }
        let(:extra) { true }

        it 'uses the description from the resources section' do
          expect(description).to eq("Professional titles from resource")
        end
      end

      context 'when the attribute has a description locally defined AND in a locale file' do
        let(:attribute) { :last_name }

        it 'uses the local description in the schema' do
          expect(description).to eq("The employee's last name")
        end
      end

      context 'when the attribute has no description' do
        let(:attribute) { :age }

        it 'is nil' do
          expect(description).to be_nil
        end
      end
    end
  end
end