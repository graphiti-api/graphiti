if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "public_id with ActiveRecord" do
    before(:all) do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end

    around do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end

    let(:state_resource) do
      Class.new(Legacy::StateResource) do
        def self.name
          "Legacy::StateResource"
        end

        public_id :public_id
      end
    end

    let(:author_resource) do
      state_resource_class = state_resource
      Class.new(Legacy::AuthorResource) do
        def self.name
          "Legacy::AuthorResource"
        end

        belongs_to :state, resource: state_resource_class
      end
    end

    let!(:state1) { Legacy::State.create!(name: "Maine", public_id: "st-abc") }
    let!(:state2) { Legacy::State.create!(name: "Ohio", public_id: "st-def") }
    let!(:author) { Legacy::Author.create!(first_name: "Stephen", state: state1) }

    it "finds by public id" do
      proxy = state_resource.find(id: "st-def")
      expect(proxy.data.id).to eq(state2.id)
    end

    it "renders the public id as the jsonapi id" do
      json = JSON.parse(state_resource.find(id: "st-abc").to_jsonapi)
      expect(json["data"]["id"]).to eq("st-abc")
    end

    it "sorts by the public id attribute" do
      proxy = state_resource.all(sort: "-id")
      expect(proxy.data.map(&:public_id)).to eq(%w[st-def st-abc])
    end

    it "rejects client filtering on _primary_key" do
      expect {
        state_resource.all(filter: {_primary_key: state1.id}).to_a
      }.to raise_error(Graphiti::Errors::InvalidAttributeAccess)
    end

    it "loads belongs_to includes via the real primary key and renders public ids" do
      json = JSON.parse(author_resource.all(include: "state").to_jsonapi)
      expect(json["data"][0]["relationships"]["state"]["data"]["id"]).to eq("st-abc")
      expect(json["included"].map { |i| i["id"] }).to eq(["st-abc"])
    end

    it "filters by public id" do
      proxy = state_resource.all(filter: {id: "st-def"})

      expect(proxy.data.map(&:id)).to eq([state2.id])
    end

    it "assigns a client-supplied id to the public attribute, not the primary key" do
      payload = {
        data: {
          type: "states",
          id: "st-new",
          attributes: {name: "Vermont"}
        }
      }

      created = nil
      Graphiti.with_context({}, :create) do
        proxy = state_resource.build(payload)
        expect(proxy.save).to eq(true)
        created = proxy.data
      end

      expect(created.public_id).to eq("st-new")
      expect(created.id).to be_a(Integer)
      expect(Legacy::State.find(created.id).public_id).to eq("st-new")
    end

    it "renders the public id as linkage when the relationship opts in" do
      state_resource_class = state_resource
      resource = Class.new(Legacy::AuthorResource) do
        def self.name
          "Legacy::AuthorResource"
        end
      end
      resource.belongs_to :state,
        resource: state_resource_class,
        always_include_resource_ids: true

      json = JSON.parse(resource.all({}).to_jsonapi)

      expect(json["data"][0]["relationships"]["state"]["data"]["id"]).to eq("st-abc")
    end

    it "renders the public id as linkage without loading the association" do
      json = JSON.parse(author_resource.all({}).to_jsonapi)

      expect(json["data"][0]["relationships"]["state"]["data"])
        .to eq({"type" => "states", "id" => "st-abc"})
      expect(json).to_not have_key("included")
    end

    it "resolves every rendered foreign key in one query" do
      Legacy::Author.create!(first_name: "Peter", state: state2)
      queries = []
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] if payload[:name] == "Legacy::State Load"
      end

      author_resource.all({}).to_jsonapi

      ActiveSupport::Notifications.unsubscribe(subscription)
      expect(queries.size).to eq(1)
    end

    context "has_many related links" do
      let(:author_resource) do
        Class.new(Legacy::AuthorResource) do
          def self.name
            "Legacy::AuthorResource"
          end

          public_id :public_id
        end
      end

      let(:book_resource) do
        author_resource_class = author_resource
        Class.new(Legacy::BookResource) do
          def self.name
            "Legacy::BookResource"
          end

          belongs_to :author, resource: author_resource_class
        end
      end

      before do
        author_resource.has_many :books, resource: book_resource, link: true
      end

      let!(:author) { Legacy::Author.create!(first_name: "Stephen", public_id: "auth-abc") }
      let!(:other_author) { Legacy::Author.create!(first_name: "Peter", public_id: "auth-def") }
      let!(:book) { Legacy::Book.create!(title: "The Shining", author: author) }
      let!(:other_book) { Legacy::Book.create!(title: "Damage", author: other_author) }

      around do |example|
        previous = Graphiti.config.context_for_endpoint
        Graphiti.config.context_for_endpoint = ->(path, action) { double("context") }
        example.run
        Graphiti.config.context_for_endpoint = previous
      end

      it "names the author by public id" do
        json = JSON.parse(author_resource.all(filter: {id: "auth-abc"}).to_jsonapi)

        expect(json["data"][0]["relationships"]["books"]["links"]["related"])
          .to eq("/legacy/books?filter[author_id]=auth-abc")
      end

      it "returns that author's books when a client follows the link" do
        books = book_resource.all(filter: {author_id: "auth-abc"})

        expect(books.data.map(&:title)).to eq(["The Shining"])
      end

      it "translates a public id inside an operator hash" do
        books = book_resource.all(filter: {author_id: {not_eq: "auth-abc"}})

        expect(books.data.map(&:title)).to eq(["Damage"])
      end

      it "still sideloads through the real foreign key" do
        json = JSON.parse(author_resource.all(include: "books").to_jsonapi)

        expect(json["included"].map { |node| node["attributes"]["title"] })
          .to match_array(["The Shining", "Damage"])
      end

      it "creates a book from a public id posted as a writable foreign key" do
        book_resource.attribute :author_id, :integer, readable: false
        proxy = Graphiti.with_context({}, :create) do
          book_resource.build(data: {type: "books", attributes: {title: "Carrie", author_id: "auth-abc"}}).tap(&:save)
        end

        expect(proxy.data.reload.author).to eq(author)
      end

      it "translates a public id through the generated many_to_many filter" do
        hobby_resource = Class.new(Legacy::HobbyResource) do
          def self.name
            "Legacy::HobbyResource"
          end
        end
        author_resource.many_to_many :hobbies, resource: hobby_resource
        hobby = Legacy::Hobby.create!(name: "Writing")
        Legacy::AuthorHobby.create!(author: author, hobby: hobby)
        Legacy::AuthorHobby.create!(author: other_author, hobby: Legacy::Hobby.create!(name: "Sailing"))

        expect(hobby_resource.all(filter: {author_id: "auth-abc"}).data).to eq([hobby])
      end

      it "keys a stat grouped by the foreign key on public ids" do
        book_resource.stat author_id: [:count]

        proxy = book_resource.all(stats: {group_by: :author_id, author_id: :count})

        expect(proxy.stats[:author_id][:count]).to eq("auth-abc" => 1, "auth-def" => 1)
      end
    end

    context "declared with a block" do
      let(:author_resource) do
        Class.new(Legacy::AuthorResource) do
          def self.name
            "Legacy::AuthorResource"
          end

          public_id do
            encode { |primary_key| "auth-#{primary_key}" }
            decode { |public_id| public_id[/\Aauth-(\d+)\z/, 1]&.to_i }
          end
        end
      end

      let(:book_resource) do
        author_resource_class = author_resource
        Class.new(Legacy::BookResource) do
          def self.name
            "Legacy::BookResource"
          end

          belongs_to :author, resource: author_resource_class, resource_ids: true
          stat author_id: [:count]
        end
      end

      let!(:author) { Legacy::Author.create!(first_name: "Stephen") }
      let!(:book) { Legacy::Book.create!(title: "The Shining", author: author) }

      it "renders linkage by encoded id without querying the author" do
        queries = []
        callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("authors") }
        json = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          JSON.parse(book_resource.all.to_jsonapi)
        end

        expect(json["data"][0]["relationships"]["author"]["data"]).to eq("type" => "authors", "id" => "auth-#{author.id}")
        expect(queries).to be_empty
      end

      it "loads the include through the primary key and renders the encoded id" do
        json = JSON.parse(book_resource.all(include: "author").to_jsonapi)

        expect(json["included"][0]["id"]).to eq("auth-#{author.id}")
      end

      it "keys a stat grouped by the foreign key on encoded ids" do
        proxy = book_resource.all(stats: {group_by: :author_id, author_id: :count})

        expect(proxy.stats[:author_id][:count]).to eq("auth-#{author.id}" => 1)
      end
    end

    context "with a stat on the id" do
      let(:state_resource) do
        Class.new(Legacy::StateResource) do
          def self.name
            "Legacy::StateResource"
          end

          public_id :public_id
          stat id: [:count]
        end
      end

      it "counts through the public attribute" do
        proxy = state_resource.all(stats: {id: :count})

        expect(proxy.stats[:id][:count]).to eq(2)
      end

      it "groups by the public id, matching what the records render" do
        proxy = state_resource.all(stats: {group_by: :id, id: :count})

        expect(proxy.stats[:id][:count].keys).to match_array(%w[st-abc st-def])
      end
    end

    context "on a model whose primary key is not :id" do
      let(:region_resource) do
        Class.new(Legacy::RegionResource) do
          def self.name
            "Legacy::RegionResource"
          end

          public_id :public_id
        end
      end

      let(:author_resource) do
        region_resource_class = region_resource
        Class.new(Legacy::AuthorResource) do
          def self.name
            "Legacy::AuthorResource"
          end

          belongs_to :region,
            resource: region_resource_class,
            foreign_key: :region_code
        end
      end

      let!(:region) do
        Legacy::Region.create!(code: "rg-1", name: "Northeast", public_id: "reg-abc")
      end
      let!(:author) do
        Legacy::Author.create!(first_name: "Stephen", region_code: "rg-1")
      end

      it "renders the public id, not the primary key" do
        json = JSON.parse(region_resource.all({}).to_jsonapi)

        expect(json["data"][0]["id"]).to eq("reg-abc")
      end

      it "loads a belongs_to through the model's own primary key" do
        json = JSON.parse(author_resource.all(include: "region").to_jsonapi)

        expect(json["included"].map { |i| i["id"] }).to eq(["reg-abc"])
      end

      it "still rejects client filtering on _primary_key" do
        expect {
          region_resource.all(filter: {_primary_key: "rg-1"}).to_a
        }.to raise_error(Graphiti::Errors::InvalidAttributeAccess)
      end

      context "with an explicit primary_key on the belongs_to" do
        around do |example|
          previous = Graphiti.config.context_for_endpoint
          Graphiti.config.context_for_endpoint = ->(path, action) { double("context") }
          example.run
          Graphiti.config.context_for_endpoint = previous
        end

        def author_resource_keyed_on(primary_key)
          region_resource_class = region_resource
          Class.new(Legacy::AuthorResource) do
            def self.name
              "Legacy::AuthorResource"
            end

            belongs_to :region,
              resource: region_resource_class,
              foreign_key: :region_code,
              primary_key: primary_key,
              link: true
          end
        end

        it "links by public id when the key is the model's own primary key" do
          json = JSON.parse(author_resource_keyed_on(:code).all({}).to_jsonapi)

          relationship = json["data"][0]["relationships"]["region"]
          expect(relationship["links"]["related"]).to eq("/legacy/regions/reg-abc")
          expect(relationship["data"]).to eq({"type" => "regions", "id" => "reg-abc"})
        end

        it "links by public id when the key is another column the target filters on" do
          author.update!(region_code: "Northeast")
          json = JSON.parse(author_resource_keyed_on(:name).all({}).to_jsonapi)

          relationship = json["data"][0]["relationships"]["region"]
          expect(relationship["links"]["related"]).to eq("/legacy/regions/reg-abc")
          expect(relationship["data"]).to eq({"type" => "regions", "id" => "reg-abc"})
        end

        it "renders neither a link nor linkage when the target has no filter on the key" do
          region_resource.filters.delete(:name)
          json = JSON.parse(author_resource_keyed_on(:name).all({}).to_jsonapi)

          expect(json["data"][0]["relationships"]).to_not have_key("region")
          expect(json.to_s).to_not include("rg-1")
        end
      end
    end

    it "updates by public id" do
      payload = {
        data: {
          type: "states",
          id: "st-abc",
          attributes: {name: "Vermont"}
        }
      }
      Graphiti.with_context({}, :update) do
        proxy = state_resource.find(payload)
        expect(proxy.update_attributes).to eq(true)
      end
      expect(state1.reload.name).to eq("Vermont")
    end

    it "compares public ids exactly" do
      expect(state_resource.all(filter: {id: "ST-ABC"}).data).to be_empty
      expect(state_resource.all(filter: {id: "st-abc"}).data.map(&:id)).to eq([state1.id])
    end

    it "excludes by public id with not_eq" do
      expect(state_resource.all(filter: {id: {not_eq: "st-abc"}}).data.map(&:id)).to eq([state2.id])
    end

    context "a polymorphic belongs_to whose target publishes public ids" do
      let(:office_resource) do
        Class.new(OfficeResource) do
          def self.name
            "OfficeResource"
          end

          public_id do
            encode { |primary_key| "off-#{primary_key}" }
            decode { |public_id| public_id.delete_prefix("off-").to_i }
          end
        end
      end

      let(:employee_resource) do
        Class.new(EmployeeResource) do
          def self.name
            "EmployeeResource"
          end

          polymorphic_belongs_to :workspace do
            group_by(:workspace_type) do
              on(:Office)
              on(:HomeOffice)
            end
          end
        end
      end

      let!(:office) { Office.create!(address: "1 Main") }
      let!(:employee) { Employee.create!(first_name: "Ann", workspace: office) }

      before { stub_const("OfficeResource", office_resource) }

      it "renders the workspace linkage and include by public id" do
        json = JSON.parse(employee_resource.all(include: "workspace", filter: {id: employee.id}).to_jsonapi)

        expect(json["data"][0]["relationships"]["workspace"]["data"]).to eq("type" => "offices", "id" => "off-#{office.id}")
        expect(json["included"][0]["id"]).to eq("off-#{office.id}")
      end
    end
  end
end
