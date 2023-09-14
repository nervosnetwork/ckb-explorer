require "test_helper"

class UdtVerificationMailerTest < ActionMailer::TestCase
  test "send token" do
    email = UdtVerificationMailer.with(email: "receiver@example.com", token: "123456").send_token

    assert_emails 1 do
      email.deliver_now
    end

    # Test the body of the sent email contains what we expect it to
    assert_equal ["noreply@magickbase.com"], email.from
    assert_equal ["receiver@example.com"], email.to
    assert_equal "Token Info Verification", email.subject
    assert_equal "#{read_fixture('send_token_email.en.text.erb').join}\n", email.body.to_s
  end

  test "when zh_CN locale" do
    email = UdtVerificationMailer.with(email: "receiver@example.com", token: "123456", locale: "zh_CN").send_token

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal "#{read_fixture('send_token_email.zh_CN.text.erb').join}\n", email.body.to_s.tr("\r", "")
  end
end
