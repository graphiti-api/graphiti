require "spec_helper"

RSpec.describe Graphiti::SpecHelpers::Matchers do
  include Graphiti::SpecHelpers::Matchers

  let(:author_resource) do
    Class.new(PORO::ApplicationResource) do
      def self.name
        "AuthorResource"
      end

      # belongs_to infers its foreign key from the related resource's model.
      self.model = PORO::Employee

      attribute :name, :string
    end
  end

  let(:post_resource) do
    author = author_resource
    Class.new(PORO::ApplicationResource) do
      def self.name
        "PostResource"
      end

      # Asserting on foreign_key makes the sideload infer one from the model,
      # which an anonymous resource has no way to find.
      self.model = PORO::Employee

      attribute :title, :string, sortable: false
      filter :body, :string, blanks: :null

      belongs_to :author, resource: author
      has_many :comments, resource: author
      has_one :summary, resource: author
    end
  end

  subject(:resource) { post_resource.new }

  describe "#belong_to_resource" do
    it { is_expected.to belong_to_resource(:author) }

    it "fails on an unknown relationship" do
      expect(resource).not_to belong_to_resource(:nope)
    end

    it "fails when the relationship is a different type" do
      expect(resource).not_to belong_to_resource(:comments)
    end

    it "matches on options" do
      expect(resource).to belong_to_resource(:author)
        .with_options(resource: author_resource)
    end

    it "fails when an option does not match" do
      expect(resource).not_to belong_to_resource(:author)
        .with_options(foreign_key: :wrong_id)
    end

    it "matches on options backed by predicate methods" do
      expect(resource).to belong_to_resource(:author)
        .with_options(readable: true, writable: true, single: false)
    end

    it "fails when a predicate-backed option does not match" do
      expect(resource).not_to belong_to_resource(:author)
        .with_options(readable: false)
    end
  end

  describe "#have_many_resources" do
    it { is_expected.to have_many_resources(:comments) }

    it "fails when the relationship is a different type" do
      expect(resource).not_to have_many_resources(:author)
    end
  end

  describe "#have_one_resource" do
    it { is_expected.to have_one_resource(:summary) }

    it "fails when the relationship is a different type" do
      expect(resource).not_to have_one_resource(:comments)
    end
  end

  describe "#expose_attribute" do
    it { is_expected.to expose_attribute(:title, :string) }

    it "fails on an unknown attribute" do
      expect(resource).not_to expose_attribute(:nope, :string)
    end

    it "fails on the wrong type" do
      expect(resource).not_to expose_attribute(:title, :integer)
    end

    it "matches on options" do
      expect(resource).to expose_attribute(:title, :string)
        .with_options(sortable: false)
    end

    it "fails when an option does not match" do
      expect(resource).not_to expose_attribute(:title, :string)
        .with_options(sortable: true)
    end
  end

  describe "#filter_attribute" do
    it { is_expected.to filter_attribute(:body, :string) }

    it "fails on an unknown filter" do
      expect(resource).not_to filter_attribute(:nope, :string)
    end

    it "matches on options" do
      expect(resource).to filter_attribute(:body, :string)
        .with_options(blanks: :null)
    end

    it "fails when an option does not match" do
      expect(resource).not_to filter_attribute(:body, :string)
        .with_options(blanks: :literal)
    end
  end

  describe "failure messages" do
    it "names the resource and the expectation" do
      matcher = belong_to_resource(:nope)
      matcher.matches?(resource)

      expect(matcher.failure_message)
        .to include(post_resource.to_s, "belong to", "nope")
    end

    it "reports which option did not match" do
      matcher = expose_attribute(:title, :string).with_options(sortable: true)
      matcher.matches?(resource)

      expect(matcher.failure_message)
        .to include("expected that sortable would be true, was false")
    end
  end
end
