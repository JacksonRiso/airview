# frozen_string_literal: true

class CreateAirviewViews < ActiveRecord::Migration[7.1]
  def change
    create_table :airview_resources do |t|
      t.string :key, null: false
      t.string :record_class_name, null: false
      t.string :label, null: false
      t.string :label_method
      t.boolean :enabled, null: false, default: false
      t.integer :position, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :airview_resources, :key, unique: true
    add_index :airview_resources, :record_class_name, unique: true
    add_index :airview_resources, :enabled

    create_table :airview_fields do |t|
      t.references :airview_resource, null: false, foreign_key: { to_table: :airview_resources }
      t.string :name, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.boolean :visible, null: false, default: true
      t.boolean :read_only, null: false, default: false
      t.integer :position, null: false, default: 0
      t.string :association_name
      t.string :target_model_name
      t.string :target_label_method
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :airview_fields, %i[airview_resource_id name], unique: true
    add_index :airview_fields, :visible

    create_table :airview_views do |t|
      t.string :name, null: false
      t.string :resource_key, null: false
      t.string :owner_key
      t.string :folder
      t.json :columns, null: false, default: []
      t.json :filters, null: false, default: {}
      t.json :sorts, null: false, default: {}
      t.json :preferences, null: false, default: {}

      t.timestamps
    end

    add_index :airview_views, :resource_key
    add_index :airview_views, %i[resource_key folder]
    add_index :airview_views, %i[resource_key name]
  end
end
