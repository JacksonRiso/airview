# frozen_string_literal: true

module Airview
  class SetupController < ApplicationController
    before_action :set_definition, only: %i[edit update sync destroy]

    def index
      @models = ModelDiscovery.models
      @definitions_by_model = ResourceDefinition.all.index_by(&:record_class_name)
    end

    def new
      @model = ModelDiscovery.model_named(params[:model_name])
      raise ActionController::RoutingError, "Not Found" unless @model

      @definition = build_definition(@model)
    end

    def create
      @definition = ResourceDefinition.new(resource_definition_params)

      if @definition.save
        redirect_to setup_path, notice: "Resource saved"
      else
        @model = ModelDiscovery.model_named(@definition.record_class_name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @definition.update(resource_definition_params.except(:key, :record_class_name))
        redirect_to setup_path, notice: "Resource updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def sync
      added_count = ResourceSynchronizer.new(@definition).sync_missing_fields
      field_label = "field".pluralize(added_count)
      redirect_to edit_setup_resource_path(@definition), notice: "#{added_count} #{field_label} added"
    end

    def destroy
      @definition.destroy!
      redirect_to setup_path, notice: "Resource removed"
    end

    private

    def set_definition
      @definition = ResourceDefinition.includes(:field_definitions).find(params[:id])
    end

    def build_definition(model)
      inference = SchemaInference.new(model)
      ResourceDefinition.new(normalized_resource_attributes(inference.resource_attributes)).tap do |definition|
        inference.field_attributes.each do |attributes|
          definition.field_definitions.build(attributes)
        end
      end
    end

    def normalized_resource_attributes(attributes)
      attributes = attributes.dup
      attributes[:record_class_name] ||= attributes.delete(:model_name)
      attributes
    end

    def resource_definition_params
      params.require(:resource_definition).permit(
        :key,
        :record_class_name,
        :label,
        :label_method,
        :enabled,
        :position,
        field_definitions_attributes: %i[
          id
          name
          label
          field_type
          visible
          read_only
          position
          association_name
          target_model_name
          target_label_method
          _destroy
        ]
      )
    end
  end
end
