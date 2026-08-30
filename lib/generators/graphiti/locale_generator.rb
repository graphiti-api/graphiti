module Graphiti
  class LocaleGenerator < ::Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :"omit-comments",
      type: :boolean,
      default: false,
      aliases: ["-c"],
      desc: "Generate without documentation comments"

    # Every code Graphiti renders a title for, and the title it renders today.
    ERROR_TITLES = {
      bad_request: "Request Error",
      not_found: "Not Found",
      conflict: "Conflict Error",
      unprocessable_entity: "Validation Error",
      internal_server_error: "Internal Server Error"
    }.freeze

    # The two codes no registration produces.
    ERROR_SOURCES = {
      unprocessable_entity: ["a write that failed model validations"],
      internal_server_error: ["any exception Graphiti did not register"]
    }.freeze

    # Written into the app's locale file, not defaulted in Graphiti.
    ERROR_DETAILS = {
      internal_server_error: "We've probably received an error report already, but please contact us if the issue persists."
    }.freeze

    COMMENT_WIDTH = 68

    desc "Writes the error text Graphiti renders, ready to edit"
    def locale
      template("locale.yml.erb", File.join("config/locales", "graphiti.en.yml"))
    end

    private

    def omit_comments?
      @options["omit-comments"]
    end

    def error_titles
      ERROR_TITLES
    end

    def error_detail(code)
      ERROR_DETAILS[code]
    end

    # What raises this code, so the file says where its text is used.
    def error_source_lines(code)
      ERROR_SOURCES[code] || wrap(exception_names(code))
    end

    def exception_names(code)
      Graphiti::Rails::CLIENT_ERROR_STATUSES
        .select { |_exception, status| status == code }
        .keys.map { |exception| exception.delete_prefix("Graphiti::Errors::") }
    end

    def wrap(names)
      items = names.map.with_index do |name, index|
        (index == names.length - 1) ? name : "#{name},"
      end

      items.each_with_object([]) do |item, lines|
        joined = "#{lines.last} #{item}"
        if lines.empty? || joined.length > COMMENT_WIDTH
          lines << item
        else
          lines[-1] = joined
        end
      end
    end

    def default_messages
      Graphiti::Util::SimpleErrors::DEFAULT_MESSAGES
    end

    def default_format
      Graphiti::Util::SimpleErrors::DEFAULT_FORMAT
    end
  end
end
