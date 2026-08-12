# frozen_string_literal: true

module Airview
  class Resource
    attr_accessor :label, :label_method
    attr_reader :key, :model, :fields

    def initialize(key, model:)
      @key = key.to_sym
      @model = model
      @label = key.to_s.humanize
      @label_method = :to_s
      @fields = {}
      @stale_fields = []
    end

    def field(name, type:, label: nil, **options)
      definition = Field.new(name, type:, label:, **options)
      definition.validate!
      fields[definition.name] = definition
      definition
    end

    def model_class
      model.to_s.constantize
    end

    def field!(name)
      fields.fetch(name.to_sym) do
        raise ConfigurationError, "Unknown Airview field #{name.inspect} for #{key}"
      end
    end

    def editable_fields
      fields.values.select(&:editable?)
    end

    def default_fields
      fields.values.select(&:default_visible?)
    end

    def stale_fields
      @stale_fields.dup
    end

    def add_stale_field(field, reason:)
      @stale_fields << { name: field.name.to_sym, label: field.label, reason: }
    end

    def validate!
      raise ConfigurationError, "Airview resource #{key} must define at least one field" if fields.empty?

      fields.each_value(&:validate!)
    end

    def record_label(record)
      Airview.record_label(record, label_method)
    end
  end
end
