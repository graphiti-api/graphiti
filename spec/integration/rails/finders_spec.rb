if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "integrated resources and adapters", type: :controller do
    include GraphitiSpecHelpers

    controller(ApplicationController) do
      def index
        records = resource.all(params)
        render jsonapi: records
      end

      def show
        record = resource.find(params)
        render jsonapi: record
      end

      def resource
        Legacy::AuthorResource
      end
    end

    let(:one_day_ago) { 1.day.ago }
    let(:two_days_ago) { 2.days.ago }
    let(:one_day_from_now) { 1.day.from_now }

    let!(:author1) do
      Legacy::Author.create! first_name: "Stephen",
        age: 70,
        active: true,
        float_age: 70.03,
        decimal_age: 70.033,
        state: state,
        organization: org1,
        dwelling: house,
        created_at: one_day_ago,
        last_login: one_day_ago,
        created_at_date: one_day_ago.to_date,
        identifier: SecureRandom.uuid
    end
    let!(:author2) do
      Legacy::Author.create! first_name: "George",
        age: 65,
        active: false,
        float_age: 70.01,
        decimal_age: 70.011,
        dwelling: condo,
        created_at: two_days_ago,
        last_login: one_day_ago,
        created_at_date: two_days_ago.to_date,
        identifier: SecureRandom.uuid
    end
    let!(:book1) { Legacy::Book.create!(author: author1, genre: genre, title: "The Shining") }
    let!(:book2) { Legacy::Book.create!(author: author1, genre: genre, title: "The Stand") }
    let!(:state) { Legacy::State.create!(name: "Maine") }
    let(:org1) { Legacy::Organization.create!(name: "Org1", children: [org2]) }
    let(:org2) { Legacy::Organization.create!(name: "Org2") }
    let!(:bio) { Legacy::Bio.create!(author: author1, picture: "imgur", description: "author bio") }
    let!(:genre) { Legacy::Genre.create!(name: "Horror") }
    let!(:hobby1) { Legacy::Hobby.create!(name: "Fishing", authors: [author1]) }
    let!(:hobby2) { Legacy::Hobby.create!(name: "Woodworking", authors: [author1, author2]) }
    let!(:house) { Legacy::House.new(name: "Cozy", state: state) }
    let!(:condo) { Legacy::Condo.new(name: "Modern") }

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    let(:path) { "/legacy/authors" }

    it "allows basic sorting" do
      do_index({sort: "-id"})
      expect(d.map(&:id)).to eq([author2.id, author1.id])
    end

    it "allows allowlisted filters (and other configs)" do
      do_index({filter: {first_name: "George"}})
      expect(d.map(&:id)).to eq([author2.id])
    end

    it "allows basic sideloading" do
      do_index({include: "books"})
      expect(included.map(&:jsonapi_type).uniq).to match_array(%w[books])
    end

    it "allows nested sideloading" do
      do_index({include: "books.genre"})
      expect(included.map(&:jsonapi_type).uniq)
        .to match_array(%w[books genres])
    end

    describe "paginating" do
      let!(:author3) { Legacy::Author.create! first_name: "3" }
      let!(:author4) { Legacy::Author.create! first_name: "4" }

      subject do
        do_index(page: params)
        d.map(&:id)
      end

      context "by number and size" do
        let(:params) { {number: 2, size: 1} }

        it { is_expected.to eq([author2.id]) }
      end

      context "by only offset" do
        let(:params) { {offset: 2} }

        it { is_expected.to eq([author3.id, author4.id]) }
      end

      context "by offset and size" do
        let(:params) { {offset: 2, size: 1} }

        it { is_expected.to eq([author3.id]) }
      end

      context "by offset, number and size" do
        let(:params) { {offset: 2, size: 1, number: 2} }

        it { is_expected.to eq([author4.id]) }
      end

      context "when rendering pagination links" do
        let(:params) { {size: 1, number: 2} }

        around do |e|
          original = Graphiti.config.pagination_links
          begin
            Graphiti.config.pagination_links = true
            e.run
          ensure
            Graphiti.config.pagination_links = original
          end
        end

        let(:links) do
          {}.tap do |links|
            json["links"].each_pair do |key, value|
              links[key] = CGI.unescape(value).split("?")[1]
            end
          end
        end

        context "with page and size" do
          it "works" do
            do_index(page: params)
            expect(links["self"]).to eq("page[number]=2&page[size]=1")
            expect(links["first"]).to eq("page[number]=1&page[size]=1")
            expect(links["last"]).to eq("page[number]=4&page[size]=1")
            expect(links["prev"]).to eq("page[number]=1&page[size]=1")
            expect(links["next"]).to eq("page[number]=3&page[size]=1")
          end

          context "when on the last page" do
            let(:params) { {size: 1, number: 4} }

            it "does not render 'next'" do
              do_index(page: params)
              expect(links).to_not have_key("next")
            end
          end

          context "and offset" do
            before do
              params[:offset] = 1
            end

            it "works" do
              do_index(page: params)

              expect(d[0].id).to eq(author3.id)
              expect(links["self"])
                .to eq("page[number]=2&page[offset]=1&page[size]=1")
              expect(links["first"])
                .to eq("page[number]=1&page[offset]=1&page[size]=1")
              expect(links["last"])
                .to eq("page[number]=3&page[offset]=1&page[size]=1")
              expect(links["prev"])
                .to eq("page[number]=1&page[offset]=1&page[size]=1")
              expect(links["next"])
                .to eq("page[number]=3&page[offset]=1&page[size]=1")
            end

            context "when on the last page" do
              before do
                params[:number] = 3 # 1 per page + 1 offset = 4th/last result
              end

              it "does not render 'next'" do
                do_index(page: params)
                expect(d[0].id).to eq(author4.id)
                expect(links).to_not have_key("next")
              end
            end
          end
        end
      end
    end

    describe "filtering" do
      subject(:ids) do
        do_index({filter: filter})
        d.map(&:id)
      end

      let!(:author3) do
        Legacy::Author.create! first_name: "GeOrge",
          age: 72,
          identifier: "AbC123",
          active: true,
          float_age: 70.05,
          decimal_age: 70.055,
          last_login: nil,
          created_at: 1.day.from_now,
          created_at_date: 1.day.from_now.to_date
      end

      context "when multiple operators" do
        let(:filter) { {age: {gte: 50, lte: 70}} }

        it "works" do
          expect(ids).to eq([author1.id, author2.id])
        end
      end

      context "when an integer_id" do
        let(:filter) { {id: value} }

        context "passed as an integer" do
          let(:value) { {eq: author2.id} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "passed as a string" do
          let(:value) { {eq: author2.id.to_s} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end
      end

      context "when a uuid" do
        context "eq" do
          it "executes case-sensitive search (invalid)" do
            do_index({filter: {identifier: "abc123"}})
            expect(d.map(&:id)).to eq([])
          end

          it "executes case-sensitive search (valid)" do
            do_index({filter: {identifier: "AbC123"}})
            expect(d.map(&:id)).to eq([author3.id])
          end
        end

        context "!eq" do
          it "executes case-sensitive search (invalid)" do
            do_index({filter: {identifier: {not_eq: "abc123"}}})
            expect(d.map(&:id).length).to eq(3)
          end

          it "executes case-sensitive search (valid)" do
            do_index({filter: {identifier: {not_eq: "AbC123"}}})
            expect(d.map(&:id).length).to eq(2)
          end
        end
      end

      context "when a string" do
        let(:filter) { {first_name: value} }

        context "eq" do
          let(:value) { {eq: "george"} }

          it "executes case-insensitive search" do
            expect(ids).to eq([author2.id, author3.id])
          end
        end

        context "nothing" do
          let(:value) { "george" }

          it "defaults to eq" do
            expect(ids).to eq([author2.id, author3.id])
          end
        end

        context "eql" do
          let(:value) { {eql: "GeOrge"} }

          it "executes case-sensitive search" do
            expect(ids).to eq([author3.id])
          end
        end

        context "!eq" do
          let(:value) { {'!eq': "george"} }

          it "executes case-insensitive NOT search" do
            expect(ids).to eq([author1.id])
          end
        end

        # test not_ alternative to !
        context "not_eq" do
          let(:value) { {not_eq: "george"} }

          it "executes case-insensitive NOT search" do
            expect(ids).to eq([author1.id])
          end
        end

        # test not_ alternative to !
        context "not_eq" do
          let(:value) { {not_eq: "george"} }

          it "executes case-insensitive NOT search" do
            expect(ids).to eq([author1.id])
          end
        end

        context "!eql" do
          let(:value) { {'!eql': "GeOrge"} }

          it "executes case-sensitive search" do
            expect(ids).to eq([author1.id, author2.id])
          end
        end

        context "prefix" do
          let(:value) { {prefix: "GEO"} }

          it "executes case-insensitive prefix query" do
            expect(ids).to eq([author2.id, author3.id])
          end

          if ::ActiveRecord.version >= Gem::Version.new("5.0")
            context "when match string includes % characters" do
              let(:value) { {prefix: "%ild"} }

              let!(:author_with_percent) do
                Legacy::Author.create!(first_name: "%ildcard")
              end

              let!(:normal_author) do
                Legacy::Author.create!(first_name: "wildcard")
              end

              it "does not use the provided % as a wildcard character" do
                expect(ids).to eq([author_with_percent.id])
              end
            end
          end
        end

        context "!prefix" do
          let(:value) { {'!prefix': "Geo"} }

          it "executes case-insensitive prefix NOT query" do
            expect(ids).to eq([author1.id])
          end
        end

        context "suffix" do
          let(:value) { {suffix: "orge"} }

          it "executes case-insensitive suffix query" do
            expect(ids).to eq([author2.id, author3.id])
          end

          if ::ActiveRecord.version >= Gem::Version.new("5.0")
            context "when match string includes % characters" do
              let(:value) { {suffix: "car%"} }

              let!(:author_with_percent) do
                Legacy::Author.create!(first_name: "Wildcar%")
              end

              let!(:normal_author) do
                Legacy::Author.create!(first_name: "Wildcard")
              end

              it "does not use the provided % as a wildcard character" do
                expect(ids).to eq([author_with_percent.id])
              end
            end
          end
        end

        context "!suffix" do
          let(:value) { {'!suffix': "orge"} }

          it "executes case-insensitive suffix NOT query" do
            expect(ids).to eq([author1.id])
          end
        end

        context "match" do
          let(:value) { {match: "org"} }

          it "executes case-insensitive match query" do
            expect(ids).to eq([author2.id, author3.id])
          end

          if ::ActiveRecord.version >= Gem::Version.new("5.0")
            context "when match string includes % characters" do
              let(:value) { {match: "ld%ca"} }

              let!(:author_with_percent) do
                Legacy::Author.create!(first_name: "Wild%card")
              end

              let!(:author_with_dash) do
                Legacy::Author.create!(first_name: "Wild-card")
              end

              it "does not use the provided % as a wildcard character" do
                expect(ids).to eq([author_with_percent.id])
              end
            end
          end
        end

        context "!match" do
          let(:value) { {'!match': "org"} }

          it "executes case-insensitive NOT match query" do
            expect(ids).to eq([author1.id])
          end
        end
      end

      context "when an integer" do
        let(:filter) { {age: value} }

        context "eq" do
          let(:value) { {eq: 65} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "!eq" do
          let(:value) { {'!eq': 65} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "nothing" do
          let(:value) { 65 }

          it "defaults to eq" do
            expect(ids).to eq([author2.id])
          end
        end

        context "gt" do
          let(:value) { {gt: 70} }

          it "works" do
            expect(ids).to eq([author3.id])
          end
        end

        context "gte" do
          let(:value) { {gte: 70} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "lt" do
          let(:value) { {lt: 70} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "lte" do
          let(:value) { {lte: 70} }

          it "works" do
            expect(ids).to eq([author1.id, author2.id])
          end
        end
      end

      context "when a decimal" do
        let(:filter) { {decimal_age: value} }

        context "eq" do
          let(:value) { {eq: 70.011.to_d} }

          it "works" do
            expect(ids).to eq([author2.id])
          end

          context "as a string" do
            let(:value) { {eq: 70.011.to_d.to_s} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end
        end

        context "!eq" do
          let(:value) { {'!eq': 70.011.to_d} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "nothing" do
          let(:value) { 70.011.to_d }

          it "defaults to eq" do
            expect(ids).to eq([author2.id])
          end
        end

        context "gt" do
          let(:value) { {gt: 70.033.to_d} }

          it "works" do
            expect(ids).to eq([author3.id])
          end
        end

        context "gte" do
          let(:value) { {gte: 70.033.to_d} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "lt" do
          let(:value) { {lt: 70.033.to_d} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "lte" do
          let(:value) { {lte: 70.033.to_d} }

          it "works" do
            expect(ids).to eq([author1.id, author2.id])
          end
        end
      end

      context "when a float" do
        let(:filter) { {float_age: value} }

        context "eq" do
          let(:value) { {eq: 70.01} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "!eq" do
          let(:value) { {'!eq': 70.01} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "nothing" do
          let(:value) { 70.01 }

          it "defaults to eq" do
            expect(ids).to eq([author2.id])
          end
        end

        context "gt" do
          let(:value) { {gt: 70.03} }

          it "works" do
            expect(ids).to eq([author3.id])
          end
        end

        context "gte" do
          let(:value) { {gte: 70.03} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "lt" do
          let(:value) { {lt: 70.03} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "lte" do
          let(:value) { {lte: 70.03} }

          it "works" do
            expect(ids).to eq([author1.id, author2.id])
          end
        end
      end

      context "when a date" do
        let(:filter) { {created_at_date: value} }

        context "eq" do
          let(:value) { {eq: two_days_ago.to_date.iso8601} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "!eq" do
          let(:value) { {'!eq': two_days_ago.to_date.iso8601} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "nothing" do
          let(:value) { two_days_ago.to_date.iso8601 }

          it "defaults to eq" do
            expect(ids).to eq([author2.id])
          end
        end

        context "gt" do
          let(:value) { {gt: one_day_ago.to_date.iso8601} }

          it "works" do
            expect(ids).to eq([author3.id])
          end
        end

        context "gte" do
          let(:value) { {gte: one_day_ago.to_date.iso8601} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "lt" do
          let(:value) { {lt: one_day_ago.to_date.iso8601} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "lte" do
          let(:value) { {lte: one_day_ago.to_date.iso8601} }

          it "works" do
            expect(ids).to eq([author1.id, author2.id])
          end
        end
      end

      context "when a datetime" do
        let(:filter) { {created_at: value} }

        context "eq" do
          let(:value) { {eq: two_days_ago.iso8601} }

          it "works" do
            expect(ids).to eq([author2.id])
          end

          context "when value is nil" do
            let(:filter) { {last_login: value} }
            let(:value) { {eq: "null"} }

            it "works" do
              expect(ids).to eq([author3.id])
            end
          end
        end

        context "!eq" do
          let(:value) { {'!eq': two_days_ago.iso8601} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end

          context "when value is nil" do
            let(:filter) { {last_login: value} }
            let(:value) { {'!eq': "null"} }

            it "works" do
              expect(ids).to eq([author1.id, author2.id])
            end
          end
        end

        context "nothing" do
          let(:value) { two_days_ago.iso8601 }

          it "defaults to eq" do
            expect(ids).to eq([author2.id])
          end
        end

        # Add a second to accomodate fractionals
        context "gt" do
          let(:value) { {gt: (one_day_ago + 1.second).iso8601} }

          it "works" do
            expect(ids).to eq([author3.id])
          end
        end

        context "gte" do
          let(:value) { {gte: one_day_ago.iso8601} }

          it "works" do
            expect(ids).to eq([author1.id, author3.id])
          end
        end

        context "lt" do
          let(:value) { {lt: one_day_ago.iso8601} }

          it "works" do
            expect(ids).to eq([author2.id])
          end
        end

        context "lte" do
          let(:value) { {lte: one_day_ago.iso8601} }

          it "works" do
            expect(ids).to eq([author1.id, author2.id])
          end
        end
      end

      context "when a boolean" do
        let(:filter) { {active: value} }

        context "eq" do
          context "when true" do
            let(:value) { {eq: true} }

            it "works" do
              expect(ids).to eq([author1.id, author3.id])
            end
          end

          context "when false" do
            let(:value) { {eq: false} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end

          context "when string true" do
            let(:value) { {eq: "true"} }

            it "works" do
              expect(ids).to eq([author1.id, author3.id])
            end
          end

          context "when string false" do
            let(:value) { {eq: "false"} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end
        end

        context "nothing" do
          let(:value) { false }

          it "defaults to eq" do
            expect(ids).to eq([author2.id])
          end
        end
      end

      context "when aliasing the column" do
        context "when string" do
          let(:filter) { {fname: value} }

          describe "eq" do
            let(:value) { {eq: author2.first_name.upcase} }

            it "works" do
              expect(ids).to eq([author2.id, author3.id])
            end
          end

          describe "not_eq" do
            let(:value) { {not_eq: author2.first_name.upcase} }

            it "works" do
              expect(ids).to eq([author1.id])
            end
          end

          describe "eql" do
            let(:value) { {eql: author2.first_name} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end

          describe "not_eql" do
            let(:value) { {not_eql: author2.first_name} }

            it "works" do
              expect(ids).to eq([author1.id, author3.id])
            end
          end

          describe "prefix" do
            let(:value) { {prefix: author2.first_name[0..3]} }

            it "works" do
              expect(ids).to eq([author2.id, author3.id])
            end
          end

          describe "not_prefix" do
            let(:value) { {not_prefix: author2.first_name[0..3]} }

            it "works" do
              expect(ids).to eq([author1.id])
            end
          end

          describe "suffix" do
            let(:value) { {suffix: "rge"} }

            it "works" do
              expect(ids).to eq([author2.id, author3.id])
            end
          end

          describe "not_suffix" do
            let(:value) { {not_suffix: "rge"} }

            it "works" do
              expect(ids).to eq([author1.id])
            end
          end

          describe "match" do
            let(:value) { {match: "eor"} }

            it "works" do
              expect(ids).to eq([author2.id, author3.id])
            end
          end

          describe "not match" do
            let(:value) { {not_match: "eor"} }

            it "works" do
              expect(ids).to eq([author1.id])
            end
          end
        end

        context "when numeric" do
          let(:filter) { {birthdays: value} }

          describe "eq" do
            let(:value) { {eq: author2.age} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end

          describe "not_eq" do
            let(:value) { {not_eq: author2.age} }

            it "works" do
              expect(ids).to eq([author1.id, author3.id])
            end
          end

          describe "gt" do
            let(:value) { {gt: 70} }

            it "works" do
              expect(ids).to eq([author3.id])
            end
          end

          describe "gte" do
            let(:value) { {gte: 70} }

            it "works" do
              expect(ids).to eq([author1.id, author3.id])
            end
          end

          describe "lt" do
            let(:value) { {lt: 70} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end

          describe "lte" do
            let(:value) { {lte: 70} }

            it "works" do
              expect(ids).to eq([author1.id, author2.id])
            end
          end
        end

        context "when datetime" do
          let(:filter) { {created_at: value} }

          describe "eq" do
            let(:value) { {eq: two_days_ago.iso8601} }

            it "works" do
              expect(ids).to eq([author2.id])
            end
          end

          describe "not_eq" do
            let(:value) { {not_eq: two_days_ago.iso8601} }

            it "works" do
              expect(ids).to eq([author1.id, author3.id])
            end
          end

          describe "lte" do
            let(:value) { {lte: one_day_ago.iso8601} }

            it "works" do
              expect(ids).to eq([author1.id, author2.id])
            end
          end
        end
      end
    end

    context "when hitting #show" do
      subject(:make_request) do
        do_show({id: id, include: "books"})
      end

      let(:id) { author1.id.to_s }
      let(:path) { "/legacy/authors/#{id}" }

      it "works" do
        make_request
        expect(json["data"]["id"]).to eq(author1.id.to_s)
        expect(json["data"]["attributes"].except("identifier")).to eq({
          "first_name" => "Stephen",
          "fname" => "Stephen", # alias
          "age" => 70,
          "birthdays" => 70, # alias
          "float_age" => 70.03,
          "decimal_age" => "70.033",
          "active" => true
        })
        expect(included.map(&:jsonapi_type).uniq).to match_array(%w[books])
      end

      context "and record not found" do
        let(:id) { "99999" }

        it "raises not found error" do
          expect {
            make_request
          }.to raise_error(Graphiti::Errors::RecordNotFound)
        end
      end
    end

    context "when passing sparse fieldsets on primary data" do
      context "and sideloading" do
        it "is able to sideload without adding the field" do
          do_index({
            fields: {authors: "first_name"},
            include: "books"
          })
          expect(json["data"][0]["relationships"]).to be_present
          expect(included.map(&:jsonapi_type).uniq).to match_array(%w[books])
        end
      end
    end

    context "sideloading has_many" do
      it "can sideload" do
        do_index({include: "books"})
        expect(included("books").map(&:id)).to eq([book1.id, book2.id])
      end

      context "when paginating the sideload" do
        let(:request) do
          do_index({
            include: "books",
            page: {books: {size: 1, number: 2}}
          })
        end

        context "and only 1 parent" do
          before do
            author2.destroy
          end

          it "works" do
            request
            expect(included("books").map(&:id)).to eq([book2.id])
          end
        end

        context "and > 1 parents" do
          it "raises error" do
            expect {
              begin
                request
              rescue => e
                raise e.cause
              end
            }.to raise_error(Graphiti::Errors::UnsupportedPagination)
          end
        end
      end

      it "allows sorting of sideloaded resource" do
        do_index({include: "books", sort: "-books.id"})
        expect(included("books").map(&:id)).to eq([book2.id, book1.id])
      end

      it "allows filtering of sideloaded resource" do
        do_index({include: "books", filter: {books: {id: book2.id}}})
        expect(included("books").map(&:id)).to eq([book2.id])
      end

      it "allows extra fields for sideloaded resource" do
        do_index({include: "books", extra_fields: {books: "alternate_title"}})
        book = included("books")[0]
        expect(book["title"]).to be_present
        expect(book["pages"]).to be_present
        expect(book["alternate_title"]).to eq("alt title")
      end

      it "allows sparse fieldsets for the sideloaded resource" do
        do_index({include: "books", fields: {books: "pages"}})
        book = included("books")[0]
        expect(book).to_not have_key("title")
        expect(book).to_not have_key("alternate_title")
        expect(book["pages"]).to eq(500)
      end

      it "allows extra fields and sparse fieldsets for the sideloaded resource" do
        do_index({include: "books", fields: {books: "pages"}, extra_fields: {books: "alternate_title"}})
        book = included("books")[0]
        expect(book).to have_key("pages")
        expect(book).to have_key("alternate_title")
        expect(book).to_not have_key("title")
      end

      context "when a custom inverse_filter is provided" do
        before do
          Legacy::AuthorResource.class_eval do
            has_many :books, inverse_filter: :some_author_id
          end
        end

        after do
          Legacy::AuthorResource.class_eval do
            has_many :books
          end
        end

        it "still works" do
          do_index({include: "books"})
          expect(included("books").map(&:id)).to eq([book1.id, book2.id])
        end
      end
    end

    context "sideloading belongs_to" do
      it "can sideload" do
        do_index({include: "state"})
        expect(included("states").map(&:id)).to eq([state.id])
      end

      it "allows extra fields for sideloaded resource" do
        do_index({include: "state", extra_fields: {states: "population"}})
        state = included("states")[0]
        expect(state["name"]).to be_present
        expect(state["abbreviation"]).to be_present
        expect(state["population"]).to be_present
      end

      it "allows sparse fieldsets for the sideloaded resource" do
        do_index({include: "state", fields: {states: "name"}})
        state = included("states")[0]
        expect(state["name"]).to be_present
        expect(state).to_not have_key("abbreviation")
        expect(state).to_not have_key("population")
      end

      it "allows extra fields and sparse fieldsets for the sideloaded resource" do
        do_index({include: "state", fields: {states: "name"}, extra_fields: {states: "population"}})
        state = included("states")[0]
        expect(state).to have_key("name")
        expect(state).to have_key("population")
        expect(state).to_not have_key("abbreviation")
      end
    end

    context "sideloading has_one" do
      it "can sideload" do
        do_index({include: "bio"})
        expect(included("bios").map(&:id)).to eq([bio.id])
      end

      it "allows extra fields for sideloaded resource" do
        do_index({include: "bio", extra_fields: {bios: "created_at"}})
        bio = included("bios")[0]
        expect(bio["description"]).to be_present
        expect(bio["created_at"]).to be_present
        expect(bio["picture"]).to be_present
      end

      it "allows sparse fieldsets for the sideloaded resource" do
        do_index({include: "bio", fields: {bios: "description"}})
        bio = included("bios")[0]
        expect(bio["description"]).to be_present
        expect(bio).to_not have_key("created_at")
        expect(bio).to_not have_key("picture")
      end

      it "allows extra fields and sparse fieldsets for the sideloaded resource" do
        do_index({include: "bio", fields: {bios: "description"}, extra_fields: {bios: "created_at"}})
        bio = included("bios")[0]
        expect(bio).to have_key("description")
        expect(bio).to have_key("created_at")
        expect(bio).to_not have_key("picture")
      end

      context "when no records found" do
        before do
          Legacy::Bio.delete_all
        end

        it "still uses the activerecord adapter, not the PORO adapter" do
          expect_any_instance_of(Legacy::Author).to_not receive(:bio=)
          do_index({include: "bio"})
          expect(json["data"][0]["relationships"]["bio"]["data"])
            .to be_nil
        end
      end

      # Model/Resource has has_one, but it's just a subset of a has_many
      context "when multiple records (faux-has_one)" do
        let!(:bio2) { Legacy::Bio.create!(author: author1, picture: "imgur", description: "author bio") }

        context "and there is another level of association" do
          before do
            bio.bio_labels << Legacy::BioLabel.create!
            bio2.bio_labels << Legacy::BioLabel.create!
          end

          it "still works" do
            do_index({include: "bio.bio_labels"})
            expect(included("bio_labels").length).to eq(1)
          end
        end
      end
    end

    context "sideloading many_to_many" do
      it "can sideload" do
        do_index({include: "hobbies"})
        expect(included("hobbies").map(&:id)).to eq([hobby1.id, hobby2.id])
      end

      it "allows sorting of sideloaded resource" do
        do_index({include: "hobbies", sort: "-hobbies.name"})
        expect(included("hobbies").map(&:id)).to eq([hobby2.id, hobby1.id])
      end

      it "allows filtering of sideloaded resource" do
        do_index({
          include: "hobbies",
          filter: {hobbies: {id: hobby2.id}}
        })
        expect(included("hobbies").map(&:id)).to eq([hobby2.id])
      end

      it "allows extra fields for sideloaded resource" do
        do_index({
          include: "hobbies",
          extra_fields: {hobbies: "reason"}
        })
        hobby = included("hobbies")[0]
        expect(hobby["name"]).to be_present
        expect(hobby["description"]).to be_present
        expect(hobby["reason"]).to eq("hobby reason")
      end

      it "allows sparse fieldsets for the sideloaded resource" do
        do_index({include: "hobbies", fields: {hobbies: "name"}})
        hobby = included("hobbies")[0]
        expect(hobby["name"]).to be_present
        expect(hobby).to_not have_key("description")
        expect(hobby).to_not have_key("reason")
      end

      it "allows extra fields and sparse fieldsets for the sideloaded resource" do
        do_index({
          include: "hobbies",
          fields: {hobbies: "name"},
          extra_fields: {hobbies: "reason"}
        })
        hobby = included("hobbies")[0]
        expect(hobby).to have_key("name")
        expect(hobby).to have_key("reason")
        expect(hobby).to_not have_key("description")
      end

      it "allows extra fields and sparse fieldsets for multiple resources" do
        do_index({
          include: "hobbies,books",
          fields: {hobbies: "name", books: "title"},
          extra_fields: {hobbies: "reason", books: "alternate_title"}
        })
        hobby = included("hobbies")[0]
        book = included("books")[0]
        expect(hobby).to have_key("name")
        expect(hobby).to have_key("reason")
        expect(hobby).to_not have_key("description")
        expect(book).to have_key("title")
        expect(book).to have_key("alternate_title")
        expect(book).to_not have_key("pages")
      end

      it "does not duplicate results" do
        do_index({include: "hobbies"})
        author1_relationships = json["data"][0]["relationships"]
        author2_relationships = json["data"][1]["relationships"]

        author1_hobbies = author1_relationships["hobbies"]["data"]
        author2_hobbies = author2_relationships["hobbies"]["data"]

        expect(included("hobbies").size).to eq(2)
        expect(author1_hobbies.size).to eq(2)
        expect(author2_hobbies.size).to eq(1)
      end

      context "when sideloads non-namespace model via a namespace model" do
        let(:shop) { Legacy::Sales::Shop.create(name: "shop") }

        before do
          allow(Legacy::Sales::ShopResource).to receive(:validate_endpoints?) { false }
          allow(controller).to receive(:resource).and_return(Legacy::Sales::ShopResource)
          Legacy::Sales::Stock.create(shop_id: shop.id, book_id: book1.id, amount: 2)
        end

        it "works" do
          do_index({include: "books"})
          expect(included("books").map(&:id)).to eq([book1.id])
        end
      end

      context "when configured as a has_many association" do
        before do
          @orig_sideload = Legacy::AuthorResource.sideloads.delete(:hobbies)
          @orig_filter = Legacy::HobbyResource.filters.delete(:author_id)
          @orig_attr = Legacy::HobbyResource.attributes.delete(:author_id)

          Legacy::AuthorResource.class_eval do
            has_many :hobbies
          end
        end

        after do
          Legacy::AuthorResource.sideloads[:hobbies] = @orig_sideload
          Legacy::HobbyResource.filters[:author_id] = @orig_filter
          Legacy::HobbyResource.attributes[:author_id] = @orig_attr
        end

        it "derives the foreign key directly" do
          expect {
            begin
              do_index({include: "hobbies"})
            rescue => e
              raise e.cause
            end
          }.to raise_error(Graphiti::Errors::AttributeError, /author_id/)
        end
      end

      context "when the association is self-referential" do
        before do
          Legacy::AuthorResource.class_eval do
            many_to_many :mentors,
              foreign_key: {mentee_joins: :mentee_id},
              resource: Legacy::AuthorResource

            many_to_many :mentees,
              foreign_key: {mentor_joins: :mentor_id},
              resource: Legacy::AuthorResource
          end
        end

        let!(:author_with_mentors) { Legacy::Author.create!(first_name: "Fred") }
        let!(:author_with_mentees) { Legacy::Author.create!(first_name: "George") }
        let!(:author_with_both) { Legacy::Author.create!(first_name: "Alice") }

        before do
          author_with_mentors.mentors = [author_with_mentees, author_with_both]
          author_with_mentees.mentees = [author_with_mentors, author_with_both]
        end

        it "still works" do
          do_index({include: "mentors"})
          target = d.find { |e| e.id == author_with_mentors.id }
          expect(target.relationships["mentors"]).to eq({
            "data" => [
              {"type" => "authors", "id" => author_with_mentees.id.to_s},
              {"type" => "authors", "id" => author_with_both.id.to_s}
            ]
          })
        end

        it "allows filtering by the association" do
          do_index({filter: {mentor_id: author_with_mentees.id}})

          expect(d.map(&:id)).to eq([author_with_mentors.id, author_with_both.id])
        end
      end

      context "when association name differs from source name" do
        before do
          Legacy::UserResource.class_eval do
            many_to_many :books, resource: Legacy::BookResource
          end
          allow(Legacy::BookResource).to receive(:validate_endpoints?) { false }
          allow(controller).to receive(:resource) { Legacy::BookResource }
        end

        after do
          Legacy::UserResource.sideloads.delete(:books)
        end

        let!(:reader) { Legacy::User.create!(books: [book2]) }

        it "correctly infers the filter name for the association from the inverse_of option" do
          do_index({filter: {reader_id: reader.id}})

          expect(d.map(&:id)).to eq([book2.id])
        end

        context "when the graphiti association manually sets inverse_filter" do
          before do
            Legacy::UserResource.class_eval do
              many_to_many :books, resource: Legacy::BookResource, inverse_filter: :the_reader_id
            end
          end

          it "overrides the inferred one" do
            do_index({filter: {the_reader_id: reader.id}})

            expect(d.map(&:id)).to eq([book2.id])
          end
        end
      end

      context "when the table name does not match the association name" do
        before do
          @orig_filter = Legacy::HobbyResource.filters.delete(:author_id)
          Legacy::AuthorHobby.table_name = :author_hobby
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        after do
          Legacy::HobbyResource.filters[:author_id] = @orig_filter
          Legacy::AuthorHobby.table_name = :author_hobbies
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        let!(:other_table_hobby1) { Legacy::Hobby.create!(name: "Fishing", authors: [author1]) }
        let!(:other_table_hobby2) { Legacy::Hobby.create!(name: "Woodworking", authors: [author1, author2]) }

        it "still works" do
          do_index({include: "hobbies"})
          expect(included("hobbies").map(&:id))
            .to eq([other_table_hobby1.id, other_table_hobby2.id])
        end
      end

      context "when filter already exists and it is wrong" do
        let(:existing_filter) {
          {
            aliases: [:author_id],
            name: :author_id,
            type: :integer_id,
            allow: nil,
            deny: nil,
            single: false,
            dependencies: nil,
            required: false,
            operators:
              {eq: nil, not_eq: nil, gt: nil, gte: nil, lt: nil, lte: nil},
            allow_nil: false,
            deny_empty: false
          }
        }

        before do
          @orig_filter = Legacy::HobbyResource.filters[:author_id]
          Legacy::HobbyResource.filters[:author_id] = existing_filter
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
          Legacy::AuthorHobby.class_eval do
            belongs_to :author
            belongs_to :hobby
          end
          Legacy::AuthorHobby.table_name = :author_hobby
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        after do
          Legacy::HobbyResource.filters[:author_id] = @orig_filter
          Legacy::AuthorHobby.table_name = :author_hobbies
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        it "does not recreate the filter so it raises an error" do
          expect { do_index({include: "hobbies"}) }.to raise_error(ActiveRecord::StatementInvalid)
        end
      end

      context "when a custom inverse_filter is provided" do
        before do
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies, inverse_filter: :the_id_of_the_author
          end
        end

        after do
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        it "still works" do
          do_index({include: "hobbies"})
          expect(included("hobbies").map(&:id)).to eq([hobby1.id, hobby2.id])
        end

        describe "filtering relationship" do
          controller(ApplicationController) do
            def index
              records = Legacy::HobbyResource.all(params)
              render jsonapi: records
            end
          end

          before do
            allow(controller.request.env).to receive(:[])
              .with("PATH_INFO") { "/legacy/hobbies" }
          end

          it "can filter the relationship by the custom name" do
            do_index(filter: {the_id_of_the_author: [author1.id, author2.id].join(",")})
            expect(d.map(&:id)).to eq([hobby1.id, hobby2.id])
          end
        end
      end

      context "when polymorphic many-to-many" do
        let(:tag1) { Legacy::Tag.create!(name: "One") }
        let(:tag2) { Legacy::Tag.create!(name: "Two") }

        context "when authors" do
          before do
            author1.tags << tag1
            author2.tags << tag1
            author2.tags << tag2
          end

          it "still works" do
            do_index({include: "tags"})
            sl = d[0].sideload(:tags)
            expect(sl.map(&:id)).to eq([tag1.id])
            sl = d[1].sideload(:tags)
            expect(sl.map(&:id)).to eq([tag1.id, tag2.id])
          end
        end

        context "when books" do
          before do
            book1.tags << tag1
            book1.tags << tag2
            book2.tags << tag1
          end

          it "still works" do
            allow(Legacy::BookResource).to receive(:validate_endpoints?) { false }
            allow(controller).to receive(:resource) { Legacy::BookResource }
            do_index({include: "tags"})
            sl = d[0].sideload(:tags)
            expect(sl.map(&:id)).to eq([tag1.id, tag2.id])
            sl = d[1].sideload(:tags)
            expect(sl.map(&:id)).to eq([tag1.id])
          end
        end

        if ::Rails::VERSION::MAJOR >= 5
          context "when both" do
            let(:tag3) { Legacy::Tag.create!(name: "Three") }

            before do
              author1.tags << tag1
              book2.tags << tag2
              book2.tags << tag3
            end

            it "still works" do
              allow(Legacy::TagResource).to receive(:validate_endpoints?) { false }
              allow(controller).to receive(:resource) { Legacy::TagResource }
              do_index({
                filter: {
                  taggable_id: [
                    {id: author1.id, type: author1.class.name}.to_json,
                    {id: book2.id, type: book2.class.name}.to_json
                  ]
                }
              })
              expect(d.map(&:name)).to eq(%w[One Two Three])
            end
          end
        end
      end
    end

    context "sideloading self-referential" do
      it "works" do
        do_index({include: "organization.children"})
        includes = included("organizations")
        expect(includes[0]["name"]).to eq("Org1")
        expect(includes[1]["name"]).to eq("Org2")
      end
    end

    context 'sideloading the same "type", then adding another sideload' do
      before do
        Legacy::Author.class_eval do
          has_many :other_books, class_name: "Book"
        end

        Legacy::AuthorResource.class_eval do
          has_many :other_books,
            foreign_key: :author_id,
            resource: Legacy::BookResource
        end
      end

      it "works" do
        book2.genre = Legacy::Genre.create! name: "Comedy"
        book2.save!
        do_index({
          filter: {books: {id: book1.id}, other_books: {id: book2.id}},
          include: "books.genre,other_books.genre"
        })
        expect(included("genres").length).to eq(2)
      end
    end

    context "sideloading polymorphic belongs_to" do
      it "allows extra fields for the sideloaded resource" do
        do_index({
          include: "dwelling",
          extra_fields: {houses: "house_price", condos: "condo_price"}
        })
        house = included("houses")[0]
        expect(house["name"]).to be_present
        expect(house["house_description"]).to be_present
        expect(house["house_price"]).to eq(1_000_000)
        condo = included("condos")[0]
        expect(condo["name"]).to be_present
        expect(condo["condo_description"]).to be_present
        expect(condo["condo_price"]).to eq(500_000)
      end

      it "allows sparse fieldsets for the sideloaded resource" do
        do_index({
          include: "dwelling",
          fields: {houses: "name", condos: "condo_description"}
        })
        house = included("houses")[0]
        expect(house["name"]).to be_present
        expect(house).to_not have_key("house_description")
        expect(house).to_not have_key("house_price")
        condo = included("condos")[0]
        expect(condo["condo_description"]).to be_present
        expect(condo).to_not have_key("name")
        expect(condo).to_not have_key("condo_price")
      end

      it "allows extra fields and sparse fieldsets for the sideloaded resource" do
        do_index({
          include: "dwelling",
          fields: {houses: "name", condos: "condo_description"},
          extra_fields: {houses: "house_price", condos: "condo_price"}
        })
        house = included("houses")[0]
        condo = included("condos")[0]
        expect(house).to have_key("name")
        expect(house).to have_key("house_price")
        expect(house).to_not have_key("house_description")
        expect(condo).to have_key("condo_description")
        expect(condo).to have_key("condo_price")
        expect(condo).to_not have_key("name")
      end

      # NB: Condo does NOT have a state relationship
      it "allows additional levels of nesting" do
        do_index({include: "dwelling.state"})
        expect(included("states").length).to eq(1)
      end
    end

    context "when select statement is specified" do
      before do
        Legacy::AuthorResource.class_eval do
          def base_scope
            Legacy::Author.select("*", "id as id_1")
          end
        end
      end

      it "can query stats total count" do
        do_index({stats: {total: "count"}})
        expect(d.map(&:id)).to eq([author1.id, author2.id])
      end
    end
  end
end
