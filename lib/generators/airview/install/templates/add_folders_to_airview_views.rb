# frozen_string_literal: true

class AddFoldersToAirviewViews < ActiveRecord::Migration[7.1]
  def change
    add_column :airview_views, :folder, :string unless column_exists?(:airview_views, :folder)
    add_index :airview_views, %i[resource_key folder] unless index_exists?(:airview_views, %i[resource_key folder])
  end
end
