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
        Resource.new(definition.key, model: definition.model_name).tap do |resource|
          resource.label = definition.label
          resource.label_method = definition.label_method.presence&.to_sym || :to_s

          definition.field_definitions.visible.order(:position, :name).each do |field|
            resource.field(
              field.name,
              type: field.field_type,
              label: field.label,
              readonly: field.readonly?,
              model: field.target_model_name,
              label_method: field.target_label_method.presence&.to_sym
            )
          end
        end
      end
    end
  end
end
