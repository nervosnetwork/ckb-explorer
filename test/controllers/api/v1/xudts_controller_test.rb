require "test_helper"

module Api
  module V1
    class XudtsControllerTest < ActionDispatch::IntegrationTest
      test "should get success code when call show" do
        udt = create(:udt, :xudt, published: true)

        valid_get api_v1_xudt_url(udt.type_hash)

        assert_response :success
      end

      test "should get success code when call index" do
        create(:udt, :xudt, published: true)

        valid_get api_v1_xudts_url

        assert_response :success
      end

      test "should get success code when call xudt_compatible index " do
        create(:udt, :xudt_compatible, published: true)
        create(:udt, :xudt, published: true)

        valid_get api_v1_xudts_url, params: { type: "xudt_compatible" }

        assert_response :success
        assert_equal 1, json["data"].length
      end

      test "filter union xudt by symbol and tags" do
        udt = create(:udt, :xudt, symbol: "CKBB")
        create(:xudt_tag, udt:, tags: ["duplicate", "layer-1-asset", "supply-limited"])
        udt2 = create(:udt, :xudt, symbol: "RPGG")
        create(:xudt_tag, udt: udt2, tags: ["duplicate", "layer-2-asset", "supply-limited"])
        valid_get api_v1_xudts_url, params: { symbol: "CKBB", tags: "duplicate,supply-limited", union: true }
        assert_response :success
        assert_equal "CKBB", json["data"].first["attributes"]["symbol"]
        assert_equal ["duplicate", "layer-1-asset", "supply-limited"], json["data"].first["attributes"]["xudt_tags"]
      end

      test "filter xudt by symbol and tags" do
        udt = create(:udt, :xudt, symbol: "CKBB")
        create(:xudt_tag, udt:, tags: ["duplicate", "layer-1-asset", "supply-limited"])
        udt2 = create(:udt, :xudt, symbol: "RPGG")
        create(:xudt_tag, udt: udt2, tags: ["duplicate", "layer-2-asset", "supply-limited"])
        valid_get api_v1_xudts_url, params: { symbol: "CKBB", tags: "layer-1-asset,supply-limited,NOT EXIST" }
        assert_response :success
        assert_equal "CKBB", json["data"].first["attributes"]["symbol"]
        assert_equal ["duplicate", "layer-1-asset", "supply-limited"], json["data"].first["attributes"]["xudt_tags"]
      end

      test "list xudt and xudt_tags" do
        udt = create(:udt, :xudt, symbol: "CKBB")
        create(:xudt_tag, udt:, tags: ["duplicate", "layer-1-asset", "supply-limited"])
        udt2 = create(:udt, :xudt, symbol: "RPGG")
        create(:xudt_tag, udt: udt2, tags: ["duplicate", "layer-2-asset", "supply-limited"])
        valid_get api_v1_xudts_url

        assert_equal "RPGG", json["data"].first["attributes"]["symbol"]
        assert_equal ["duplicate", "layer-1-asset", "supply-limited"], json["data"].last["attributes"]["xudt_tags"]
      end
    end
  end
end
