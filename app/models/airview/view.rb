# frozen_string_literal: true

module Airview
  class View < ApplicationRecord
    self.table_name = "airview_views"

    validates :name, :resource_key, presence: true

    scope :for_resource, ->(resource_key) { where(resource_key: resource_key.to_s) }
    scope :ordered, -> { order(:folder, :name) }

    before_validation :normalize_folder

    def ordered_columns(resource)
      saved = Array(columns).map(&:to_s)
      available = resource.fields.keys.map(&:to_s)

      saved & available
    end

    private

    def normalize_folder
      self.folder = folder.to_s.strip.presence
    end
  end
end
