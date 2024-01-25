require "test_helper"

module Api
  module V1
    class CellInputTypeScriptsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        cell_input = create(:cell_input, :with_full_transaction)

        valid_get api_v1_cell_input_type_script_url(cell_input.id)

        assert_response :success
      end

      test "should set right content type when call show" do
        cell_input = create(:cell_input, :with_full_transaction)

        valid_get api_v1_cell_input_type_script_url(cell_input.id)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        cell_input = create(:cell_input, :with_full_transaction)

        get api_v1_cell_input_type_script_url(cell_input.id), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        cell_input = create(:cell_input, :with_full_transaction)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_cell_input_type_script_url(cell_input.id), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        cell_input = create(:cell_input, :with_full_transaction)

        get api_v1_cell_input_type_script_url(cell_input.id), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        cell_input = create(:cell_input, :with_full_transaction)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_cell_input_type_script_url(cell_input.id), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should return error object when id is not a integer" do
        error_object = Api::V1::Exceptions::CellInputIdInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_cell_input_type_script_url("ssdww")

        assert_equal response_json, response.body
      end

      test "should return corresponding type script with given cell input id" do
        cell_input = create(:cell_input, :with_full_transaction)
        type_script = cell_input.type_script

        valid_get api_v1_cell_input_type_script_url(cell_input.id)

        assert_equal TypeScriptSerializer.new(type_script).serialized_json, response.body
      end

      test "should contain right keys in the serialized object when call show" do
        cell_input = create(:cell_input, :with_full_transaction_and_type_script)

        valid_get api_v1_cell_input_type_script_url(cell_input.id)

        assert_equal %w(args code_hash hash_type script_hash).sort, json["data"]["attributes"].keys.sort
      end

      test "should return error object when no cell input found by id" do
        error_object = Api::V1::Exceptions::CellInputNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_cell_input_type_script_url(99)

        assert_equal response_json, response.body
      end

      test "should return error object when cell input from cellbase" do
        cell_input = create(:cell_input, :from_cellbase)

        error_object = Api::V1::Exceptions::CellInputNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_cell_input_type_script_url(cell_input.id)

        assert_equal response_json, response.body
      end

      test "should return null when found record hasn't type script" do
        cell_input = create(:cell_input, :with_full_transaction)
        type_script = cell_input.type_script

        valid_get api_v1_cell_input_type_script_url(cell_input.id)

        assert_equal "{\"data\":null}", response.body
        assert_equal TypeScriptSerializer.new(type_script).serialized_json, response.body
      end
    end
  end
end
