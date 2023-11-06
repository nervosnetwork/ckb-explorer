require "test_helper"

module Api
  module V1
    class UdtQueriesControllerTest < ActionDispatch::IntegrationTest
      test "should return empty array" do
        valid_get api_v1_udt_queries_url, params: { q: "CKB" }

        response_json = { data: [] }.to_json

        assert_response :success
        assert_equal "application/vnd.api+json", response.media_type
        assert_equal response_json, response.body
      end

      test "should query by symbol" do
        udt = create(:udt, full_name: "Nervos Token", symbol: "CKB")

        valid_get api_v1_udt_queries_url, params: { q: "CKB" }

        response_json = UdtSerializer.new([udt],
                                          {
                                            fields: {
                                              udt: [
                                                :full_name, :symbol, :type_hash,
                                                :icon_file
                                              ] } }).serialized_json

        assert_response :success
        assert_equal response_json, response.body
      end

      test "should query by name" do
        udt = create(:udt, full_name: "Nervos Token", symbol: "CKB")

        valid_get api_v1_udt_queries_url, params: { q: "nervos" }

        response_json = UdtSerializer.new([udt],
                                          {
                                            fields: {
                                              udt: [
                                                :full_name, :symbol, :type_hash,
                                                :icon_file
                                              ] } }).serialized_json

        assert_response :success
        assert_equal response_json, response.body
      end

      test "should query by symbol and name" do
        udt1 = create(:udt, full_name: "Nervos Token", symbol: "CKB")
        udt2 = create(:udt, full_name: "Nervos CKB", symbol: "NCKB")

        valid_get api_v1_udt_queries_url, params: { q: "CKB" }

        response_json = UdtSerializer.new([udt1, udt2],
                                          {
                                            fields: {
                                              udt: [
                                                :full_name, :symbol, :type_hash,
                                                :icon_file
                                              ] } }).serialized_json

        assert_response :success
        assert_equal response_json, response.body
      end
    end
  end
end
