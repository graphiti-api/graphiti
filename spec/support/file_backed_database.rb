# Threaded specs need a real file, because sqlite's :memory: gives each connection its own empty database.
module FileBackedDatabase
  module_function

  def connect(namespace, path, pool: 5)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.rm_f(path)
    base = Class.new(ActiveRecord::Base) { self.abstract_class = true }
    namespace.const_set(:Base, base)
    base.establish_connection(
      adapter: "sqlite3", database: path, pool: pool, timeout: 5000
    )
    base
  end

  def disconnect(namespace, path, consts)
    namespace::Base.remove_connection
    FileUtils.rm_f(path)
    (consts + [:Base]).each do |name|
      namespace.send(:remove_const, name) if namespace.const_defined?(name, false)
    end
  end
end
