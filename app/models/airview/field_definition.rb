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
  end
end
