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
        if migration_exists?("create_airview_views")
          unless migration_exists?("add_folders_to_airview_views")
            migration_template "add_folders_to_airview_views.rb", "db/migrate/add_folders_to_airview_views.rb"
          end
        else
          migration_template "create_airview_views.rb", "db/migrate/create_airview_views.rb"
        end
      end

      def self.next_migration_number(_dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      private

      def migration_exists?(name)
        Dir.glob(File.join(destination_root, "db/migrate/*_#{name}.rb")).any?
      end
    end
  end
end
