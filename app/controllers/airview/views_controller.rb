# frozen_string_literal: true

module Airview
  class ViewsController < ApplicationController
    before_action :set_resource

    def create
      View.create!(
        name: params[:name].presence || "Untitled view",
        resource_key: @resource.key,
        filters: params[:filters].presence || {},
        sorts: { sort: params[:sort], direction: params[:direction] }.compact,
        columns: @resource.fields.keys.map(&:to_s),
        preferences: {}
      )

      redirect_to resource_path(@resource.key), notice: "View saved"
    end

    def destroy
      View.for_resource(@resource.key).find(params[:id]).destroy!
      redirect_to resource_path(@resource.key), notice: "View deleted"
    end

    private

    def set_resource
      @resource = Airview.resource!(params[:key])
    end
  end
end
