class UdtVerificationMailer < ApplicationMailer
  default from: "noreply@magickbase.com"

  def send_token
    email = params[:email]
    @token = params[:token]
    locale = params[:locale] || "en"
    I18n.with_locale(locale) do
      mail(to: email, subject: "Token Info Verification")
    end
  end
end
