if ENV["APPRAISAL_INITIALIZED"]
  require "rails_spec_helper"

  RSpec.describe "cache keys over a resolved graph" do
    include ConcurrencyHarness

    before(:all) do
      @db_path = File.expand_path("../../tmp/cache_key_probe.sqlite3", __dir__)
      FileUtils.mkdir_p(File.dirname(@db_path))
      FileUtils.rm_f(@db_path)
      Object.const_set(:CacheRecord, Class.new(ActiveRecord::Base) { self.abstract_class = true })
      CacheRecord.establish_connection(adapter: "sqlite3", database: @db_path, pool: 10, timeout: 5000)

      CacheRecord.connection.create_table(:cache_parents, force: true) { |t|
        t.string :name
        t.timestamps
      }
      CacheRecord.connection.create_table(:cache_children, force: true) do |t|
        t.integer :cache_parent_id
        t.string :name
        t.timestamps
      end
      CacheRecord.connection.create_table(:cache_grandchildren, force: true) do |t|
        t.integer :cache_child_id
        t.string :name
        t.timestamps
      end

      Object.const_set(:CacheGrandchild, Class.new(CacheRecord) { self.table_name = "cache_grandchildren" })
      Object.const_set(:CacheChild, Class.new(CacheRecord) {
        self.table_name = "cache_children"
        has_many :cache_grandchildren, class_name: "CacheGrandchild", foreign_key: :cache_child_id
      })
      Object.const_set(:CacheParent, Class.new(CacheRecord) {
        self.table_name = "cache_parents"
        has_many :cache_children, class_name: "CacheChild", foreign_key: :cache_parent_id
        has_many :ghosts, class_name: "CacheChild", foreign_key: :cache_parent_id
      })

      Object.const_set(:CacheGrandchildResource, Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = CacheGrandchild
        self.type = :cache_grandchildren
        attribute :cache_child_id, :integer, only: [:filterable]
        attribute :name, :string
      })
      Object.const_set(:CacheChildResource, Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = CacheChild
        self.type = :cache_children
        attribute :cache_parent_id, :integer, only: [:filterable]
        attribute :name, :string
        has_many :cache_grandchildren,
          resource: CacheGrandchildResource,
          foreign_key: :cache_child_id
      })
      Object.const_set(:CacheParentResource, Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = CacheParent
        self.type = :cache_parents
        attribute :name, :string
        has_many :cache_children,
          resource: CacheChildResource,
          foreign_key: :cache_parent_id

        # Assigns nothing back to its parents, so the association reader on a
        # parent lazy-loads instead of returning what the sideload resolved.
        has_many :ghosts, resource: CacheChildResource, foreign_key: :cache_parent_id do
          assign do |parents, children|
            children.each(&:name)
          end
        end
      })

      3.times do |i|
        parent = CacheParent.create!(name: "p#{i}")
        2.times do |j|
          child = CacheChild.create!(cache_parent_id: parent.id, name: "c#{i}#{j}")
          2.times { |k| CacheGrandchild.create!(cache_child_id: child.id, name: "g#{i}#{j}#{k}") }
        end
      end
    end

    after(:all) do
      CacheRecord.remove_connection
      FileUtils.rm_f(@db_path)
      %i[
        CacheParentResource CacheChildResource CacheGrandchildResource
        CacheParent CacheChild CacheGrandchild CacheRecord
      ].each do |name|
        Object.send(:remove_const, name) if Object.const_defined?(name)
      end
    end

    def proxy(include:)
      CacheParentResource.all(page: {size: 10}, include: include)
    end

    def etag_after_render(include:)
      rendered = proxy(include: include)
      rendered.to_jsonapi
      rendered.cache_key_with_version
    end

    def etag_without_render(include:)
      proxy(include: include).cache_key_with_version
    end

    [false, true].each do |concurrency|
      context "with concurrency #{concurrency}" do
        before do
          allow(Graphiti.config).to receive(:concurrency).and_return(concurrency)
          with_thread_pool(max_threads: 4) if concurrency
        end

        it "computes the same key whether or not the graph was resolved first" do
          expect(etag_after_render(include: "cache_children.cache_grandchildren"))
            .to eq(etag_without_render(include: "cache_children.cache_grandchildren"))
        end

        it "changes the key when a sideloaded record changes" do
          before_touch = etag_after_render(include: "cache_children")
          CacheChild.first.touch
          expect(etag_after_render(include: "cache_children")).not_to eq(before_touch)
        end

        it "changes the key when a record two levels down changes" do
          before_touch = etag_after_render(include: "cache_children.cache_grandchildren")
          CacheGrandchild.last.touch
          expect(etag_after_render(include: "cache_children.cache_grandchildren")).not_to eq(before_touch)
        end

        it "changes the key when a sideload whose assign writes nothing back changes" do
          before_touch = etag_after_render(include: "ghosts")
          CacheChild.last.touch
          expect(etag_after_render(include: "ghosts")).not_to eq(before_touch)
        end

        it "reports the latest updated_at across the graph" do
          rendered = proxy(include: "cache_children.cache_grandchildren")
          rendered.to_jsonapi
          latest = CacheGrandchild.last
          latest.update!(updated_at: 1.day.from_now)

          expect(proxy(include: "cache_children.cache_grandchildren").updated_at.to_i)
            .to eq(latest.reload.updated_at.to_i)
        end
      end
    end

    describe "resolutions" do
      # Prepended once: a module per example would stack and multiply the counts.
      before(:all) do
        Graphiti::Adapters::ActiveRecord.prepend(Module.new do
          def resolve(scope)
            count = Thread.current[:cache_key_resolves]
            Thread.current[:cache_key_resolves] = count + 1 if count
            super
          end
        end)
      end

      def resolves
        Thread.current[:cache_key_resolves] = 0
        yield
        Thread.current[:cache_key_resolves]
      ensure
        Thread.current[:cache_key_resolves] = nil
      end

      before { allow(Graphiti.config).to receive(:concurrency).and_return(false) }

      {
        "cache_children" => 2,
        "cache_children.cache_grandchildren" => 3
      }.each_pair do |include, expected|
        it "resolves #{expected} times for include=#{include}, with or without a cache key" do
          render_only = resolves { proxy(include: include).to_jsonapi }

          with_cache_key = resolves do
            rendered = proxy(include: include)
            rendered.to_jsonapi
            rendered.cache_key_with_version
            rendered.updated_at
          end

          expect(render_only).to eq(expected)
          expect(with_cache_key).to eq(expected)
        end
      end
    end
  end
end
