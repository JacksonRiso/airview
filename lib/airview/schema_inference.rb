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
        model_name: model.name,
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
      model.columns.each_with_index.filter_map do |column, index|
        next if sensitive?(column.name)

        field_attributes_for(column, index)
      end
    end

    private

    def field_attributes_for(column, index)
      association = belongs_to_association_for(column.name)
      target_class = association_class(association)
      name = association&.name || column.name

      {
        name:,
        label: name.to_s.humanize,
        field_type: association ? :belongs_to : field_type(column),
        visible: true,
        readonly: readonly?(column),
        position: index,
        association_name: association&.name,
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
      association&.klass
    rescue NameError
      nil
    end

    def field_type(column)
      TYPE_MAP.fetch(column.type, :string)
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
