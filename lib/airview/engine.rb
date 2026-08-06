# frozen_string_literal: true

require "rails"

module Airview
  class Engine < ::Rails::Engine
    isolate_namespace Airview

    initializer "airview.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[airview/application.css airview/application.js]
      end
    end
  end
end
