# frozen_string_literal: true

require "test_helper"
require "active_record"

class AirviewQueryTest < Minitest::Test
  class QueryTestModel
    def self.arel_table
      ::Arel::Table.new(:query_test_models)
    end
  end

  class QueryTestScope
    attr_reader :negated_clauses

    def initialize
      @negated_clauses = []
    end

    def klass
      QueryTestModel
    end

    def where(*)
      self
    end

    def not(clause)
      negated_clauses << clause
      self
    end
  end

  def test_does_not_contain_uses_negated_like_match
    resource = Airview::Resource.new(:query_test_models, model: "AirviewQueryTest::QueryTestModel")
    field = resource.field(:name, type: :string)
    scope = QueryTestScope.new

    Airview::Query.new(resource).send(:apply_text_filter, scope, field, "does_not_contain", "venue")

    assert_equal 1, scope.negated_clauses.length
    assert_instance_of Arel::Nodes::Matches, scope.negated_clauses.first
    assert_equal "%venue%", scope.negated_clauses.first.right.instance_variable_get(:@value)
  end
end
