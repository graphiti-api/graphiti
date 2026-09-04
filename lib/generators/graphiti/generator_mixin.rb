module Graphiti
  module GeneratorMixin
    def prompt(header: nil, description: nil, default: nil)
      say(set_color("\n#{header}", :magenta, :bold)) if header
      say("\n#{description}") if description
      answer = ask(set_color("\n(default: #{default}):", :magenta, :bold))
      answer = default if answer.blank? && default != "nil"
      say(set_color("\nGot it!\n", :white, :bold))
      answer
    end

    def api_namespace
      @api_namespace ||= begin
        ns = graphiti_config["namespace"]

        if ns.blank?
          ns = prompt \
            header: "What is your API namespace?",
            description: "This will be used as a route prefix, e.g. if you want the route '/books_api/v1/authors' your namespace would be '/books_api/v1'",
            default: "/api/v1"
          update_config!("namespace" => ns)
        end

        ns
      end
    end

    def actions
      @options["actions"] || %w[index show create update destroy]
    end

    def actions?(*methods)
      methods.any? { |m| actions.include?(m) }
    end

    def resource_setting_groups
      name_width = Graphiti::Resource::SETTINGS.keys.map(&:length).max
      assignments = Graphiti::Resource::SETTINGS.to_h do |name, setting|
        value = setting[:format] || setting[:default].inspect
        [name, "#{name.to_s.ljust(name_width)} #{value}"]
      end
      hint_column = assignments.values.map(&:length).max + 2

      Graphiti::Resource::SETTING_GROUPS.transform_values do |settings|
        settings.map do |name, setting|
          hint = resource_setting_hint(setting)
          hint ? "#{assignments[name].ljust(hint_column)}# #{hint}" : assignments[name]
        end
      end
    end

    def resource_setting_hint(setting)
      hint = setting[:note] || setting[:values]&.map(&:inspect)
        &.to_sentence(two_words_connector: " or ", last_word_connector: ", or ")

      return hint unless setting[:deprecated]

      ["deprecated, removed in 3.0", hint].compact.join(". ")
    end

    def graphiti_config
      File.exist?(".graphiticfg.yml") ? YAML.load_file(".graphiticfg.yml") : {}
    end

    def update_config!(attrs)
      config = graphiti_config.merge(attrs)
      File.write(".graphiticfg.yml", config.to_yaml)
    end

    def id_or_rawid
      @options["rawid"] ? "rawid" : "id"
    end

    def sort_raw_ids
      return unless @options["rawid"]
      ".sort"
    end

    def sort_raw_ids_descending
      return unless @options["rawid"]
      ".sort.reverse"
    end
  end
end
