# frozen_string_literal: true

module Airview
  class View < ApplicationRecord
    self.table_name = "airview_views"

    validates :name, :resource_key, presence: true

    scope :for_resource, ->(resource_key) { where(resource_key: resource_key.to_s) }
  end
end
