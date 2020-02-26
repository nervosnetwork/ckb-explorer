require "test_helper"

module Api
  module V1
    class DaoDepositorsControllerTest < ActionDispatch::IntegrationTest
      test "should set right content type when call index" do
        valid_get api_v1_dao_depositors_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_dao_depositors_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::InvalidContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_dao_depositors_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_dao_depositors_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::InvalidAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_dao_depositors_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "should get serialized dao depositors" do
        create_list(:address, 10, dao_deposit: 1000)
        addresses = Address.select(:id, :address_hash, :dao_deposit, :average_deposit_time).where("dao_deposit > 0").order(dao_deposit: :desc).limit(100)

        valid_get api_v1_dao_depositors_url

        assert_equal DaoDepositorSerializer.new(addresses).serialized_json, response.body
      end

      test "serialized dao depositors should order by dao deposit" do
        create_list(:address, 3, dao_deposit: 1000)
        addresses = Address.where("dao_deposit > 0").order("dao_deposit desc")

        valid_get api_v1_dao_depositors_url

        assert_equal JSON.parse(DaoDepositorSerializer.new(addresses).serialized_json), json
      end

      test "should contain right keys in the serialized dao depositors" do
        create(:address, dao_deposit: 1000)

        valid_get api_v1_dao_depositors_url

        assert_equal %w(address_hash dao_deposit average_deposit_time).sort, json["data"].first["attributes"].keys.sort
      end

      test "should return up to 100 records" do
        create_list(:address, 103, dao_deposit: 1000)

        valid_get api_v1_dao_depositors_url

        assert_equal 100, json["data"].size
      end

      test "should return empty array when there is no depositors" do
        valid_get api_v1_dao_depositors_url

        assert_equal [], json["data"]
      end
    end
  end
end
