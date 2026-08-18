# frozen_string_literal: true

module Airview
  module ApplicationHelper
    def airview_field_value(record, field)
      return nil unless airview_field_available?(record, field)

      value = record.public_send(field.name)
      return value if field.collection_association?
      return Airview.record_label(value, field.label_method) if field.association? && value
      return value.to_json if field.type == :json && value.present?

      value
    end

    def airview_cell_value(record, field)
      value = airview_field_value(record, field)
      return tag.span("", class: "airview-empty-value") unless airview_field_available?(record, field)

      case field.type
      when :boolean
        tag.span(value ? "✓" : "", class: ["airview-check", ("is-on" if value)])
      when :belongs_to
        airview_reference_pill(record, field)
      when :has_many
        airview_collection_pills(record, field)
      when :attachment
        airview_attachment_cell(record, field)
      when :select
        value.present? ? tag.span(value, class: "airview-pill") : tag.span("", class: "airview-empty-value")
      when :date
        value.present? ? l(value.to_date, format: :default) : tag.span("", class: "airview-empty-value")
      when :datetime
        value.present? ? l(value, format: :short) : tag.span("", class: "airview-empty-value")
      else
        tag.span(value, class: "airview-cell-text")
      end
    end

    def airview_input_for(record, field)
      value = airview_field_value(record, field)
      name = "record[#{field.name}]"
      return text_field_tag(name, nil, disabled: true) unless airview_field_available?(record, field)

      case field.type
      when :boolean
        check_box_tag(name, "1", ActiveModel::Type::Boolean.new.cast(value), disabled: field.readonly?)
      when :text, :json
        text_area_tag(name, value, rows: 2, disabled: field.readonly?)
      when :select
        select_tag(name, options_for_select(field.option_values, value), include_blank: true, disabled: field.readonly?)
      when :belongs_to
        airview_reference_input(record, field, name)
      when :date
        date_field_tag(name, value, disabled: field.readonly?)
      when :datetime
        datetime_local_field_tag(name, value&.strftime("%Y-%m-%dT%H:%M"), disabled: field.readonly?)
      else
        text_field_tag(name, value, disabled: field.readonly?)
      end
    end

    def airview_sort_link(resource, field)
      active = airview_active_sort_field == field.name.to_s
      current_direction = airview_active_sort_direction
      direction = active && current_direction != "desc" ? "desc" : "asc"

      link_to(
        resource_path(resource.key, request.query_parameters.merge(sort: field.name, direction:)),
        class: ["airview-sort-link", ("is-active" if active)]
      ) do
        safe_join(
          [
            tag.span(field.label, class: "airview-column-label"),
            airview_sort_indicator(active, current_direction)
          ].compact
        )
      end
    end

    def airview_sort_indicator(active, direction)
      return nil unless active

      tag.span(direction == "desc" ? "↓" : "↑", class: "airview-sort-indicator")
    end

    def airview_active_sort_field
      params[:sort].presence || @active_view&.sorts&.dig("sort")
    end

    def airview_active_sort_direction
      (params[:direction].presence || @active_view&.sorts&.dig("direction") || "asc").to_s
    end

    def airview_column_action_path
      @active_view ? resource_view_path(@resource.key, @active_view) : resource_path(@resource.key)
    end

    def airview_column_action_params(action, field)
      columns = @visible_fields.map { |visible_field| visible_field.name.to_s }
      columns = reorder_columns(columns, field.name.to_s, action)
      columns -= [field.name.to_s] if action == :hide

      if @active_view
        { columns_present: "1", columns: }
      else
        request.query_parameters.merge(columns_present: "1", columns:)
      end
    end

    def airview_column_action_method
      @active_view ? :patch : :get
    end

    def airview_current_table_path
      query = request.query_parameters.except(:record_id, :delete_record_id, :return_to)
      query_string = query.to_query

      query_string.present? ? "#{request.path}?#{query_string}" : request.path
    end

    def airview_modal_close_path
      return_to = params[:return_to].to_s
      return return_to if return_to.start_with?("/") && !return_to.start_with?("//")

      airview_current_table_path
    end

    def airview_record_modal_path(resource, record)
      resource_path(resource.key, record_id: record.id, return_to: airview_current_table_path)
    end

    def airview_filter_operator_options(field, selected = nil)
      options = case field.type
                when :boolean
                  [["is checked", "is_true"], ["is unchecked", "is_false"]]
                when :integer, :float, :decimal
                  [["=", "equals"], [">", "gt"], ["<", "lt"], [">=", "gte"], ["<=", "lte"], ["is empty", "is_empty"], ["is not empty", "is_not_empty"]]
                when :date, :datetime
                  [["is", "equals"], ["before", "before"], ["after", "after"], ["is empty", "is_empty"], ["is not empty", "is_not_empty"]]
                else
                  [
                    ["contains", "contains"],
                    ["does not contain", "does_not_contain"],
                    ["equals", "equals"],
                    ["starts with", "starts_with"],
                    ["is empty", "is_empty"],
                    ["is not empty", "is_not_empty"]
                  ]
                end

      options_for_select(options, selected)
    end

    def airview_filter_value_input(index, field, value = nil)
      name = "filters[#{index}][value]"

      case field&.type
      when :boolean
        select_tag(
          name,
          options_for_select([%w[checked true], %w[unchecked false]], value.to_s),
          data: { airview_filter_value: true }
        )
      when :date, :datetime
        date_field_tag(name, value, data: { airview_filter_value: true })
      when :integer, :float, :decimal
        number_field_tag(name, value, step: "any", placeholder: "Value", data: { airview_filter_value: true })
      else
        text_field_tag(name, value, placeholder: "Enter a value", data: { airview_filter_value: true })
      end
    end

    def airview_filter_field_picker(index, field)
      safe_join(
        [
          hidden_field_tag("filters[#{index}][field]", field&.name, data: { airview_field_target: true }),
          airview_filter_field_picker_menu(index, field)
        ]
      )
    end

    def airview_delete_impacts(record)
      record.class.reflect_on_all_associations.filter_map do |association|
        dependent = association.options[:dependent]
        next unless dependent

        {
          name: association.name.to_s.humanize,
          dependent: dependent.to_s.humanize.downcase,
          count: airview_association_count(record, association),
          action: airview_dependent_action(dependent)
        }
      end
    end

    def airview_reference_pill(record, field)
      return tag.span("", class: "airview-empty-value") unless airview_field_available?(record, field)

      related = record.public_send(field.name)
      return tag.span("+ Link record", class: "airview-reference-empty") unless related

      label = Airview.record_label(related, field.label_method)
      linked_resource = airview_resource_for_model(field.model)
      path = linked_resource ? airview_record_modal_path(linked_resource, related) : nil

      if path
        link_to(label, path, class: "airview-reference-pill")
      else
        tag.span(label, class: "airview-reference-pill")
      end
    end

    def airview_collection_pills(record, field)
      return tag.span("0 records", class: "airview-reference-empty") unless airview_field_available?(record, field)

      records = record.public_send(field.name).limit(3).to_a
      count = airview_collection_count(record, field)

      return tag.span("0 records", class: "airview-reference-empty") if count.to_i.zero?

      linked_resource = airview_resource_for_model(field.model)
      collection_path = airview_collection_path(record, field, linked_resource)
      cards = records.map do |related|
        airview_collection_record_card(related, field, linked_resource)
      end

      cards << airview_collection_count_pill(count - records.size, collection_path) if count > records.size

      tag.div(
        safe_join(cards),
        class: "airview-reference-list airview-reference-list--cards",
        title: collection_path ? "Open #{field.label}" : nil
      )
    end

    def airview_attachment_cell(record, field)
      return tag.span("No file", class: "airview-reference-empty") unless airview_field_available?(record, field)

      attachment = record.public_send(field.name)
      return tag.span("No file", class: "airview-reference-empty") unless attachment.attached?

      blob = attachment.blob
      path = airview_attachment_path(attachment)

      link_to(path, class: "airview-attachment", target: "_blank", rel: "noopener") do
        if blob.image?
          image_tag(path, alt: blob.filename.to_s, class: "airview-attachment-thumb")
        else
          tag.span(blob.filename.to_s, class: "airview-attachment-file")
        end
      end
    end

    def airview_reference_input(record, field, name)
      return text_field_tag(name, nil, disabled: true) unless airview_field_available?(record, field)

      related = record.public_send(field.name)

      safe_join(
        [
          hidden_field_tag(name, record.public_send(field.attribute_name), data: { airview_reference_target: true }),
          airview_reference_preview(related, field),
          tag.div(
            class: "airview-reference-picker",
            data: { airview_reference_url: resource_references_path(@resource.key, field.name) }
          ) do
            safe_join(
              [
                search_field_tag(
                  nil,
                  nil,
                  placeholder: "Find linked record",
                  autocomplete: "off",
                  data: { airview_reference_picker: true }
                ),
                tag.div("", class: "airview-reference-results", data: { airview_reference_results: true }),
                airview_reference_clear_button(record, field)
              ].compact
            )
          end
        ]
      )
    end

    private

    def airview_reference_preview(related, field)
      unless related
        return tag.div(
          "+ Link record",
          class: "airview-reference-preview is-empty",
          data: { airview_reference_preview: true }
        )
      end

      linked_resource = airview_resource_for_model(field.model)
      details = airview_reference_details(related, linked_resource)

      tag.div(class: "airview-reference-preview", data: { airview_reference_preview: true }) do
        open_link = if linked_resource
                      link_to(
                        "Open record",
                        airview_record_modal_path(linked_resource, related),
                        class: "airview-reference-open"
                      )
                    end

        safe_join(
          [
            tag.div(Airview.record_label(related, field.label_method), class: "airview-reference-preview-title"),
            (tag.div(details, class: "airview-reference-preview-details") if details.present?),
            open_link
          ].compact
        )
      end
    end

    def airview_filter_field_picker_menu(index, field)
      tag.div(class: "airview-filter-field-picker", data: { airview_filter_field_picker: true }) do
        safe_join(
          [
            search_field_tag(
              "filters[#{index}][field_label]",
              field&.label,
              placeholder: "Find field",
              autocomplete: "off",
              data: { airview_filter_field_search: true }
            ),
            airview_filter_field_options
          ]
        )
      end
    end

    def airview_filter_field_options
      tag.div(class: "airview-filter-field-results", data: { airview_filter_field_results: true }) do
        safe_join(@sorted_fields.select(&:filterable?).map { |option| airview_filter_field_option(option) })
      end
    end

    def airview_filter_field_option(option)
      button_tag(
        option.label,
        type: "button",
        class: "airview-filter-field-option",
        data: {
          airview_filter_field_option: true,
          field_name: option.name,
          field_label: option.label,
          field_type: option.type
        }
      )
    end

    def airview_attachment_path(attachment)
      main_app.rails_blob_path(attachment, only_path: true)
    end

    def airview_collection_count_pill(count, path)
      label = "+#{count}"
      return tag.span(label, class: "airview-reference-preview airview-reference-preview--compact") unless path

      link_to(path, class: airview_reference_card_class) do
        safe_join(
          [
            tag.div(label, class: "airview-reference-preview-title"),
            tag.div("Open #{label} more", class: "airview-reference-preview-details")
          ]
        )
      end
    end

    def airview_collection_record_card(record, field, linked_resource)
      path = linked_resource ? airview_record_modal_path(linked_resource, record) : nil
      content = safe_join(
        [
          tag.div(Airview.record_label(record, field.label_method), class: "airview-reference-preview-title"),
          tag.div(airview_reference_details(record, linked_resource), class: "airview-reference-preview-details"),
          (tag.div("Open record", class: "airview-reference-open") if path)
        ].compact
      )

      if path
        link_to(path, class: airview_reference_card_class) do
          content
        end
      else
        tag.div(content, class: "airview-reference-preview airview-reference-preview--compact")
      end
    end

    def airview_reference_card_class
      "airview-reference-preview airview-reference-preview--compact airview-reference-card-link"
    end

    def airview_collection_path(record, field, linked_resource)
      return nil unless linked_resource

      inverse_field = airview_collection_inverse_field(record, field, linked_resource)
      return nil unless inverse_field

      resource_path(
        linked_resource.key,
        filters_present: "1",
        filters: {
          "0" => {
            field: inverse_field.name,
            operator: "equals",
            value: record.id
          }
        }
      )
    end

    def airview_collection_inverse_field(record, field, linked_resource)
      association = record.class.reflect_on_association(field.name)
      foreign_key = association&.foreign_key&.to_s

      linked_resource.fields.values.find do |candidate|
        candidate.type == :belongs_to &&
          (candidate.attribute_name.to_s == foreign_key || candidate.model.to_s == record.class.name)
      end
    rescue NoMethodError
      nil
    end

    def airview_reference_clear_button(record, field)
      column = record.class.columns_hash[field.attribute_name.to_s]
      return nil if column && !column.null

      button_tag(
        "Clear link",
        type: "button",
        class: "airview-reference-clear",
        data: { airview_reference_clear: true }
      )
    end

    def airview_reference_details(record, linked_resource)
      return "##{record.id}" unless linked_resource

      linked_resource.fields.values.reject(&:association?).first(3).filter_map do |field|
        next unless airview_field_available?(record, field)

        value = airview_field_value(record, field)
        "#{field.label}: #{value}" if value.present?
      end.join(" · ")
    end

    def airview_field_available?(record, field)
      model_class = record.class

      case field.type
      when :belongs_to
        association = model_class.reflect_on_association(field.name) if model_class.respond_to?(:reflect_on_association)
        association&.macro == :belongs_to && model_class.column_names.include?(association.foreign_key.to_s)
      when :has_many
        association = model_class.reflect_on_association(field.name) if model_class.respond_to?(:reflect_on_association)
        association&.macro == :has_many
      when :attachment
        model_class.respond_to?(:attachment_reflections) &&
          model_class.attachment_reflections.key?(field.name.to_s)
      else
        model_class.respond_to?(:column_names) && model_class.column_names.include?(field.name.to_s)
      end
    rescue ActiveRecord::StatementInvalid, NameError
      false
    end

    def airview_resource_for_model(model)
      Airview.resources.values.find { |resource| resource.model == model.to_s }
    end

    def airview_association_count(record, association)
      related = record.public_send(association.name)
      return related.count if related.respond_to?(:count) && association.collection?

      related.present? ? 1 : 0
    rescue ActiveRecord::StatementInvalid, NoMethodError
      nil
    end

    def airview_collection_count(record, field)
      record.public_send(field.name).count
    rescue ActiveRecord::StatementInvalid, NoMethodError
      0
    end

    def airview_dependent_action(dependent)
      case dependent
      when :destroy, :delete, :delete_all, :destroy_async
        "deleted"
      when :nullify
        "detached"
      when :restrict_with_error, :restrict_with_exception
        "may block deletion"
      else
        dependent.to_s.humanize.downcase
      end
    end

    def reorder_columns(columns, field_name, action)
      index = columns.index(field_name)
      return columns unless index

      direction = action == :left ? -1 : 1
      target = index + direction
      return columns unless target.between?(0, columns.length - 1)

      columns[index], columns[target] = columns[target], columns[index]
      columns
    end
  end
end
