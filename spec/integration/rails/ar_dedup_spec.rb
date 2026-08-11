if ENV["APPRAISAL_INITIALIZED"]
  require "rails_spec_helper"

  module DedupTest
    DB_PATH = File.expand_path("../../tmp/dedup_probe.sqlite3", __dir__)
  end

  # Two sideloads write to the same record from different threads. That only works because Ruby runs one thread at a time, so this test fails if that ever changes.
  RSpec.describe "dedup against ActiveRecord's association cache" do
    include ConcurrencyHarness

    before(:all) do
      base = FileBackedDatabase.connect(DedupTest, DedupTest::DB_PATH, pool: 10)

      base.connection.create_table(:dedup_parents, force: true) { |t| t.string :name }
      base.connection.create_table(:dedup_children, force: true) do |t|
        t.integer :dedup_parent_id
        t.string :kind
      end

      DedupTest.const_set(:Child, Class.new(base) {
        self.table_name = "dedup_children"
      })
      DedupTest.const_set(:Parent, Class.new(base) {
        self.table_name = "dedup_parents"
        has_many :alphas, -> { where(kind: "alpha") }, class_name: "DedupTest::Child", foreign_key: :dedup_parent_id
        has_many :betas, -> { where(kind: "beta") }, class_name: "DedupTest::Child", foreign_key: :dedup_parent_id
      })

      DedupTest.const_set(:ChildResource, Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = DedupTest::Child
        self.type = :dedup_children
        attribute :dedup_parent_id, :integer, only: [:filterable]
        attribute :kind, :string
      })
      DedupTest.const_set(:ParentResource, Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = DedupTest::Parent
        self.type = :dedup_parents
        attribute :name, :string
        has_many :alphas, resource: DedupTest::ChildResource, foreign_key: :dedup_parent_id
        has_many :betas, resource: DedupTest::ChildResource, foreign_key: :dedup_parent_id
      })

      60.times do |index|
        parent = DedupTest::Parent.create!(name: "p#{index}")
        2.times { DedupTest::Child.create!(dedup_parent_id: parent.id, kind: "alpha") }
        2.times { DedupTest::Child.create!(dedup_parent_id: parent.id, kind: "beta") }
      end
    end

    after(:all) do
      FileBackedDatabase.disconnect(DedupTest, DedupTest::DB_PATH,
        %i[ParentResource ChildResource Child Parent])
    end

    before do
      allow(Graphiti.config).to receive(:concurrency).and_return(true)
      with_thread_pool(max_threads: 4)
    end

    it "keeps both sibling associations on every shared instance" do
      damaged = []

      8.times do |run|
        parents = DedupTest::ParentResource.all(page: {size: 60}, include: "alphas,betas").to_a
        parents.each do |parent|
          cache = parent.instance_variable_get(:@association_cache) || {}
          loaded = cache.keys.sort
          damaged << [run, parent.id, loaded] unless loaded == [:alphas, :betas]
        end
      end

      expect(damaged).to be_empty, "lost associations on #{damaged.size} parents, e.g. #{damaged.first(3).inspect}"
    end
  end
end
