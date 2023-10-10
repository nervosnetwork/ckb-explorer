require "test_helper"

module Api
  module V1
    class UdtVerificationsControllerTest < ActionDispatch::IntegrationTest
      test "raise error when udt not exist" do
        valid_put api_v1_udt_verification_url("0x#{SecureRandom.hex(32)}")

        assert_equal 404, response.status
        assert_equal [{ "title" => "UDT Not Found", "detail" => "No UDT records found by given type hash", "code" => 1026, "status" => 404 }],
                     JSON.parse(response.body)
      end

      test "raise error when udt no contact mail" do
        udt = create(:udt, published: true)
        valid_put api_v1_udt_verification_url(udt.type_hash)

        assert_equal 400, response.status
        assert_equal [{ "title" => "UDT has no contact email", "detail" => "", "code" => 1033, "status" => 400 }],
                     JSON.parse(response.body)
      end

      test "raise error when sent too frequently" do
        udt = create(:udt, published: true, email: "example@sudt.com")
        create(:udt_verification, udt: udt, udt_type_hash: udt.type_hash)
        valid_put api_v1_udt_verification_url(udt.type_hash)

        assert_equal 400, response.status
        assert_equal [{ "title" => "Token sent too frequently", "detail" => "", "code" => 1036, "status" => 400 }],
                     JSON.parse(response.body)
      end

      test "should sent successfully" do
        udt = create(:udt, published: true, email: "example@sudt.com")
        valid_put api_v1_udt_verification_url(udt.type_hash)

        assert_equal 200, response.status
        assert_equal "ok", JSON.parse(response.body)
        uv = UdtVerification.first
        assert_not_nil uv.token
        assert_not_nil uv.sent_at
        assert_not_nil uv.last_ip
        assert_equal ActiveJob::Base.queue_adapter.enqueued_jobs[0][:args][0], "UdtVerificationMailer"
      end
    end
  end
end
