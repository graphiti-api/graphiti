module Graphiti
  class LocaleGenerator < ::Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :"omit-comments",
      type: :boolean,
      default: false,
      aliases: ["-c"],
      desc: "Generate without documentation comments"

    desc "Writes the error text Graphiti renders, ready to edit"
    def locale
      template("locale.yml.erb", File.join("config/locales", "graphiti.en.yml"))
    end

    private

    def omit_comments?
      @options["omit-comments"]
    end

    def default_messages
      Graphiti::Util::SimpleErrors::DEFAULT_MESSAGES
    end

    def default_format
      Graphiti::Util::SimpleErrors::DEFAULT_FORMAT
    end
  end
end
