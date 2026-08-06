# frozen_string_literal: true

module Airview
  class Field
    TYPES = %i[
      string text integer float decimal boolean date datetime select belongs_to json
    ].freeze

    attr_reader :name, :label, :type, :options, :model, :label_method

    def initialize(name, type:, label: nil, readonly: false, options: nil, model: nil, label_method: nil)
      @name = name.to_sym
      @label = label.presence || name.to_s.humanize
      @type = type.to_sym
      @readonly = readonly
      @options = options
      @model = model
      @label_method = label_method || :to_s
    end

    def readonly?
      @readonly
    end

    def editable?
      !readonly?
    end

    def association?
      type == :belongs_to
    end

    def attribute_name
      association? ? :"#{name}_id" : name
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
