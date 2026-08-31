module Graphiti
  # graphiti-api/graphiti#134 recommended reading Graphiti.context[:namespace] from base_scope before current_action existed, so the old key keeps working for one major.
  class ContextHash < Hash
    def [](key)
      super(deprecate_namespace(key))
    end

    def []=(key, value)
      super(deprecate_namespace(key), value)
    end

    private

    def deprecate_namespace(key)
      return key unless key == :namespace

      Graphiti::DEPRECATOR.deprecation_warning(:"context[:namespace]", "Use #current_action instead", caller_locations(2))
      :action
    end
  end
end
