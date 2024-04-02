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
    end
  end
end
