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
            if field_schema_backed?(resource.model_class, field)
              add_field(resource, field)
            else
              resource.add_stale_field(field, reason: stale_reason(resource.model_class, field))
              log_stale_field(resource, field)
            end
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

      def field_schema_backed?(model_class, field)
        case field.field_type.to_sym
        when :belongs_to
          belongs_to_schema_backed?(model_class, field)
        when :has_many
          association = model_class.reflect_on_association(field.name.to_sym)
          association&.macro == :has_many
        when :attachment
          attachment_names(model_class).include?(field.name.to_s)
        else
          model_class.column_names.include?(field.name.to_s)
        end
      rescue NameError
        false
      end

      def belongs_to_schema_backed?(model_class, field)
        association_name = field.association_name.presence || field.name
        association = model_class.reflect_on_association(association_name.to_sym)
        return false unless association&.macro == :belongs_to

        model_class.column_names.include?(association.foreign_key.to_s)
      end

      def attachment_names(model_class)
        return [] unless model_class.respond_to?(:attachment_reflections)

        model_class.attachment_reflections.keys.map(&:to_s)
      end

      def stale_reason(model_class, field)
        case field.field_type.to_sym
        when :belongs_to
          "missing belongs_to association or foreign key on #{model_class.name}"
        when :has_many
          "missing has_many association on #{model_class.name}"
        when :attachment
          "missing attachment on #{model_class.name}"
        else
          "missing column on #{model_class.name}"
        end
      end

      def log_stale_field(resource, field)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        reason = stale_reason(resource.model_class, field)
        Rails.logger.warn("Airview skipped stale field #{field.name.inspect} for #{resource.model}: #{reason}")
      end
    end
  end
end
