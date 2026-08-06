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
      @query = Query.new(@resource, query_params)
      @records = @query.records
      @record = @resource.model_class.new
      @views = View.for_resource(@resource.key).order(:name)
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
      redirect_to resource_path(@resource.key), notice: "Record deleted"
    end

    def references
      field = @resource.field!(params[:field])
      raise ActionController::RoutingError, "Not Found" unless field.association?

      scope = field.model_class.limit(20)
      term = params[:q].to_s.strip
      if term.present? && field.label_method
        table = field.model_class.arel_table
        scope = scope.where(table[field.label_method].matches("%#{ActiveRecord::Base.sanitize_sql_like(term)}%"))
      end

      render json: scope.map { |record| { id: record.id, label: record.public_send(field.label_method).to_s } }
    end

    private

    def set_resource
      @resource = Airview.resource!(params[:key])
    end

    def query_params
      params.permit(:q, :sort, :direction, :page, :limit, filters: {})
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
