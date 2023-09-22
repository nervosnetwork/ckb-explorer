class UdtVerificationMailerPreview < ActionMailer::Preview
  def send_token
    UdtVerificationMailer.with(email: "receiver@example.com", token: "123456", locale: params[:locale]).send_token
  end
end
