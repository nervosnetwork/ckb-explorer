require "test_helper"

module Api
  module V1
    class ContractsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        valid_get api_v1_contract_url("dao_contract")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_contract_url("dao_contract"), headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_url("dao_contract"), headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_contract_url("dao_contract"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_contract_url("dao_contract"), headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get success code when call show" do
        valid_get api_v1_contract_url("dao_contract")

        assert_response :success
      end

      test "the returned dao contract when param is dao_contract" do
        valid_get api_v1_contract_url("dao_contract")

        assert_equal "dao_contract", json.dig("data", "type")
      end

      test "should contain right keys in the serialized object when visit show" do
        valid_get api_v1_contract_url("dao_contract")

        response_contract = json["data"]
        assert_equal %w(total_deposit subsidy_granted deposit_transactions_count withdraw_transactions_count
           depositors_count total_depositors_count).sort, response_contract["attributes"].keys.sort
      end

      test "should return corresponding contract with given contract name" do
        valid_get api_v1_contract_url("dao_contract")

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
