# frozen_string_literal: true

require "test_helper"
require "action_controller"
require_relative "../../app/controllers/airview/application_controller"
require_relative "../../app/controllers/airview/resources_controller"

class AirviewResourcesControllerTest < Minitest::Test
  class TestParameters < Hash
    def present?
      any?
    end
  end

  def test_filter_conditions_use_submitted_filters_when_filters_present_marker_exists
    controller = Airview::ResourcesController.new
    controller.params = TestParameters[
      filters_present: "1",
      filters: {
        "0" => {
          "field" => "kind",
          "operator" => "equals",
          "value" => "venue"
        }
      }
    ]
    controller.instance_variable_set(:@resource, resource_with_fields(:kind))
    controller.instance_variable_set(:@active_view, nil)

    assert_equal(
      [{ "field" => "kind", "operator" => "equals", "value" => "venue" }],
      controller.send(:filter_conditions)
    )
  end

  def test_filter_conditions_clear_filters_when_marker_exists_without_filter_rows
    controller = Airview::ResourcesController.new
    controller.params = TestParameters[filters_present: "1"]
    controller.instance_variable_set(:@resource, resource_with_fields(:kind))
    controller.instance_variable_set(:@active_view, nil)

    assert_empty controller.send(:filter_conditions)
  end

  private

  def resource_with_fields(*field_names)
    Airview::Resource.new(:resources, model: "Resource").tap do |resource|
      field_names.each { |field_name| resource.field(field_name, type: :string) }
    end
  end
end
