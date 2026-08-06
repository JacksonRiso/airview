# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record/migration"

module Airview
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "airview.rb", "config/initializers/airview.rb"
      end

      def copy_migration
        migration_template "create_airview_views.rb", "db/migrate/create_airview_views.rb"
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end
