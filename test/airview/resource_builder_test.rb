# frozen_string_literal: true

require "test_helper"

class AirviewResourceBuilderTest < Minitest::Test
  FakeAssociation = Struct.new(:macro, :foreign_key)
  FakeColumn = Struct.new(:name, :type, :sql_type, :null, :default)

  class FakeFieldDefinitions
    include Enumerable

    def initialize(fields)
      @fields = fields
    end

    def each(&block)
      @fields.each(&block)
    end

    def visible
      self
    end

    def order(*)
      @fields
    end
  end

  FakeField = Struct.new(
    :name,
    :field_type,
    :label,
    :read_only,
    :target_model_name,
    :target_label_method,
    :association_name,
    :default_visible,
    :position,
    keyword_init: true
  ) do
    def read_only?
      read_only
    end

    def default_visible?
      default_visible.nil? || default_visible
    end
  end

  FakeDefinition = Struct.new(
    :key,
    :record_class_name,
    :label,
    :label_method,
    :field_definitions,
    keyword_init: true
  ) do
    def model_class
      record_class_name.constantize
    end
  end

  class CapturingFieldDefinitions < FakeFieldDefinitions
    attr_reader :created

    def initialize(fields)
      super
      @created = []
    end

    def create!(attributes)
      @created << attributes
    end
  end

  class CompanyLocation
    class << self
      attr_accessor :test_columns

      def model_name
        Struct.new(:human).new("Company location")
      end

      def column_names
        %w[id name vendor_id]
      end

      def columns
        test_columns || []
      end

      def primary_key
        "id"
      end

      def reflect_on_association(name)
        return FakeAssociation.new(:belongs_to, "vendor_id") if name.to_sym == :vendor
        return FakeAssociation.new(:has_many, nil) if name.to_sym == :certificates

        nil
      end

      def reflect_on_all_associations(*)
        []
      end

      def attachment_reflections
        {}
      end
    end
  end

  def test_skips_persisted_fields_for_deleted_columns
    resource = build_resource(
      fields: [
        fake_field(:name, :string),
        fake_field(:searchable_in_vendor_database, :boolean)
      ]
    )

    assert_equal %i[name], resource.fields.keys
    assert_equal :searchable_in_vendor_database, resource.stale_fields.fetch(0).fetch(:name)
    assert_match "missing column", resource.stale_fields.fetch(0).fetch(:reason)
  end

  def test_skips_belongs_to_fields_when_foreign_key_is_missing
    resource = build_resource(
      fields: [
        fake_field(:vendor, :belongs_to),
        fake_field(:missing_vendor, :belongs_to)
      ]
    )

    assert_equal %i[vendor], resource.fields.keys
    assert_equal :missing_vendor, resource.stale_fields.fetch(0).fetch(:name)
  end

  def test_keeps_supported_has_many_fields
    resource = build_resource(
      fields: [
        fake_field(:certificates, :has_many)
      ]
    )

    assert_equal %i[certificates], resource.fields.keys
    assert_empty resource.stale_fields
  end

  def test_setup_sync_creates_missing_inferred_fields_without_recreating_existing_fields
    fields = CapturingFieldDefinitions.new([fake_field(:name, :string)])
    definition = FakeDefinition.new(
      key: "company_locations",
      record_class_name: "AirviewResourceBuilderTest::CompanyLocation",
      label: "Company locations",
      label_method: nil,
      field_definitions: fields
    )

    CompanyLocation.test_columns = [
      FakeColumn.new("id", :integer, "integer", false, nil),
      FakeColumn.new("name", :string, "varchar", true, nil),
      FakeColumn.new("new_column", :boolean, "boolean", true, nil)
    ]

    begin
      added_count = Airview::ResourceSynchronizer.new(definition).sync_missing_fields
      created_names = fields.created.map { |attributes| attributes.fetch(:name) }
      created_positions = fields.created.map { |attributes| attributes.fetch(:position) }

      assert_equal 2, added_count
      assert_equal %w[id new_column], created_names
      assert_equal [1, 2], created_positions
    ensure
      CompanyLocation.test_columns = nil
    end
  end

  private

  def build_resource(fields:)
    Airview::ResourceBuilder.build(
      FakeDefinition.new(
        key: "company_locations",
        record_class_name: "AirviewResourceBuilderTest::CompanyLocation",
        label: "Company locations",
        label_method: nil,
        field_definitions: FakeFieldDefinitions.new(fields)
      )
    )
  end

  def fake_field(name, type)
    FakeField.new(
      name: name.to_s,
      field_type: type.to_s,
      label: name.to_s.humanize,
      read_only: false,
      default_visible: true,
      position: 0
    )
  end
end
