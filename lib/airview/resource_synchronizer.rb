# frozen_string_literal: true

module Airview
  class ResourceSynchronizer
    attr_reader :definition

    def initialize(definition)
      @definition = definition
    end

    def sync_missing_fields
      existing_names = definition.field_definitions.map { |field| field.name.to_s }
      position = definition.field_definitions.map(&:position).compact.max.to_i
      added_count = 0

      SchemaInference.new(definition.model_class).field_attributes.each do |attributes|
        next if existing_names.include?(attributes[:name].to_s)

        position += 1
        definition.field_definitions.create!(
          attributes.merge(position:, read_only: attributes[:read_only] ? true : false)
        )
        added_count += 1
      end

      added_count
    end
  end
end
