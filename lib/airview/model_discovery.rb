# frozen_string_literal: true

module Airview
  class ModelDiscovery
    EXCLUDED_NAMESPACES = %w[Airview ActiveStorage ActionMailbox ActionText].freeze

    class << self
      def models
        eager_load_application

        ActiveRecord::Base.descendants
                          .select { |model| eligible?(model) }
                          .sort_by(&:name)
      end

      def model_named(name)
        models.find { |model| model.name == name.to_s }
      end

      private

      def eager_load_application
        Rails.application.eager_load! if defined?(Rails) && Rails.application
      rescue Zeitwerk::NameError
        nil
      end

      def eligible?(model)
        model.name.present? &&
          EXCLUDED_NAMESPACES.none? { |namespace| model.name.start_with?("#{namespace}::") } &&
          !model.abstract_class? &&
          model.table_exists?
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        false
      end
    end
  end
end
