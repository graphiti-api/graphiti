# This could definitely use some refactoring love, but I have no time ATM
# The code is pretty self-contained; we're just listening to notifications
# and taking action.
module Graphiti
  class Debugger
    class << self
      attr_accessor :enabled, :chunks, :debug_models, :preserve, :pry
    end
    self.chunks = []

    class << self
      def on_data(name, start, stop, id, payload)
        return [] unless enabled

        took = ((stop - start) * 1000.0).round(2)
        params = scrub_params(payload[:params])

        if payload[:exception]
          on_data_exception(payload, params)
        elsif payload[:sideload]
          if payload[:results]
            on_sideload_data(payload, params, took)
          end
        else
          on_primary_data(payload, params, took)
        end
      end

      private def on_data_exception(payload, params)
        unless payload[:exception_object].instance_variable_get(:@__graphiti_debug)
          add_chunk do |logs, json|
            logs << ["\n=== Graphiti Debug ERROR", :red, true]
            if (sideload = payload[:sideload])
              logs << ["#{sideload.parent_resource.class}: Sideload \"#{sideload.name}\"", :red, true]
              json[:parent_resource] = sideload.parent_resource.class.name
              json[:sideload] = sideload.name
            end
            if params
              query = "#{payload[:resource].class.name}.all(#{JSON.pretty_generate(params)}).data"
              logs << [query, :cyan, true]
              logs << ["The error occurred when running the above query. Copy/paste it into a rake task or Rails console session to reproduce. Keep in mind you may have to set context.", :yellow, true]
            else
              query = "This sideload is done manually via .scope - no debug information available."
              logs << [query, :cyan, true]
            end
            json[:query] = query

            logs << "\n\n"
            payload[:exception_object]&.instance_variable_set(:@__graphiti_debug, json)
          end
        end
      end

      private def results(raw_results)
        raw_results.map { |r| "[#{r.class.name}, #{r.id.inspect}]" }.join(", ")
      end

      private def on_sideload_data(payload, params, took)
        sideload = payload[:sideload]
        results = results(payload[:results])
        add_chunk(payload[:resource], payload[:parent]) do |logs, json|
          logs << [" \\_ #{sideload.name}", :yellow, true]
          json[:name] = sideload.name
          query = if sideload.class.scope_proc
            "#{payload[:resource].class.name}: Manual sideload via .scope"
          else
            "#{payload[:resource].class.name}.all(#{params.inspect})"
          end
          logs << ["    #{query}", :cyan, true]
          json[:query] = query
          logs << ["    Returned Models: #{results}"] if debug_models
          logs << ["    Took: #{took}ms", :magenta, true]
          json[:took] = took
        end
      end

      private def on_primary_data(payload, params, took)
        results = results(payload[:results])
        add_chunk(payload[:resource], payload[:parent]) do |logs, json|
          logs << [""]
          logs << ["=== Graphiti Debug", :green, true]
          title = "Top Level Data Retrieval (+ sideloads):"
          logs << [title, :green, true]
          json[:title] = title
          query = "#{payload[:resource].class.name}.all(#{params.inspect})"
          logs << [query, :cyan, true]
          json[:query] = query
          logs << ["Returned Models: #{results}"] if debug_models
          logs << ["Took: #{took}ms", :magenta, true]
          json[:took] = took
        end
      end

      def on_render(name, start, stop, id, payload)
        return [] unless enabled

        add_chunk do |logs|
          took = ((stop - start) * 1000.0).round(2)
          logs << [""]
          logs << ["=== Graphiti Debug", :green, true]
          logs << if payload[:proxy]&.cached?
            ["Rendering (cached):", :green, true]
          else
            ["Rendering:", :green, true]
          end
          logs << ["Took: #{took}ms", :magenta, true]
        end
      end

      def debug
        if enabled
          begin
            self.chunks = []
            yield
          ensure
            flush
            self.chunks = [] unless preserve
          end
        else
          yield
        end
      end

      def to_a
        debugs = []
        graph_statements.each do |chunk|
          debugs << chunk_to_hash(chunk)
        end
        debugs
      end

      def flush
        Graphiti.broadcast(:flush_debug, {}) do |payload|
          payload[:chunks] = chunks
          graph_statements.each do |chunk|
            flush_chunk(chunk)
          end
        end
      end

      private

      def scrub_params(params)
        params ||= {}
        params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
        params.reject! { |k, v| [:controller, :action, :format, :debug].include?(k.to_sym) }
        params.deep_symbolize_keys
      end

      def add_chunk(resource = nil, parent = nil)
        logs, json = [], {}
        yield(logs, json)
        chunks << {
          resource: resource,
          parent: parent,
          logs: logs,
          json: json,
          children: []
        }
      end

      def graph_statements
        @chunks.each do |chunk|
          if (parent = chunk[:parent])
            relevant = chunks.find { |c| c[:resource] == parent }
            relevant[:children].unshift(chunk) if relevant
          end
        end
        @chunks.reject! { |c| !!c[:parent] }
        @chunks
      end

      def chunk_to_hash(chunk)
        hash = {}
        hash.merge!(chunk[:json])
        sideloads = []
        chunk[:children].each do |child_chunk|
          sideloads << chunk_to_hash(child_chunk)
        end
        hash[:sideloads] = sideloads
        hash
      end

      def flush_chunk(chunk, depth = 0)
        chunk[:logs].each do |args|
          indent = "   " * depth
          args[0] = "#{indent}#{args[0]}"
          Graphiti.log(*args)
        end

        chunk[:children].each do |child_chunk|
          flush_chunk(child_chunk, depth + 1)
        end
      end
    end

    ActiveSupport::Notifications.subscribe \
      "resolve.graphiti", method(:on_data)
    ActiveSupport::Notifications.subscribe \
      "render.graphiti", method(:on_render)
  end
end
