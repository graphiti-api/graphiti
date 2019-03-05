module Graphiti
  class SchemaDiff
    def initialize(old, new)
      @old = old.deep_symbolize_keys
      @new = new.deep_symbolize_keys
      @errors = []
    end

    def compare
      compare_each if @old != @new
      @errors
    end

    private

    def compare_each
      compare_resources
      compare_endpoints
      compare_types
    end

    def compare_resources
      @old[:resources].each_with_index do |r, index|
        new_resource = @new[:resources].find { |n| n[:name] == r[:name] }
        next if new_resource.try(:[], :remote) || r.try(:[], :remote)

        compare_resource(r, new_resource) do
          compare_attributes(r, new_resource)
          compare_defaults(r, new_resource)
          compare_extra_attributes(r, new_resource)
          compare_sorts(r, new_resource)
          compare_filters(r, new_resource)
          compare_relationships(r, new_resource)
        end
      end
    end

    def compare_resource(old_resource, new_resource)
      unless new_resource
        @errors << "#{old_resource[:name]} was removed."
        return
      end

      if old_resource[:type] != new_resource[:type]
        @errors << "#{old_resource[:name]} changed type from #{old_resource[:type].inspect} to #{new_resource[:type].inspect}."
      end
      yield
    end

    def compare_attributes(old_resource, new_resource)
      old_resource[:attributes].each_pair do |name, old_att|
        unless (new_att = new_resource[:attributes][name])
          @errors << "#{old_resource[:name]}: attribute #{name.inspect} was removed."
          next
        end

        compare_attribute(old_resource[:name], name, old_att, new_att)
      end
    end

    def compare_defaults(old_resource, new_resource)
      if new_resource[:default_sort] && !old_resource[:default_sort]
        @errors << "#{old_resource[:name]}: default sort added."
      end

      if old_resource[:default_sort] && !new_resource[:default_sort]
        @errors << "#{old_resource[:name]}: default sort removed."
      end

      if new_resource[:default_sort] && old_resource[:default_sort]
        if new_resource[:default_sort] != old_resource[:default_sort]
          @errors << "#{old_resource[:name]}: default sort changed from #{old_resource[:default_sort].inspect} to #{new_resource[:default_sort].inspect}."
        end
      end

      if new_resource[:default_page_size] && !old_resource[:default_page_size]
        @errors << "#{old_resource[:name]}: default page size added."
      end

      if old_resource[:default_page_size] && !new_resource[:default_page_size]
        @errors << "#{old_resource[:name]}: default page size removed."
      end

      if old_resource[:default_page_size] && new_resource[:default_page_size]
        if old_resource[:default_page_size] != new_resource[:default_page_size]
          @errors << "#{old_resource[:name]}: default page size changed from #{old_resource[:default_page_size]} to #{new_resource[:default_page_size]}."
        end
      end
    end

    def compare_relationships(old_resource, new_resource)
      old_resource[:relationships].each_pair do |name, old_rel|
        unless (new_rel = new_resource[:relationships][name])
          @errors << "#{old_resource[:name]}: relationship #{name.inspect} was removed."
          next
        end

        if new_rel[:single] && !old_rel[:single]
          @errors << "#{old_resource[:name]}: relationship #{name.inspect} became single: true."
          next
        end

        if new_rel[:resource] != old_rel[:resource]
          @errors << "#{old_resource[:name]}: relationship #{name.inspect} changed resource from #{old_rel[:resource]} to #{new_rel[:resource]}."
        end

        if new_rel[:type] != old_rel[:type]
          @errors << "#{old_resource[:name]}: relationship #{name.inspect} changed type from #{old_rel[:type].inspect} to #{new_rel[:type].inspect}."
        end
      end
    end

    def compare_extra_attributes(old_resource, new_resource)
      old_resource[:extra_attributes].each_pair do |name, old_att|
        unless (new_att = new_resource[:extra_attributes][name])
          @errors << "#{old_resource[:name]}: extra attribute #{name.inspect} was removed."
          next
        end

        compare_attribute(old_resource[:name], name, old_att, new_att, extra: true)
      end
    end

    def compare_sorts(old_resource, new_resource)
      old_resource[:sorts].each_pair do |name, old_sort|
        unless (new_sort = new_resource[:sorts][name])
          @errors << "#{old_resource[:name]}: sort #{name.inspect} was removed."
          next
        end

        if new_sort[:guard] && !old_sort[:guard]
          @errors << "#{old_resource[:name]}: sort #{name.inspect} became guarded."
        end

        if new_sort[:only] && !old_sort[:only]
          @errors << "#{old_resource[:name]}: sort #{name.inspect} now limited to only #{new_sort[:only].inspect}."
        end

        if new_sort[:only] && old_sort[:only]
          if new_sort[:only] != old_sort[:only]
            @errors << "#{old_resource[:name]}: sort #{name.inspect} was limited to only #{old_sort[:only].inspect}, now limited to only #{new_sort[:only].inspect}."
          end
        end
      end
    end

    def compare_filters(old_resource, new_resource)
      old_resource[:filters].each_pair do |name, old_filter|
        unless (new_filter = new_resource[:filters][name])
          @errors << "#{old_resource[:name]}: filter #{name.inspect} was removed."
          next
        end

        if new_filter[:type] != old_filter[:type]
          @errors << "#{old_resource[:name]}: filter #{name.inspect} changed type from #{old_filter[:type].inspect} to #{new_filter[:type].inspect}."
          next
        end

        if new_filter[:single] && !old_filter[:single]
          @errors << "#{old_resource[:name]}: filter #{name.inspect} became singular."
        end

        if new_filter[:dependencies] && !old_filter[:dependencies]
          @errors << "#{old_resource[:name]}: filter #{name.inspect} added dependencies #{new_filter[:dependencies].inspect}."
        end

        if new_filter[:dependencies] && old_filter[:dependencies]
          if new_filter[:dependencies] != old_filter[:dependencies]
            @errors << "#{old_resource[:name]}: filter #{name.inspect} changed dependencies from #{old_filter[:dependencies].inspect} to #{new_filter[:dependencies].inspect}."
          end
        end

        if new_filter[:allow] != old_filter[:allow]
          new = new_filter[:allow] || []
          old = old_filter[:allow] || []
          diff = new - old
          if diff.length > 0
            @errors << "#{old_resource[:name]}: filter #{name.inspect} allowlist went from #{old.inspect} to #{new.inspect}."
          end
        end

        if new_filter[:deny] != old_filter[:deny]
          new = new_filter[:deny] || []
          old = old_filter[:deny] || []
          diff = new - old
          if diff.length > 0
            @errors << "#{old_resource[:name]}: filter #{name.inspect} denylist went from #{old.inspect} to #{new.inspect}."
          end
        end

        if (diff = old_filter[:operators] - new_filter[:operators]).length > 0
          diff.each do |op|
            @errors << "#{old_resource[:name]}: filter #{name.inspect} removed operator #{op.inspect}."
          end
        end

        if new_filter[:required] && !old_filter[:required]
          @errors << "#{old_resource[:name]}: filter #{name.inspect} went from optional to required."
        end

        if new_filter[:guard] && !old_filter[:guard]
          @errors << "#{old_resource[:name]}: filter #{name.inspect} went from unguarded to guarded."
        end
      end
    end

    def compare_endpoints
      @old[:endpoints].each_pair do |path, old_endpoint|
        unless (new_endpoint = @new[:endpoints][path])
          @errors << "Endpoint \"#{path}\" was removed."
          next
        end

        old_endpoint[:actions].each_pair do |name, old_action|
          unless (new_action = new_endpoint[:actions][name])
            @errors << "Endpoint \"#{path}\" removed action #{name.inspect}."
            next
          end

          if new_action[:sideload_allowlist] && !old_action[:sideload_allowlist]
            @errors << "Endpoint \"#{path}\" added sideload allowlist."
          end

          if new_action[:sideload_allowlist]
            if new_action[:sideload_allowlist] != old_action[:sideload_allowlist]
              removal = Util::Hash.include_removed? \
                new_action[:sideload_allowlist], old_action[:sideload_allowlist]
              if removal
                @errors << "Endpoint \"#{path}\" had incompatible sideload allowlist. Was #{old_action[:sideload_allowlist].inspect}, now #{new_action[:sideload_allowlist].inspect}."
              end
            end
          end
        end
      end
    end

    def compare_types
      @old[:types].each_pair do |name, old_type|
        unless (new_type = @new[:types][name])
          @errors << "Type #{name.inspect} was removed."
          next
        end

        if new_type[:kind] != old_type[:kind]
          @errors << "Type #{name.inspect} changed kind from #{old_type[:kind].inspect} to #{new_type[:kind].inspect}."
        end
      end
    end

    def compare_attribute(resource_name, att_name, old_att, new_att, extra: false)
      prefix = extra ? "extra attribute" : "attribute"

      if old_att[:type] != new_att[:type]
        @errors << "#{resource_name}: #{prefix} #{att_name.inspect} changed type from #{old_att[:type].inspect} to #{new_att[:type].inspect}."
      end

      [:readable, :writable].each do |flag|
        if [true, "guarded"].include?(old_att[flag]) && new_att[flag] == false
          @errors << "#{resource_name}: #{prefix} #{att_name.inspect} changed flag #{flag.inspect} from #{old_att[flag].inspect} to #{new_att[flag].inspect}."
        end

        if new_att[flag] == "guarded" && old_att[flag] == true
          @errors << "#{resource_name}: #{prefix} #{att_name.inspect} changed flag #{flag.inspect} from #{old_att[flag].inspect} to #{new_att[flag].inspect}."
        end
      end
    end
  end
end
