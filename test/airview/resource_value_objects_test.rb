# frozen_string_literal: true

require "test_helper"

class AirviewResourceValueObjectsTest < Minitest::Test
  def test_resource_accepts_labeled_fields
    resource = Airview::Resource.new(:users, model: "User")
    field = resource.field(:email, type: :string, label: "Email address")

    assert_equal "Email address", field.label
    assert_equal %i[email], resource.fields.keys
  end

  def test_rejects_unknown_field_types
    resource = Airview::Resource.new(:users, model: "User")

    assert_raises(Airview::ConfigurationError) do
      resource.field(:email, type: :mystery)
    end
  end

  def test_belongs_to_attribute_name_uses_foreign_key
    field = Airview::Field.new(:account, type: :belongs_to)

    assert_equal :account_id, field.attribute_name
  end
end
