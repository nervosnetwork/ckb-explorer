require "test_helper"

module Api
  module V1
    class ScriptsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @code_hash = '0x00000000000000000000000000000000000000000000000000545950455f4944'
        @hash_type = 'type'
        @type_script = create(:type_script, code_hash: @code_hash, hash_type: @hash_type )
      end
      test "should get success code when call details" do
        valid_get details_api_v1_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_response :success
      end
      test "should set right content type when call show" do
        valid_get details_api_v1_scripts_url(code_hash: @code_hash, hash_type: @hash_type)
        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get details_api_v1_scripts_url(code_hash: @code_hash, hash_type: @hash_type), headers: { "Content-Type": "text/plain" }
        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get details_api_v1_scripts_url(code_hash: @code_hash, hash_type: @hash_type), headers: { "Content-Type": "text/plain" }
        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        address = create(:address, :with_lock_script)

        get details_api_v1_scripts_url(code_hash: @code_hash, hash_type: @hash_type), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

    end
  end
end
