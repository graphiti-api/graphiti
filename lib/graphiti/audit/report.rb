module Graphiti
  class Audit
    class Report
      ANSI = {red: 31, green: 32, yellow: 33, blue: 34, magenta: 35, cyan: 36, bold: 1, dim: 2}.freeze

      ISSUE_HEADINGS = {
        broken_relationship: "raised while being inspected",
        missing_association_method: "will raise when the relationship is included: the model has no association method",
        missing_guard_method: "will raise whenever the resource renders: the readable guard is not defined",
        missing_sideload_filter: "will raise when the relationship is included: the related resource is missing the filter"
      }.freeze

      CHECKLIST = {
        broken_relationship: ["all relationships inspectable", "relationship", "raised while being inspected"],
        missing_association_method: ["all association methods defined", "association method", "missing"],
        missing_guard_method: ["all readable guards defined", "readable guard", "missing"],
        missing_sideload_filter: ["all sideload filters declared", "sideload filter", "missing"],
        loads_on_every_render: ["all id-rendering loads preloaded", "relationship", "loading ids without preloading"]
      }.freeze

      Cell = Struct.new(:raw, :painted) do
        def pad_to(width)
          painted + " " * (width - raw.length)
        end
      end

      def initialize(rows, color: $stdout.tty?)
        @rows = rows
        @color = color
      end

      def to_s
        return "graphiti: no relationships found.\n" if @rows.empty?

        (body + [summary]).join("\n")
      end

      private

      def body
        [""] + issue_sections + loading_section + would_load_section + checks_section
      end

      def issue_sections
        row_finding_pairs = @rows.flat_map do |row|
          row.findings.map { |finding| [row, finding] }
        end

        row_finding_pairs
          .group_by { |_, finding| finding.check }
          .sort_by { |check, _| ISSUE_HEADINGS.keys.index(check) || ISSUE_HEADINGS.size }
          .flat_map { |check, group| issue_section(check, group) }
      end

      def issue_section(check, group)
        findings = group.map(&:last)
        label = findings.first.error? ? "ERROR" : "WARNING"
        color = findings.first.error? ? :red : :yellow
        fixes = findings.filter_map(&:remedy).uniq

        section_heading(label, color, ISSUE_HEADINGS.fetch(check, check.to_s.tr("_", " "))) +
          lines_grouped_by_resource(group.map { |row, finding| [row, finding.message] }) +
          (fixes.size == 1 ? [fix_line(fixes.first), ""] : [])
      end

      def loading_section
        rows = @rows.select { |row| loads_without_preload?(row) }
        return [] if rows.empty?

        section_heading("WARNING", :yellow, "rendering resource ids by loading an association the base_scope does not preload") +
          lines_grouped_by_resource(rows.map { |row| [row, nil] }) +
          ["  #{paint("That is a query per record rendered.", :dim)}",
            fix_line("preload the association in base_scope, or drop `resource_ids`"),
            "  #{paint("See www.graphiti.dev/concepts/relationships#customizing-relationships", :dim)}",
            ""]
      end

      def loads_without_preload?(row)
        row.resource_ids_source == :load && row.preloaded == false
      end

      def would_load_section
        rows = @rows.select(&:would_start_loading?)
        return [] if rows.empty?

        verb = rows.size == 1 ? "renders" : "render"

        section_heading("FYI", :blue, "#{count(rows.size, "belongs_to relationship")} #{verb} no resource ids") +
          lines_grouped_by_resource(rows.map { |row| [row, nil] }) +
          ["  #{paint("Nothing to fix. A request that includes the relationship still gets its ids.", :dim)}",
            "",
            "  #{paint("To render ids on every response, opt in:", :dim)}",
            ""] +
          opt_in_lines +
          ["",
            "  #{paint("Either would load the association on every render. That potential performance cost is why ids are opt-in.", :dim)}",
            "  #{paint("Preloading the association in base_scope keeps that load cheap.", :dim)}",
            "  #{paint("See www.graphiti.dev/concepts/relationships#belongs-to-resource-ids", :dim)}",
            ""]
      end

      def checks_section
        failure_counts = @rows.flat_map(&:findings).map(&:check).tally
        loading = @rows.count { |row| loads_without_preload?(row) }
        failure_counts[:loads_on_every_render] = loading if loading > 0

        no_loads = @rows.none? { |row| row.resource_ids_source == :load }

        lines = CHECKLIST.filter_map do |check, (passed, failure_noun, failure_suffix)|
          if (failures = failure_counts[check])
            "  #{paint("✗", :red)} #{count(failures, failure_noun)} #{failure_suffix}"
          elsif check == :loads_on_every_render && no_loads
            nil
          else
            "  #{paint("✓", :green)} #{passed}"
          end
        end

        [paint("checks", :bold), ""] + lines + [""]
      end

      def section_heading(label, color, heading)
        ["#{paint(label, color, :bold)} #{paint(heading, :bold)}", ""]
      end

      def fix_line(text)
        "  #{paint("fix:", :green)} #{text}"
      end

      def lines_grouped_by_resource(pairs)
        width = pairs.map { |row, _| declaration_cell(row).raw.length }.max

        pairs.group_by { |row, _| row.resource }.sort_by { |resource, _| resource }.flat_map do |resource, group|
          ["  #{paint(resource, :bold)}"] +
            group.sort_by { |row, _| row.relationship.to_s }.map { |row, note|
              declaration = declaration_cell(row)
              note ? "    #{declaration.pad_to(width)}  #{note}" : "    #{declaration.painted}"
            } +
            [""]
        end
      end

      def opt_in_lines
        options = [
          [[["resource_ids: ", :cyan], ["true", :yellow]], "on one relationship"],
          [[["self.belongs_to_resource_ids_by_default = ", nil], [":always", :cyan]], "across the whole API"]
        ]

        rows = options.map do |parts, scope|
          [cell(parts), cell([[scope, :dim]])]
        end

        aligned(rows, "    ")
      end

      def declaration_cell(row)
        cell(declaration_parts(row))
      end

      def declaration_parts(row)
        parts = [[row.type.to_s, :blue], [" ", nil], [":#{row.relationship}", :cyan]]

        row.options.each do |key, value|
          parts << [", ", nil] << ["#{key}: ", :cyan] << option_part(value)
        end

        parts
      end

      def option_part(value)
        case value
        when "..." then ["{ ... }", :dim]
        when true, false then [value.inspect, :yellow]
        when Symbol then [value.inspect, :cyan]
        when String then [value.inspect, :green]
        else [value.inspect, nil]
        end
      end

      def cell(parts)
        Cell.new(
          parts.map { |text, _| text }.join,
          parts.map { |text, style| paint(text, style) }.join
        )
      end

      def aligned(rows, indent)
        widths = rows.transpose.map { |column| column.map { |cell| cell.raw.length }.max }

        rows.map do |cells|
          line = cells.each_with_index.map { |cell, index|
            index == cells.size - 1 ? cell.painted : cell.pad_to(widths[index])
          }.join("  ")
          indent + line
        end
      end

      def summary
        errors = @rows.count(&:error?)
        loading = @rows.count { |row| loads_without_preload?(row) }
        no_ids = @rows.count(&:would_start_loading?)

        counts = [
          count(@rows.group_by(&:resource).size, "resource"),
          count(@rows.size, "relationship"),
          paint(count(errors, "error"), errors > 0 ? :red : nil)
        ]
        counts << paint("#{loading} loading ids without preloading", :yellow) if loading > 0
        counts << "#{no_ids} without resource ids" if no_ids > 0

        "graphiti: #{counts.join(", ")}."
      end

      def count(number, noun)
        "#{number} #{noun}#{"s" unless number == 1}"
      end

      def paint(text, *styles)
        styles = styles.compact
        return text unless @color && styles.any?

        "\e[#{styles.map { |style| ANSI.fetch(style) }.join(";")}m#{text}\e[0m"
      end
    end
  end
end
