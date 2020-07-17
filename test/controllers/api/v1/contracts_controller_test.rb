require "test_helper"

module Api
  module V1
    class ContractsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        valid_get api_v1_contract_url(DaoContract::CONTRACT_NAME)

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_contract_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_contract_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_url(DaoContract::CONTRACT_NAME), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get success code when call show" do
        valid_get api_v1_contract_url(DaoContract::CONTRACT_NAME)

        assert_response :success
      end

      test "the returned dao contract when param is dao_contract" do
        DaoContract.default_contract
        valid_get api_v1_contract_url(DaoContract::CONTRACT_NAME)

        assert_equal DaoContract::CONTRACT_NAME, json.dig("data", "type")
      end

      test "should contain right keys in the serialized object when visit show" do
        DaoContract.default_contract
        valid_get api_v1_contract_url(DaoContract::CONTRACT_NAME)

        response_contract = json["data"]
        assert_equal %w(
          average_deposit_time claimed_compensation claimed_compensation_changes deposit_changes deposit_compensation depositor_changes depositors_count estimated_apc mining_reward total_deposit treasury_amount unclaimed_compensation unclaimed_compensation_changes
        ).sort, response_contract["attributes"].keys.sort
      end

      test "should return corresponding contract with given contract name" do
        DaoContract.default_contract
        valid_get api_v1_contract_url(DaoContract::CONTRACT_NAME)

        assert_equal JSON.parse(DaoContractSerializer.new(DaoContract.default_contract).serialized_json), json
      end

      test "should return error object when no records found by id" do
        error_object = Api::V1::Exceptions::ContractNotFoundError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_contract_url("Bitcoin")

        assert_equal response_json, response.body
      end
    end
  end
end
