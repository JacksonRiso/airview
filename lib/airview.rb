# frozen_string_literal: true

require_relative "airview/version"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/inflections"
require "bigdecimal"
require "json"
require_relative "airview/configuration"
require_relative "airview/field"
require_relative "airview/resource"
require_relative "airview/query"
require_relative "airview/model_discovery"
require_relative "airview/resource_builder"
require_relative "airview/resource_synchronizer"
require_relative "airview/schema_inference"
require_relative "airview/engine" if defined?(Rails)

module Airview
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class UnknownResourceError < Error; end
  RECORD_LABEL_METHODS = %i[
    name
    title
    email
    username
    display_name
    company_name
    label
  ].freeze

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def resources
      if defined?(Airview::ResourceDefinition) && database_resources_available?
        ResourceBuilder.enabled_resources
      else
        {}
      end
    end

    def resource!(key)
      resources.fetch(key.to_sym) do
        raise UnknownResourceError, "Airview resource #{key.inspect} is not registered"
      end
    end

    def record_label(record, preferred_method = nil)
      return "" unless record

      label = label_from_method(record, preferred_method)
      label ||= label_from_method(record, :full_name)
      label ||= label_from_full_name_parts(record)
      label ||= RECORD_LABEL_METHODS.lazy.filter_map { |method_name| label_from_method(record, method_name) }.first
      label.presence || "#{record.class.model_name.human} ##{record.id}"
    end

    private

    def label_from_method(record, method_name)
      return nil if method_name.blank? || method_name.to_sym == :to_s
      return nil unless record.respond_to?(method_name)

      value = record.public_send(method_name).to_s.strip
      return nil if value.blank? || value.start_with?("#<")

      value
    end

    def label_from_full_name_parts(record)
      return nil unless record.respond_to?(:first_name) && record.respond_to?(:last_name)

      [record.public_send(:first_name), record.public_send(:last_name)].compact.join(" ").strip.presence
    end

    def database_resources_available?
      return false unless ActiveRecord::Base.connected?

      ActiveRecord::Base.connection.data_source_exists?("airview_resources")
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      false
    end
  end
end
