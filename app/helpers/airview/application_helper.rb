# frozen_string_literal: true

module Airview
  module ApplicationHelper
    def airview_field_value(record, field)
      value = record.public_send(field.name)
      return value.public_send(field.label_method).to_s if field.association? && value
      return value.to_json if field.type == :json && value.present?

      value
    end

    def airview_input_for(record, field)
      value = airview_field_value(record, field)
      name = "record[#{field.name}]"

      case field.type
      when :boolean
        check_box_tag(name, "1", ActiveModel::Type::Boolean.new.cast(value), disabled: field.readonly?)
      when :text, :json
        text_area_tag(name, value, rows: 2, disabled: field.readonly?)
      when :select
        select_tag(name, options_for_select(field.option_values, value), include_blank: true, disabled: field.readonly?)
      when :belongs_to
        options = association_options(field, record)
        select_tag(
          name,
          options_for_select(options, record.public_send(field.attribute_name)),
          include_blank: true,
          disabled: field.readonly?
        )
      when :date
        date_field_tag(name, value, disabled: field.readonly?)
      when :datetime
        datetime_local_field_tag(name, value&.strftime("%Y-%m-%dT%H:%M"), disabled: field.readonly?)
      else
        text_field_tag(name, value, disabled: field.readonly?)
      end
    end

    def airview_sort_link(resource, field)
      direction = params[:sort] == field.name.to_s && params[:direction] != "desc" ? "desc" : "asc"
      link_to(
        field.label,
        resource_path(resource.key, request.query_parameters.merge(sort: field.name, direction:))
      )
    end

    private

    def association_options(field, record)
      selected = record.public_send(field.name)
      records = field.model_class.limit(50).to_a
      records << selected if selected && records.exclude?(selected)
      records.compact.uniq.map { |option| [option.public_send(field.label_method).to_s, option.id] }
    end
  end
end
