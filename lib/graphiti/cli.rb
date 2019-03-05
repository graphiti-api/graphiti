require "thor"
require "net/http"
require "graphiti"

Thor::Base.shell = Thor::Shell::Color

module Graphiti
  class CLI < Thor
    desc "schema_check OLD_SCHEMA NEW_SCHEMA", "Diff 2 schemas for backwards incompatibilities. Pass file path or URL. If your app relies on JSON Web Tokens, you can set GRAPHITI_TOKEN for authentication"
    def schema_check(old, new)
      old = schema_for(old)
      new = schema_for(new)

      errors = Graphiti::SchemaDiff.new(old, new).compare
      if errors.any?
        say(set_color("Backwards incompatibilties found!\n", :red, :bold))
        errors.each { |e| say(set_color(e, :yellow)) }
        exit(1)
      else
        say(set_color("No incompatibilities found!", :green))
        exit(0)
      end
    end

    private

    def schema_for(input)
      if input.starts_with?("http")
        JSON.parse(fetch_remote_schema(input))
      else
        JSON.parse(File.read(input))
      end
    end

    def fetch_remote_schema(path)
      uri = URI(path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Token token=\"#{ENV["GRAPHITI_TOKEN"]}\""
      res = http.request(req)
      res.body
    end
  end
end
