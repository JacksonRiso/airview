# frozen_string_literal: true

require_relative "airview/version"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/string/inflections"
require "bigdecimal"
require "json"
require_relative "airview/configuration"
require_relative "airview/field"
require_relative "airview/resource"
require_relative "airview/query"
require_relative "airview/model_discovery"
require_relative "airview/resource_builder"
require_relative "airview/schema_inference"
require_relative "airview/engine" if defined?(Rails)

module Airview
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class UnknownResourceError < Error; end

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

    private

    def database_resources_available?
      return false unless ActiveRecord::Base.connected?

      ActiveRecord::Base.connection.data_source_exists?("airview_resources")
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      false
    end
  end
end
