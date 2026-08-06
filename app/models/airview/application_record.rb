# frozen_string_literal: true

module Airview
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
