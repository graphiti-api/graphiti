# This will convert JSONAPI-compatible POST/PUT payloads
# into something Rails better understands. Example:
#
# {
#   "data": {
#     "type": "articles",
#     "attributes": { "title": "the first article" },
#     "relationships": {
#       "tags": {
#         "data": [{
#           "type": "tags",
#           "attributes": { "name": "One" }
#         }, {
#           "type": "tags",
#           "attributes": { "name": "Two" }
#         }]
#       }
#     }
#   }
# }
#
# Into:
#
# {
#    article: {
#      title: 'the first article',
#      tags_attributes: [
#        { name: 'One' },
#        { name: 'Two' },
#      ]
#    }
# }
#
# Why we don't use AMS deserialization - AMS will:
# * not support relationship data
# * override foreign key incorrectly, ie
#   post_id incorrectly becomes nil if post relation is nil,
#   even if it is in the attributes payload
#
# Usage:
#
# In controller:
#
# before_action :deserialize_jsonapi!, only: [:my_action]

module JsonapiCompliable
  module Deserializable
    extend ActiveSupport::Concern

    included do
      attr_accessor :raw_params
    end

    class Deserialization
      def initialize(params, namespace: true)
        @params = params
        @namespace = namespace
      end

      def deserialize
        hash = attributes
        hash = hash.merge(relationships)
        hash = @namespace ? { parsed_type => hash } : hash
        hash.reverse_merge(@params.except(:data)).deep_symbolize_keys
      end

      private

      def parsed_type
        @params[:data][:type].underscore.singularize.to_sym
      end

      def attributes
        attrs = {}
        attrs[:id] = @params[:data].try(:[], :id) if @params[:data].try(:[], :id)
        attrs.merge!(@params[:data].try(:[], :attributes) || {})
        attrs
      end

      def relationships
        return {} if @params[:data].try(:[], :relationships).blank?

        {}.tap do |hash|
          @params[:data][:relationships].each_pair do |relationship_name, payload|
            parsed_relation = parse_relation(payload)

            if parsed_relation.present?
              hash["#{relationship_name}_attributes".to_sym] = parsed_relation
            end
          end
        end
      end

      def parse_relation(payload)
        if payload[:data].is_a?(Array)
          parse_has_many(payload[:data])
        else
          parse_belongs_to(payload)
        end
      end

      def parse_belongs_to(payload)
        self.class.new(payload, namespace: false).deserialize
      end

      def parse_has_many(payloads)
        payloads.map do |payload|
          payload = { data: payload }
          self.class.new(payload, namespace: false).deserialize
        end.compact
      end
    end

    def deserialize_jsonapi!
      self.raw_params = Util::Hash.deep_dup(self.params)

      if defined?(::Rails) && (is_a?(ActionController::Base) || (defined?(ActionController::API) && is_a?(ActionController::API)))
        hash = params.to_unsafe_h
        hash = hash.with_indifferent_access if ::Rails::VERSION::MAJOR == 4
        deserialized = Deserialization.new(hash).deserialize
        self.params = ActionController::Parameters.new(deserialized)
      else
        self.params =  Deserialization.new(params).deserialize
      end
    end
  end
end
