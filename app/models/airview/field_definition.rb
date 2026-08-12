# frozen_string_literal: true

module Airview
  class FieldDefinition < ApplicationRecord
    self.table_name = "airview_fields"

    belongs_to :resource_definition,
               class_name: "Airview::ResourceDefinition",
               foreign_key: :airview_resource_id,
               inverse_of: :field_definitions

    validates :name, :label, :field_type, presence: true
    validates :name, uniqueness: { scope: :airview_resource_id }
    validates :field_type, inclusion: { in: Airview::Field::TYPES.map(&:to_s) }

    scope :visible, -> { where(visible: true) }

    def default_visible?
      metadata.fetch("default_visible", true)
    end

    def stale?
      !schema_backed?
    end

    def stale_reason
      return nil if schema_backed?

      case field_type.to_sym
      when :belongs_to
        "Missing belongs_to association or foreign key"
      when :has_many
        "Missing has_many association"
      when :attachment
        "Missing attachment"
      else
        "Missing column"
      end
    end

    def schema_backed?
      model_class = resource_definition.model_class

      case field_type.to_sym
      when :belongs_to
        belongs_to_schema_backed?(model_class)
      when :has_many
        association = model_class.reflect_on_association(name.to_sym)
        association&.macro == :has_many
      when :attachment
        attachment_names(model_class).include?(name.to_s)
      else
        model_class.column_names.include?(name.to_s)
      end
    rescue ActiveRecord::StatementInvalid, NameError
      false
    end

    private

    def belongs_to_schema_backed?(model_class)
      association_key = association_name.presence || name
      association = model_class.reflect_on_association(association_key.to_sym)
      return false unless association&.macro == :belongs_to

      model_class.column_names.include?(association.foreign_key.to_s)
    end

    def attachment_names(model_class)
      return [] unless model_class.respond_to?(:attachment_reflections)

      model_class.attachment_reflections.keys.map(&:to_s)
    end
  end
end
