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

    def graphiti_config
      File.exist?(".graphiticfg.yml") ? YAML.load_file(".graphiticfg.yml") : {}
    end

    def update_config!(attrs)
      config = graphiti_config.merge(attrs)
      File.open(".graphiticfg.yml", "w") { |f| f.write(config.to_yaml) }
    end
  end
end
