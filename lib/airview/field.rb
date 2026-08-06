# frozen_string_literal: true

module Airview
  class Field
    TYPES = %i[
      string text integer float decimal boolean date datetime select belongs_to has_many attachment json
    ].freeze

    attr_reader :name, :label, :type, :options, :model, :label_method

    def initialize(name, type:, label: nil, readonly: false, options: nil, model: nil, label_method: nil,
                   default_visible: true)
      @name = name.to_sym
      @label = label.presence || name.to_s.humanize
      @type = type.to_sym
      @readonly = readonly
      @options = options
      @model = model
      @label_method = label_method || :to_s
      @default_visible = default_visible
    end

    def readonly?
      @readonly
    end

    def editable?
      !readonly? && !display_only?
    end

    def default_visible?
      @default_visible
    end

    def association?
      type.in?(%i[belongs_to has_many])
    end

    def collection_association?
      type == :has_many
    end

    def attachment?
      type == :attachment
    end

    def display_only?
      collection_association? || attachment?
    end

    def filterable?
      !display_only?
    end

    def sortable?
      !display_only?
    end

    def attribute_name
      type == :belongs_to ? :"#{name}_id" : name
    end

    def validate!
      return if TYPES.include?(type)

      raise ConfigurationError, "Unsupported Airview field type #{type.inspect} for #{name}"
    end

    def model_class
      return nil unless model

      model.to_s.constantize
    end

    def option_values
      return [] unless options

      options.respond_to?(:call) ? options.call : options
    end
  end
end
