# frozen_string_literal: true

module Airview
  class ResourceBuilder
    class << self
      def enabled_resources
        definitions = Airview::ResourceDefinition.enabled.includes(:field_definitions).order(:position, :label)

        definitions.each_with_object({}) do |definition, resources|
          resource = build(definition)
          resources[resource.key] = resource
        end
      end

      def build(definition)
        Resource.new(definition.key, model: definition.record_class_name).tap do |resource|
          resource.label = definition.label
          resource.label_method = definition.label_method.presence&.to_sym || :to_s

          definition.field_definitions.visible.order(:position, :name).each do |field|
            add_field(resource, field)
          end

          add_missing_virtual_fields(resource, definition)
        end
      end

      private

      def add_field(resource, field)
        resource.field(
          field.name,
          type: field.field_type,
          label: field.label,
          readonly: field.read_only?,
          model: field.target_model_name,
          label_method: field.target_label_method.presence&.to_sym,
          default_visible: field.default_visible?
        )
      end

      def add_missing_virtual_fields(resource, definition)
        defined_names = definition.field_definitions.map { |field| field.name.to_sym }

        SchemaInference.new(resource.model_class).field_attributes.each do |attributes|
          next unless attributes[:field_type].to_sym.in?(%i[has_many attachment])
          next if defined_names.include?(attributes[:name].to_sym)

          resource.field(
            attributes[:name],
            type: attributes[:field_type],
            label: attributes[:label],
            readonly: attributes[:read_only],
            model: attributes[:target_model_name],
            label_method: attributes[:target_label_method],
            default_visible: attributes.dig(:metadata, :default_visible)
          )
        end
      end
    end
  end
end
