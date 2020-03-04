require "test_helper"

module Api
  module V1
    class UdtsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        udt = create(:udt)

        valid_get api_v1_udt_url(udt.type_hash)

        assert_response :success
      end

      test "should set right content type when call show" do
        udt = create(:udt)

        valid_get api_v1_udt_url(udt.type_hash)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        udt = create(:udt)

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        udt = create(:udt)

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        udt = create(:udt)
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_udt_url(udt.type_hash), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end
    end
  end
end
