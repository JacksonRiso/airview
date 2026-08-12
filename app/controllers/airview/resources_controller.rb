# frozen_string_literal: true

module Airview
  class ResourcesController < ApplicationController
    before_action :set_resource, except: :index

    def index
      @resources = Airview.resources.values
      if @resources.any?
        redirect_to resource_path(@resources.first.key)
      else
        redirect_to setup_path
      end
    end

    def show
      @resources = Airview.resources.values
      return render(:empty) if @resource.fields.empty?

      @views = View.for_resource(@resource.key).ordered
      @active_view = @views.find { |view| view.id.to_s == params[:view_id].to_s }
      @sorted_fields = @resource.fields.values.sort_by { |field| field.label.downcase }
      @visible_fields = visible_fields
      @filter_conditions = filter_conditions
      @query = Query.new(@resource, query_params.merge(filters: @filter_conditions))
      @records = @query.records
      @record = @resource.model_class.new
      @expanded_record = expanded_record
      @delete_record = delete_record
    end

    def create
      record = @resource.model_class.new(record_attributes)

      if record.save
        redirect_to resource_path(@resource.key), notice: "Record created"
      else
        redirect_to resource_path(@resource.key), alert: record.errors.full_messages.to_sentence
      end
    end

    def update
      record = @resource.model_class.find(params[:id])

      if record.update(record_attributes)
        redirect_back fallback_location: resource_path(@resource.key), notice: "Record updated"
      else
        redirect_back fallback_location: resource_path(@resource.key), alert: record.errors.full_messages.to_sentence
      end
    end

    def destroy
      record = @resource.model_class.find(params[:id])
      record.destroy!
      redirect_to safe_return_path || resource_path(@resource.key), notice: "Record deleted"
    end

    def references
      field = @resource.field!(params[:field])
      raise ActionController::RoutingError, "Not Found" unless field.association?

      scope = field.model_class.all
      term = params[:q].to_s.strip
      scope = filter_reference_scope(scope, field, term) if term.present?

      render json: scope.limit(20).map { |record| reference_payload(record, field) }
    end

    private

    def set_resource
      @resource = Airview.resource!(params[:key])
    end

    def safe_return_path
      return_to = params[:return_to].to_s
      return nil unless return_to.start_with?("/") && !return_to.start_with?("//")

      return_to
    end

    def query_params
      permitted = params.permit(:q, :sort, :direction, :page, :limit, filters: %i[field operator value])
      view_sorts = @active_view&.sorts || {}

      permitted[:sort] ||= view_sorts["sort"]
      permitted[:direction] ||= view_sorts["direction"]
      permitted
    end

    def visible_fields
      column_names = if params.key?(:columns_present)
                       Array(params[:columns]).flat_map { |value| value.to_s.split(",") }
                     elsif params[:columns].present?
                       Array(params[:columns]).flat_map { |value| value.to_s.split(",") }
                     elsif @active_view
                       @active_view.ordered_columns(@resource)
                     else
                       @resource.default_fields.map { |field| field.name.to_s }
                     end

      column_names.filter_map { |name| @resource.fields[name.to_sym] }
    end

    def expanded_record
      return nil if params[:record_id].blank?

      @resource.model_class.find_by(id: params[:record_id])
    end

    def delete_record
      return nil if params[:delete_record_id].blank?

      @resource.model_class.find_by(id: params[:delete_record_id])
    end

    def reference_payload(record, field)
      linked_resource = Airview.resources.values.find { |resource| resource.model == field.model.to_s }
      {
        id: record.id,
        label: Airview.record_label(record, field.label_method),
        resource_key: linked_resource&.key,
        open_url: linked_resource ? reference_open_path(linked_resource, record) : nil,
        preview: reference_preview(record, linked_resource)
      }
    end

    def reference_open_path(resource, record)
      resource_path(resource.key, record_id: record.id, return_to: current_table_path)
    end

    def current_table_path
      query = request.query_parameters.except(:record_id, :delete_record_id, :return_to)
      query_string = query.to_query

      query_string.present? ? "#{request.path}?#{query_string}" : request.path
    end

    def reference_preview(record, linked_resource)
      preview_fields = if linked_resource
                         linked_resource.fields.values.reject(&:association?).first(3)
                       else
                         reference_preview_columns(record.class).map do |column_name|
                           [column_name, column_name.to_s.humanize]
                         end
                       end

      preview_fields.filter_map do |preview_field|
        name, label = if preview_field.respond_to?(:name)
                        [preview_field.name, preview_field.label]
                      else
                        preview_field
                      end
        value = record.public_send(name)
        next if value.blank?

        { label:, value: value.to_s }
      end
    end

    def filter_reference_scope(scope, field, term)
      columns = searchable_reference_columns(field.model_class, field.label_method)
      id_scope = reference_id_scope(scope, term)
      return id_scope || scope if columns.empty?

      table = field.model_class.arel_table
      escaped = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
      predicate = columns.map { |column_name| table[column_name].matches(escaped) }.reduce(&:or)
      text_scope = scope.where(predicate)

      id_scope ? text_scope.or(id_scope) : text_scope
    end

    def searchable_reference_columns(model_class, preferred_method)
      candidates = [preferred_method, :full_name, :name, :title, :email, :username, :display_name, :company_name]
      column_names = model_class.column_names

      candidates.compact.map(&:to_s).uniq.select { |name| column_names.include?(name) }
    end

    def reference_id_scope(scope, term)
      return nil unless term.match?(/\A\d+\z/) && scope.klass.column_names.include?("id")

      scope.where(id: term)
    end

    def reference_preview_columns(model_class)
      preferred = %w[email username company_name title name created_at]
      columns = model_class.column_names - %w[id]

      (preferred & columns).presence || columns.first(3)
    end

    def filter_conditions
      request_filters = params[:filters]
      return [] if params.key?(:filters_present)
      return normalized_filters(request_filters) if request_filters.present?
      return normalized_filters(@active_view.filters) if @active_view&.filters.present?

      []
    end

    def normalized_filters(filters)
      filter_list(filters).filter_map do |condition|
        normalized_filter(condition)
      end
    end

    def normalized_filter(condition)
      return nil unless condition.respond_to?(:[])

      field = condition["field"] || condition[:field]
      field = field_name_from_label(condition) if @resource.fields[field.to_s.to_sym].nil?
      operator = condition["operator"] || condition[:operator]
      value = condition["value"] || condition[:value]
      return nil if field.blank? || operator.blank?
      return nil unless @resource.fields[field.to_s.to_sym]

      { "field" => field.to_s, "operator" => operator.to_s, "value" => value }
    end

    def field_name_from_label(condition)
      label = condition["field_label"] || condition[:field_label]
      @resource.fields.values.find { |field| field.label == label }&.name
    end

    def filter_list(filters)
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      filters = filters.values if filters.is_a?(Hash)
      Array(filters)
    end

    def record_attributes
      raw = params.fetch(:record, {}).permit!
      @resource.editable_fields.each_with_object({}) do |field, attributes|
        next unless raw.key?(field.name.to_s)

        attributes[field.attribute_name] = cast_value(field, raw[field.name.to_s])
      end
    end

    def cast_value(field, value)
      return nil if value == ""

      case field.type
      when :boolean
        ActiveModel::Type::Boolean.new.cast(value)
      when :integer
        value.to_i
      when :float
        value.to_f
      when :decimal
        BigDecimal(value.to_s)
      when :json
        JSON.parse(value)
      else
        value
      end
    rescue JSON::ParserError, ArgumentError
      value
    end
  end
end
