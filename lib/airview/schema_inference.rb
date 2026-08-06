# frozen_string_literal: true

module Airview
  class SchemaInference
    SENSITIVE_PATTERNS = [
      /password/i,
      /token/i,
      /secret/i,
      /api[_-]?key/i,
      /credential/i,
      /encrypted/i,
      /digest/i,
      /reset/i,
      /remember/i
    ].freeze

    TYPE_MAP = {
      string: :string,
      text: :text,
      integer: :integer,
      float: :float,
      decimal: :decimal,
      boolean: :boolean,
      date: :date,
      datetime: :datetime,
      timestamp: :datetime,
      json: :json,
      jsonb: :json
    }.freeze

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def resource_attributes
      {
        key: model.model_name.route_key,
        record_class_name: model.name,
        label: model.model_name.human(count: 2),
        label_method: inferred_label_method,
        enabled: false,
        metadata: {
          table_name: model.table_name,
          inferred_at: Time.current.iso8601
        }
      }
    end

    def field_attributes
      column_fields = model.columns.each_with_index.filter_map do |column, index|
        next if sensitive?(column.name)

        field_attributes_for(column, index)
      end

      column_fields + virtual_field_attributes(column_fields.length)
    end

    private

    def virtual_field_attributes(starting_position)
      collection_fields = collection_field_attributes(starting_position)
      attachment_fields = attachment_field_attributes(starting_position + collection_fields.length)

      collection_fields + attachment_fields
    end

    def collection_field_attributes(starting_position)
      model.reflect_on_all_associations(:has_many).each_with_index.filter_map do |association, index|
        target_class = association_class(association)
        next unless target_class

        {
          name: association.name,
          label: association.name.to_s.humanize,
          field_type: :has_many,
          visible: true,
          read_only: true,
          position: starting_position + index,
          association_name: association.name,
          target_model_name: target_class.name,
          target_label_method: label_method_for(target_class),
          metadata: {
            default_visible: false,
            macro: association.macro.to_s
          }
        }
      end
    rescue NameError
      []
    end

    def attachment_field_attributes(starting_position)
      return [] unless model.respond_to?(:attachment_reflections)

      model.attachment_reflections.values.each_with_index.map do |reflection, index|
        {
          name: reflection.name,
          label: reflection.name.to_s.humanize,
          field_type: :attachment,
          visible: true,
          read_only: true,
          position: starting_position + index,
          association_name: reflection.name,
          target_model_name: nil,
          target_label_method: nil,
          metadata: {
            default_visible: false,
            macro: reflection.macro.to_s
          }
        }
      end
    end

    def field_attributes_for(column, index)
      association = belongs_to_association_for(column.name)
      target_class = association_class(association)
      name = association&.name || column.name
      association_supported = association && target_class

      {
        name:,
        label: name.to_s.humanize,
        field_type: inferred_field_type(column, association_supported),
        visible: true,
        read_only: inferred_readonly?(column, association),
        position: index,
        association_name: association_supported ? association.name : nil,
        target_model_name: target_class&.name,
        target_label_method: target_class ? label_method_for(target_class) : nil,
        metadata: column_metadata(column)
      }
    end

    def belongs_to_association_for(column_name)
      return nil unless column_name.end_with?("_id")

      model.reflect_on_all_associations(:belongs_to).find do |association|
        association.foreign_key.to_s == column_name
      end
    rescue NameError
      nil
    end

    def association_class(association)
      return nil if association&.polymorphic?

      association&.klass
    rescue ArgumentError, NameError
      nil
    end

    def unsupported_association?(association)
      association && !association_class(association)
    end

    def field_type(column)
      TYPE_MAP.fetch(column.type, :string)
    end

    def inferred_field_type(column, association_supported)
      association_supported ? :belongs_to : field_type(column)
    end

    def inferred_readonly?(column, association)
      readonly?(column) || unsupported_association?(association)
    end

    def readonly?(column)
      column.name == model.primary_key || column.name.in?(%w[created_at updated_at])
    end

    def sensitive?(name)
      SENSITIVE_PATTERNS.any? { |pattern| name.match?(pattern) }
    end

    def inferred_label_method
      label_method_for(model)
    end

    def label_method_for(klass)
      %i[name title email username slug].find { |method| klass.column_names.include?(method.to_s) } || :to_s
    end

    def column_metadata(column)
      {
        sql_type: column.sql_type,
        null: column.null,
        default: column.default,
        primary_key: column.name == model.primary_key
      }
    end
  end
end
