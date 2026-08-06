# frozen_string_literal: true

module Airview
  class ViewsController < ApplicationController
    before_action :set_resource

    def create
      view = View.create!(
        name: params[:name].presence || "Untitled view",
        resource_key: @resource.key,
        folder: params[:folder],
        filters: filter_params,
        sorts: sort_params,
        columns: column_params.presence || @resource.default_fields.map { |field| field.name.to_s },
        preferences: {}
      )

      redirect_to resource_view_records_path(@resource.key, view), notice: "View saved"
    end

    def update
      view = View.for_resource(@resource.key).find(params[:id])
      view.update!(view_update_attributes)

      redirect_to resource_view_records_path(@resource.key, view), notice: "View updated"
    end

    def destroy
      View.for_resource(@resource.key).find(params[:id]).destroy!
      redirect_to resource_path(@resource.key), notice: "View deleted"
    end

    private

    def set_resource
      @resource = Airview.resource!(params[:key])
    end

    def filter_params
      filters = params[:filters]
      return [] unless filters.respond_to?(:values)

      filters.values.filter_map do |condition|
        permitted = condition.permit(:field, :field_label, :operator, :value)
        field = permitted[:field]
        field = field_name_from_label(permitted) if @resource.fields[field.to_s.to_sym].nil?
        next if field.blank? || permitted[:operator].blank?
        next unless @resource.fields[field.to_s.to_sym]

        { "field" => field.to_s, "operator" => permitted[:operator], "value" => permitted[:value] }
      end
    end

    def field_name_from_label(condition)
      @resource.fields.values.find { |field| field.label == condition[:field_label] }&.name
    end

    def sort_params
      params.permit(:sort, :direction).to_h.compact
    end

    def column_params
      Array(params[:columns]).select { |name| @resource.fields.key?(name.to_sym) }
    end

    def view_update_attributes
      {}.tap do |attributes|
        attributes[:name] = params[:name] if params.key?(:name)
        attributes[:folder] = params[:folder] if params.key?(:folder)
        attributes[:filters] = filter_params if params.key?(:filters) || params.key?(:filters_present)
        attributes[:sorts] = sort_params if params.key?(:sort) || params.key?(:direction)
        attributes[:columns] = column_params if params.key?(:columns) || params.key?(:columns_present)
      end
    end
  end
end
