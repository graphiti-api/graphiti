module Graphiti
  module Adapters
    class GraphitiAPI < ::Graphiti::Adapters::Null
      def base_scope(model)
        {}
      end

      def resolve(scope)
        url = build_url(scope)
        response = resource.make_request(url)
        json = JSON.parse(response.body)

        if json["errors"]
          handle_remote_error(url, json)
        else
          models = json["data"].map { |d| build_entity(json, d) }
          Util::RemoteSerializer.for(resource.class.serializer, models)
          models
        end
      end

      private

      def handle_remote_error(url, json)
        errors = json["errors"].map { |error|
          if (raw = error["meta"].try(:[], "__raw_error__"))
            {message: raw["message"], backtrace: raw["backtrace"]}
          else
            {message: "#{error["title"]} - #{error["detail"]}"}
          end
        }.compact
        raise Errors::Remote.new(url, errors)
      end

      def build_url(scope)
        url = resource.remote_url
        params = scope[:params].merge(scope.except(:params))
        params[:page] ||= {}
        params[:page][:size] ||= 999
        params = CGI.unescape(params.to_query)
        url = "#{url}?#{params}" unless params.blank?
        url
      end

      def find_entity(json, id, type)
        lookup = Array(json["data"]) | Array(json["included"])
        lookup.find { |l| l["id"] == id.to_s && l["type"] == type }
      end

      def build_entity(json, node)
        entity = OpenStruct.new(node["attributes"])
        entity.id = node["id"]
        entity._type = node["type"]
        process_relationships(entity, json, node["relationships"] || {})
        entity
      end

      def process_relationships(entity, json, relationship_json)
        entity._relationships = {}
        relationship_json.each_pair do |name, hash|
          if (data = hash["data"])
            if data.is_a?(Array)
              data.each do |d|
                rel = find_entity(json, d["id"], d["type"])
                related_entity = build_entity(json, rel)
                add_relationship(entity, related_entity, name, true)
              end
            else
              rel = find_entity(json, hash["data"]["id"], hash["data"]["type"])
              related_entity = build_entity(json, rel)
              add_relationship(entity, related_entity, name)
            end
          end
          Util::RemoteSerializer.for(Graphiti::Serializer, Array(entity[name]))
        end
      end

      def add_relationship(entity, related_entity, name, many = false)
        if many
          entity[name] ||= []
          entity[name] << related_entity
          entity._relationships[name] ||= []
          entity._relationships[name] << related_entity
        else
          entity[name] = related_entity
          entity._relationships[name] = related_entity
        end
      end
    end
  end
end
