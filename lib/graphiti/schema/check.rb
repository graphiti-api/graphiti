module Graphiti
  class Schema
    class Check
      attr_reader :path, :errors

      def initialize(schema, path)
        @path = path
        @schema = schema
        @generated = normalize(schema)
        @committed = normalize(JSON.parse(File.read(path))) if File.exist?(path)
        @errors = @committed ? SchemaDiff.new(@committed, @generated).compare : []
      end

      def missing?
        @committed.nil?
      end

      def stale?
        !missing? && @committed != @generated
      end

      def compatible?
        errors.empty?
      end

      def ok?
        !missing? && !stale? && compatible?
      end

      def write!
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(@schema))
        path
      end

      def message
        return "Schema is up to date: #{path}" if ok?
        return "#{missing_message}\n\n#{regenerate}" if missing?
        return "#{incompatible_message}\n\n#{errors.join("\n")}" unless compatible?

        "Schema file is outdated: #{path}\n\n#{regenerate}"
      end

      private

      def normalize(schema)
        JSON.parse(JSON.generate(schema))
      end

      def missing_message
        "Schema file not found: #{path}"
      end

      def incompatible_message
        <<~MSG.chomp
          Found backwards-incompatibilities in schema: #{path}

          Re-run with FORCE_SCHEMA=true to accept them and overwrite the file.

          Incompatibilities:
        MSG
      end

      def regenerate
        "Run `rake graphiti:schema:generate` and commit the file."
      end
    end
  end
end
