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
      return scope if filters.blank?

      return apply_structured_filters(scope, filters) if structured_filters?(filters)

      filters.each do |name, value|
        next if value.blank?

        field = resource.fields[name.to_sym]
        next unless field

        scope = apply_filter(scope, field, value)
      end
      scope
    end

    def structured_filters?(filters)
      filters.is_a?(Array) || filters.values.first.respond_to?(:key?)
    rescue NoMethodError
      false
    end

    def apply_structured_filters(scope, filters)
      Array(filters.is_a?(Hash) ? filters.values : filters).each do |condition|
        condition = condition.to_unsafe_h if condition.respond_to?(:to_unsafe_h)
        condition = condition.to_h.stringify_keys
        field = resource.fields[condition["field"].to_s.to_sym]
        next unless field
        next unless field.filterable?

        scope = apply_structured_filter(scope, field, condition["operator"], condition["value"])
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

    def apply_structured_filter(scope, field, operator, value)
      return apply_empty_filter(scope, field, operator) if operator.to_s.in?(%w[is_empty is_not_empty])
      return scope if value.blank? && field.type != :boolean

      case field.type
      when :string, :text, :select, :json
        apply_text_filter(scope, field, operator, value)
      when :boolean
        apply_boolean_filter(scope, field, operator, value)
      when :integer, :float, :decimal
        apply_numeric_filter(scope, field, operator, value)
      when :date, :datetime
        apply_date_filter(scope, field, operator, value)
      else
        scope.where(field.attribute_name => value)
      end
    end

    def apply_empty_filter(scope, field, operator)
      empty_values = %i[string text select json].include?(field.type) ? [nil, ""] : [nil]

      if operator == "is_not_empty"
        scope.where.not(field.attribute_name => empty_values)
      else
        scope.where(field.attribute_name => empty_values)
      end
    end

    def apply_text_filter(scope, field, operator, value)
      column = scope.klass.arel_table[field.attribute_name]

      case operator
      when "equals"
        scope.where(field.attribute_name => value)
      when "starts_with"
        scope.where(column.matches("#{sanitize_like(value)}%"))
      else
        scope.where(column.matches("%#{sanitize_like(value)}%"))
      end
    end

    def apply_boolean_filter(scope, field, operator, value)
      boolean = case operator
                when "is_true"
                  true
                when "is_false"
                  false
                else
                  ActiveModel::Type::Boolean.new.cast(value)
                end

      scope.where(field.attribute_name => boolean)
    end

    def apply_numeric_filter(scope, field, operator, value)
      operators = { "gt" => ">", "lt" => "<", "gte" => ">=", "lte" => "<=" }
      sql_operator = operators[operator.to_s]
      return scope.where(field.attribute_name => value) unless sql_operator

      column = scope.connection.quote_column_name(field.attribute_name)
      scope.where("#{column} #{sql_operator} ?", value)
    end

    def apply_date_filter(scope, field, operator, value)
      case operator
      when "before"
        scope.where(scope.klass.arel_table[field.attribute_name].lt(value))
      when "after"
        scope.where(scope.klass.arel_table[field.attribute_name].gt(value))
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
      return scope unless field.sortable?

      scope.order(field.attribute_name => direction)
    end

    def sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value.to_s)
    end
  end
end
