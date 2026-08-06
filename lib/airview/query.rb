# frozen_string_literal: true

module Airview
  class Query
    DEFAULT_LIMIT = 50
    MAX_LIMIT = 200

    attr_reader :resource, :params

    def initialize(resource, params = {})
      @resource = resource
      @params = params || {}
    end

    def records
      scope = resource.model_class.all
      scope = apply_search(scope)
      scope = apply_filters(scope)
      scope = apply_sort(scope)
      scope.limit(limit).offset(offset)
    end

    def count
      apply_filters(apply_search(resource.model_class.all)).count
    end

    def limit
      value = params[:limit].presence || DEFAULT_LIMIT
      [[value.to_i, 1].max, MAX_LIMIT].min
    end

    def page
      [params[:page].to_i, 1].max
    end

    def offset
      (page - 1) * limit
    end

    private

    def apply_search(scope)
      term = params[:q].to_s.strip
      return scope if term.empty?

      searchable = resource.fields.values.select { |field| %i[string text select].include?(field.type) }
      return scope if searchable.empty?

      clauses = searchable.map do |field|
        scope.klass.arel_table[field.attribute_name].matches("%#{sanitize_like(term)}%")
      end
      scope.where(clauses.reduce { |query, clause| query.or(clause) })
    end

    def apply_filters(scope)
      filters = params[:filters].respond_to?(:to_unsafe_h) ? params[:filters].to_unsafe_h : params[:filters]
      return scope unless filters.respond_to?(:each)

      filters.each do |name, value|
        next if value.blank?

        field = resource.fields[name.to_sym]
        next unless field

        scope = apply_filter(scope, field, value)
      end
      scope
    end

    def apply_filter(scope, field, value)
      case field.type
      when :string, :text, :select
        scope.where(scope.klass.arel_table[field.attribute_name].matches("%#{sanitize_like(value)}%"))
      when :boolean
        scope.where(field.attribute_name => ActiveModel::Type::Boolean.new.cast(value))
      when :integer
        scope.where(field.attribute_name => value.to_i)
      else
        scope.where(field.attribute_name => value)
      end
    end

    def apply_sort(scope)
      sort = params[:sort].to_s
      return scope if sort.empty?

      direction = params[:direction].to_s.downcase == "desc" ? :desc : :asc
      field = resource.fields[sort.to_sym]
      return scope unless field

      scope.order(field.attribute_name => direction)
    end

    def sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value.to_s)
    end
  end
end
