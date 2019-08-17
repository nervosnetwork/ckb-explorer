require "test_helper"

module Api
  module V1
    class NetsControllerTest < ActionDispatch::IntegrationTest
      setup do
        CkbSync::Api.any_instance.stubs(:local_node_info).returns(
          CKB::Types::Peer.new(
            addresses: [
              CKB::Types::AddressInfo.new(address: "/ip4/172.16.55.2/tcp/8115/p2p/QmPcRzhoyTUKnoMpJ4SfrWsQGLo5fLMMXsCJieGbVuYNrc", score: "1"),
              CKB::Types::AddressInfo.new(address: "/ip4/172.16.55.2/tcp/8115/p2p/QmPcRzhoyTUKnoMpJ4SfrWsQGLo5fLMMXsCJieGbVuYNrc", score: "1")
            ],
            is_outbound: nil,
            node_id: "QmPcRzhoyTUKnoMpJ4SfrWsQGLo5fLMMXsCJieGbVuYNra",
            version: "0.16.0 (rylai-v5 2178d78 2019-07-13)"
          )
        )
        NetInfo.any_instance.stubs(:id).returns(1)
      end
      test "should get success code when call index" do
        valid_get api_v1_nets_url

        assert_response :success
      end

      test "should set right content type when call index" do
        valid_get api_v1_nets_url

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should respond with 415 Unsupported Media Type when Content-Type is wrong" do
        get api_v1_nets_url, headers: { "Content-Type": "text/plain" }

        assert_equal 415, response.status
      end

      test "should respond with error object when Content-Type is wrong" do
        error_object = Api::V1::Exceptions::WrongContentTypeError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_nets_url, headers: { "Content-Type": "text/plain" }

        assert_equal response_json, response.body
      end

      test "should respond with 406 Not Acceptable when Accept is wrong" do
        get api_v1_nets_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal 406, response.status
      end

      test "should respond with error object when Accept is wrong" do
        error_object = Api::V1::Exceptions::WrongAcceptError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        get api_v1_nets_url, headers: { "Content-Type": "application/vnd.api+json", "Accept": "application/json" }

        assert_equal response_json, response.body
      end

      test "the returned net info should contain right keys when call index" do
        valid_get api_v1_nets_url

        assert_equal %w(local_node_info), json.dig("data", "attributes").keys.sort
      end

      test "should return right net info" do
        NetInfo.any_instance.stubs(:id).returns(1)
        net_info = NetInfo.new

        valid_get api_v1_nets_url

        assert_equal NetInfoSerializer.new(net_info, { params: { info_name: "local_node_info" } }).serialized_json, response.body
      end

      test "should get success code when call show" do
        valid_get api_v1_net_url("version")

        assert_response :success
      end

      test "should return addresses when param is addresses" do
        net_info = NetInfo.new

        valid_get api_v1_net_url("addresses")

        assert_equal NetInfoSerializer.new(net_info, { params: { info_name: "addresses" } }).serialized_json, response.body
      end

      test "should return is outbound when param is is_outbound" do
        net_info = NetInfo.new

        valid_get api_v1_net_url("is_outbound")

        assert_equal NetInfoSerializer.new(net_info, { params: { info_name: "is_outbound" } }).serialized_json, response.body
      end

      test "should return is node id when param is node_id" do
        net_info = NetInfo.new

        valid_get api_v1_net_url("node_id")

        assert_equal NetInfoSerializer.new(net_info, { params: { info_name: "node_id" } }).serialized_json, response.body
      end

      test "should return is version when param is version" do
        net_info = NetInfo.new

        valid_get api_v1_net_url("version")

        assert_equal NetInfoSerializer.new(net_info, { params: { info_name: "version" } }).serialized_json, response.body
      end

      test "should respond with error object when net info name is invalid" do
        error_object = Api::V1::Exceptions::NetInfoNameInvalidError.new
        response_json = RequestErrorSerializer.new([error_object], message: error_object.title).serialized_json

        valid_get api_v1_net_url("hash_rates")

        assert_equal response_json, response.body
      end
    end
  end
end
