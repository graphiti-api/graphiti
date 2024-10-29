require "spec_helper"

RSpec.describe Graphiti::Query do
  let(:employee_resource) { Class.new(PORO::EmployeeResource) }
  let(:position_resource) { Class.new(PORO::PositionResource) }
  let(:department_resource) { Class.new(PORO::DepartmentResource) }
  let(:resource) { employee_resource.new }
  let(:params) { {} }
  let(:instance) { described_class.new(resource, params) }

  before do
    employee_resource.has_many :positions,
      resource: position_resource
    employee_resource.belongs_to :remote, remote: true
    position_resource.belongs_to :department,
      resource: department_resource
    employee_resource.attribute :name, :string
    position_resource.attribute :title, :string
    position_resource.attribute :rank, :integer
    department_resource.attribute :description, :string
  end

  describe "#hash" do
    subject(:hash) { instance.hash }

    before do
      params[:include] = "positions.department"
    end

    describe "includes" do
      let(:expected) do
        {
          positions: {include: {department: {}}}
        }
      end

      it "parses correctly" do
        expect(hash[:include]).to eq(expected)
      end

      context "when stringified keys" do
        before do
          params.deep_stringify_keys!
        end

        it "works" do
          expect(hash[:include]).to eq(expected)
        end
      end

      context "when context has sideload allowlist" do
        let(:ctx) do
          OpenStruct.new(sideload_allowlist: {update: {positions: {}}})
        end

        around do |e|
          Graphiti.with_context ctx, :update do
            e.run
          end
        end

        it "removes invalid includes" do
          expect(hash).to eq(include: {positions: {}})
        end
      end

      context "when context does not respond to #sideload_allowlist" do
        before do
          params[:include] = "positions.department"
        end

        let(:ctx) { OpenStruct.new }

        around do |e|
          Graphiti.with_context ctx, :update do
            e.run
          end
        end

        it "still works" do
          expect(hash).to eq({
            include: {
              positions: {
                include: {
                  department: {}
                }
              }
            }
          })
        end
      end

      context "when invalid" do
        before do
          params[:include] = "foo"
        end

        it "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::InvalidInclude)
        end

        context "but the config says not to raise" do
          before do
            params[:include] = "foo,positions"
            Graphiti.config.raise_on_missing_sideload = false
          end

          it "does not raise" do
            expect {
              hash
            }.to_not raise_error
            expect(hash).to eq(include: {positions: {}})
          end
        end
      end
    end

    describe "filters" do
      context "when unknown attribute" do
        before do
          params[:filter] = {asdf: "adsf"}
        end

        it "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to filter on attribute :asdf, but could not find an attribute with that name.")
        end

        context "on an association" do
          context "via type" do
            before do
              params[:filter] = {departments: {via_type: "asdf"}}
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to filter on attribute :via_type, but could not find an attribute with that name.")
            end
          end

          context "via name" do
            before do
              params[:filter] = {department: {via_name: "asdf"}}
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to filter on attribute :via_name, but could not find an attribute with that name.")
            end
          end
        end
      end

      context "when known unfilterable attribute" do
        before do
          employee_resource.attribute :asdf, :string, filterable: false
          params[:filter] = {asdf: "adsf"}
        end

        it "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to filter on attribute :asdf, but the attribute was marked :filterable => false.")
        end

        context "on an association" do
          context "via type" do
            before do
              params[:filter] = {departments: {via_type: "asdf"}}
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to filter on attribute :via_type, but could not find an attribute with that name.")
            end
          end

          context "via name" do
            before do
              department_resource.attribute :via_name, :string, filterable: false
              params[:filter] = {department: {via_name: "asdf"}}
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to filter on attribute :via_name, but the attribute was marked :filterable => false.")
            end
          end
        end
      end

      context "via type" do
        before do
          params[:filter] = {
            name: "foo",
            positions: {title: "bar"},
            departments: {description: "baz"}
          }
        end

        let(:expected) do
          {
            filter: {name: "foo"},
            include: {
              positions: {
                filter: {title: "bar"},
                include: {
                  department: {
                    filter: {description: "baz"}
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "with stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "parses correctly" do
            expect(hash).to eq(expected)
          end
        end
      end

      context "via association name" do
        # department vs departments
        before do
          params[:filter] = {
            name: "foo",
            positions: {title: "bar"},
            department: {description: "baz"}
          }
        end

        let(:expected) do
          {
            filter: {name: "foo"},
            include: {
              positions: {
                filter: {title: "bar"},
                include: {
                  department: {
                    filter: {description: "baz"}
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "with multiple filters" do
          before do
            params[:filter][:positions][:id] = 4
          end

          it "keeps both filters" do
            expect(hash[:include][:positions][:filter])
              .to eq(title: "bar", id: 4)
          end
        end

        context "with stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "parses correctly" do
            expect(hash).to eq(expected)
          end
        end
      end

      context "via relationship name dot syntax" do
        before do
          params[:filter] = {'positions.title': {eq: "asdf"}}
        end

        let(:expected) do
          {
            include: {
              positions: {
                filter: {title: {eq: "asdf"}},
                include: {
                  department: {}
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "when multiple levels" do
          before do
            params[:filter] = {'positions.department.name': {eq: "asdf"}}
          end

          let(:expected) do
            {
              include: {
                positions: {
                  include: {
                    department: {
                      filter: {name: {eq: "asdf"}}
                    }
                  }
                }
              }
            }
          end

          it "parses correctly" do
            expect(hash).to eq(expected)
          end
        end

        context "with stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "parses correctly" do
            expect(hash).to eq(expected)
          end
        end
      end
    end

    describe "sorts" do
      context "when unknown attribute" do
        before do
          params[:sort] = "asdf"
        end

        it "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :asdf, but could not find an attribute with that name.")
        end

        context "on association" do
          context "by type" do
            before do
              params[:sort] = "departments.by_type"
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :by_type, but could not find an attribute with that name.")
            end
          end

          context "by name" do
            before do
              params[:sort] = "department.by_name"
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :by_name, but could not find an attribute with that name.")
            end
          end
        end
      end

      context "when known unsortable attribute" do
        before do
          employee_resource.attribute :foo, :string, sortable: false
          params[:sort] = "foo"
        end

        it "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :foo, but the attribute was marked :sortable => false.")
        end

        context "on association" do
          context "via type" do
            before do
              params[:sort] = "departments.by_type"
              department_resource.attribute :by_type, :string, sortable: false
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :by_type, but the attribute was marked :sortable => false.")
            end
          end

          context "via name" do
            before do
              params[:sort] = "department.by_name"
              department_resource.attribute :by_name, :string, sortable: false
            end

            it "raises error" do
              expect {
                hash
              }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :by_name, but the attribute was marked :sortable => false.")
            end
          end
        end
      end

      context "via type" do
        before do
          params[:sort] = "name,positions.title,-positions.rank,-departments.description"
        end

        let(:expected) do
          {
            sort: [{name: :asc}],
            include: {
              positions: {
                sort: [{title: :asc}, {rank: :desc}],
                include: {
                  department: {
                    sort: [{description: :desc}]
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "and stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "parses correctly" do
            expect(hash).to eq(expected)
          end
        end
      end

      context "via name" do
        before do
          params[:sort] = "name,positions.title,-positions.rank,-department.description"
        end

        let(:expected) do
          {
            sort: [{name: :asc}],
            include: {
              positions: {
                sort: [{title: :asc}, {rank: :desc}],
                include: {
                  department: {
                    sort: [{description: :desc}]
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "and stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "parses correctly" do
            expect(hash).to eq(expected)
          end
        end
      end

      context "via nested dot syntax" do
        before do
          params[:sort] = "-positions.department.name"
        end

        let(:expected) do
          {
            include: {
              positions: {
                include: {
                  department: {
                    sort: [{name: :desc}]
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end
      end
    end

    describe "pagination" do
      context "via type" do
        before do
          params[:page] = {
            number: 2, size: 1,
            positions: {number: 3, size: 2},
            departments: {number: 4, size: 3}
          }
        end

        let(:expected) do
          {
            page: {number: 2, size: 1},
            include: {
              positions: {
                page: {number: 3, size: 2},
                include: {
                  department: {
                    page: {number: 4, size: 3}
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "and stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "still works" do
            expect(hash).to eq(expected)
          end
        end
      end

      context "via association name" do
        before do
          params[:page] = {
            number: 2, size: 1,
            positions: {number: 3, size: 2},
            department: {number: 4, size: 3}
          }
        end

        let(:expected) do
          {
            page: {number: 2, size: 1},
            include: {
              positions: {
                page: {number: 3, size: 2},
                include: {
                  department: {
                    page: {number: 4, size: 3}
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "and stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "still works" do
            expect(hash).to eq(expected)
          end
        end
      end

      context "via dot syntax" do
        before do
          params[:page] = {
            number: 2, size: 1,
            'positions.size': 2,
            'positions.number': 3,
            'positions.department.size': 3,
            'positions.department.number': 4
          }
        end

        let(:expected) do
          {
            page: {number: 2, size: 1},
            include: {
              positions: {
                page: {number: 3, size: 2},
                include: {
                  department: {
                    page: {number: 4, size: 3}
                  }
                }
              }
            }
          }
        end

        it "works" do
          expect(hash).to eq(expected)
        end
      end
    end

    describe "fieldsets" do
      context "when unknown attribute" do
        before do
          params[:fields] = {employees: "asdf"}
        end

        it "raises error" do
          # expect {
          hash
          # }.to raise_error(Graphiti::Errors::AttributeError, 'AnonymousResourceClass: Tried to read attribute :asdf, but could not find an attribute with that name.')
        end
      end

      context "when known but unreadable attribute" do
        before do
          employee_resource.attribute :first_name, :string, readable: false
          params[:fields] = {employees: "first_name"}
        end

        xit "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to read attribute :first_name, but the attribute was marked :readable => false.")
        end
      end

      context "via type" do
        before do
          params[:fields] = {
            employees: "first_name,last_name",
            positions: "title",
            departments: "description"
          }
        end

        let(:expected) do
          {
            fields: {
              employees: [:first_name, :last_name],
              positions: [:title],
              departments: [:description]
            },
            include: {
              positions: {
                include: {
                  department: {}
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "and stringified keys" do
          it "still works" do
            expect(hash).to eq(expected)
          end
        end
      end
    end

    describe "extra fields" do
      context "when unknown extra_attribute" do
        before do
          params[:extra_fields] = {employees: "asdf"}
        end

        xit "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to read attribute :asdf, but could not find an attribute with that name.")
        end
      end

      context "when known but unreadable attribute" do
        before do
          employee_resource.attribute :first_name, :string, readable: false
          params[:extra_fields] = {employees: "first_name"}
        end

        xit "raises error" do
          expect {
            hash
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to read attribute :first_name, but the attribute was marked :readable => false.")
        end
      end

      context "via type" do
        before do
          params[:extra_fields] = {
            employees: "foo,bar",
            positions: "baz",
            departments: "bax"
          }
        end

        let(:expected) do
          {
            extra_fields: {
              employees: [:foo, :bar],
              positions: [:baz],
              departments: [:bax]
            },
            include: {
              positions: {
                extra_fields: {positions: [:baz]},
                include: {
                  department: {
                    extra_fields: {departments: [:bax]}
                  }
                }
              }
            }
          }
        end

        it "parses correctly" do
          expect(hash).to eq(expected)
        end

        context "and stringified keys" do
          before do
            params.deep_stringify_keys!
          end

          it "still works" do
            expect(hash).to eq(expected)
          end
        end
      end
    end

    context "when fields are also present" do
      before do
        params[:fields] = {
          employees: "foo,bar"
        }
        params[:extra_fields] = {
          employees: "baz,bax"
        }
      end

      it "adds extra fields to fields" do
        expect(hash).to eq({
          fields: {
            employees: [:foo, :bar, :baz, :bax]
          },
          extra_fields: {
            employees: [:baz, :bax]
          },
          include: {
            positions: {
              include: {
                department: {}
              }
            }
          }
        })
      end
    end

    describe "stats" do
      before do
        params[:stats] = {total: "count"}
      end

      let(:expected) do
        {
          stats: {total: [:count]},
          include: {
            positions: {
              include: {
                department: {}
              }
            }
          }
        }
      end

      it "parses correctly" do
        expect(hash).to eq(expected)
      end

      context "when stringified keys" do
        before do
          params.deep_stringify_keys!
        end

        it "still works" do
          expect(hash).to eq(expected)
        end
      end

      context "when multiple" do
        before do
          params[:stats] = {total: "count,sum"}
        end

        it "works" do
          expect(hash[:stats]).to eq(total: [:count, :sum])
        end
      end

      context "when association" do
        before do
          params[:stats] = {positions: {total: :count}}
        end

        it "raises error" do
          expect {
            hash
          }.to raise_error(NotImplementedError, "Association statistics are not currently supported")
        end
      end
    end
  end

  describe "#paginate?" do
    subject { instance.paginate? }

    context "when given boolean" do
      context "when true" do
        before do
          params[:paginate] = true
        end

        it { is_expected.to eq(true) }
      end

      context "when false" do
        before do
          params[:paginate] = false
        end

        it { is_expected.to eq(false) }
      end
    end

    context "when given string" do
      context "when true" do
        before do
          params[:paginate] = "true"
        end

        it { is_expected.to eq(true) }
      end

      context "when false" do
        before do
          params[:paginate] = "false"
        end

        it { is_expected.to eq(false) }
      end
    end
  end

  describe "#links?" do
    subject { instance.links? }

    it { is_expected.to eq(true) }

    context "when xml" do
      before do
        params[:format] = "xml"
      end

      it { is_expected.to eq(false) }
    end

    context "when simple json" do
      before do
        params[:format] = "json"
      end

      it { is_expected.to eq(false) }
    end

    context "when links_on_demand" do
      around do |e|
        original = Graphiti.config.links_on_demand
        begin
          Graphiti.config.links_on_demand = true
          e.run
        ensure
          Graphiti.config.links_on_demand = original
        end
      end

      context "and requested" do
        context "as string" do
          before do
            params[:links] = "true"
          end

          it { is_expected.to eq(true) }
        end

        context "as boolean" do
          before do
            params[:links] = "true"
          end

          it { is_expected.to eq(true) }
        end
      end

      context "and not requested in url" do
        it { is_expected.to eq(false) }
      end
    end
  end

  describe "#action" do
    subject { instance.action }
    let(:provided_action) { :create }

    context "when provided explicitly" do
      let(:instance) { described_class.new(resource, params, nil, nil, [], provided_action) }
      it { is_expected.to eq(provided_action) }

      context "and the action provided is show" do
        let(:provided_action) { :show }
        it { is_expected.to eq(:find) }
      end

      context "and the action provided is index" do
        let(:provided_action) { :index }
        it { is_expected.to eq(:all) }
      end
    end

    context "when not provided, but provided as an 'action' parameter" do
      before { params[:action] = provided_action }
      it { is_expected.to eq(provided_action) }
    end

    context "when not provided, it defaults to the context's namespace" do
      around do |e|
        Graphiti.with_context nil, provided_action do
          e.run
        end
      end
      it { is_expected.to eq(provided_action) }
    end

    describe "sideloads" do
      subject(:sideloads) { instance.sideloads }

      context "when including an has_many resource" do
        before { params[:include] = "positions" }

        it "does not cascate the action" do
          expect(sideloads.values.map(&:action)).to eq([:all])
        end
      end

      context "when including a resource from a remote resource" do
        before { params[:include] = "remote.resource" }

        let(:sideloads_of_another_query) { described_class.new(resource, params).sideloads }

        def resource_class_of_remote_sideload(sideloads)
          sideloads.fetch(:remote).sideloads.fetch(:resource).resource.class
        end

        it "re-uses resource class across multiple queries (avoid memory leak)" do
          expect(resource_class_of_remote_sideload(sideloads))
            .to eq(resource_class_of_remote_sideload(sideloads_of_another_query))
        end
      end
    end
  end

  describe "#pagination_links?" do
    subject { instance.pagination_links? }
    let(:pagination_links) { Graphiti.config.pagination_links }
    let(:pagination_links_on_demand) { Graphiti.config.pagination_links_on_demand }

    around do |e|
      original_pagination_links = Graphiti.config.pagination_links
      original_pagination_links_on_demand = Graphiti.config.pagination_links_on_demand
      Graphiti.config.pagination_links = pagination_links
      Graphiti.config.pagination_links_on_demand = pagination_links_on_demand
      begin
        e.run
      ensure
        Graphiti.config.pagination_links = original_pagination_links
        Graphiti.config.pagination_links_on_demand = original_pagination_links_on_demand
      end
    end

    context "when pagination_links_on_demand" do
      let(:pagination_links_on_demand) { true }

      context "when params ask for pagination" do
        let(:params) { {pagination_links: true} }

        it { is_expected.to eq(true) }
      end

      context "when params dont ask pagination" do
        it { is_expected.to eq(false) }
      end
    end

    context "when action is equal to find" do
      let(:params) { {action: "show"} }
      let(:pagination_links_on_demand) { false }

      it { is_expected.to eq(false) }

      context "when pagination_links_on_demand and param is present" do
        let(:params) { {action: "show", pagination_links: true} }
        let(:pagination_links_on_demand) { true }

        it { is_expected.to eq(false) }
      end
    end

    context "when action is equal to all" do
      let(:params) { {action: "index"} }
      let(:pagination_links_on_demand) { false }

      context "when is equal config.pagination_links is true" do
        let(:pagination_links) { true }

        it { is_expected.to eq(true) }
      end

      context "when is equal config.pagination_links is false" do
        let(:pagination_links) { false }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe "cache_key" do
    it "generates a stable key" do
      instance1 = described_class.new(resource, params)
      instance2 = described_class.new(resource, params)

      expect(instance1.cache_key).to be_present
      expect(instance1.cache_key).to eq(instance2.cache_key)
    end

    it "generates a different key with different params" do
      instance1 = described_class.new(resource, params)
      instance2 = described_class.new(resource, {extra_fields: {positions: ["foo"]}})

      expect(instance1.cache_key).to be_present
      expect(instance2.cache_key).to be_present
      expect(instance1.cache_key).not_to eq(instance2.cache_key)
    end
  end
end
