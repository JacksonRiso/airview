# frozen_string_literal: true

module Airview
  class ResourceDefinition < ApplicationRecord
    self.table_name = "airview_resources"

    has_many :field_definitions,
             -> { order(:position, :name) },
             class_name: "Airview::FieldDefinition",
             foreign_key: :airview_resource_id,
             inverse_of: :resource_definition,
             dependent: :destroy

    accepts_nested_attributes_for :field_definitions, allow_destroy: true

    validates :key, :model_name, :label, presence: true
    validates :key, uniqueness: true
    validates :model_name, uniqueness: true
    validate :key_is_immutable, on: :update
    validate :model_is_discoverable
    validate :enabled_resource_has_visible_fields

    scope :enabled, -> { where(enabled: true) }

    def model_class
      model_name.constantize
    end

    private

    def key_is_immutable
      errors.add(:key, "cannot be changed") if will_save_change_to_key?
    end

    def model_is_discoverable
      return if Airview::ModelDiscovery.model_named(model_name)

      errors.add(:model_name, "must be a concrete ActiveRecord model with a table")
    end

    def enabled_resource_has_visible_fields
      return unless enabled?
      return if field_definitions.reject(&:marked_for_destruction?).any?(&:visible?)

      errors.add(:base, "Enabled resources must have at least one visible field")
    end
  end
end
