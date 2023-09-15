module Api
  module V1
    class UdtVerificationsController < ApplicationController
      before_action :check_udt_info, only: :update
      before_action :set_locale, only: :update

      def update
        udt_verification = UdtVerification.find_or_create_by(udt_id: @udt.id)

        udt_verification.refresh_token!(request.remote_ip)
        UdtVerificationMailer.with(email: @udt.email, token: udt_verification.token,
                                   locale: @locale).send_token.deliver_later
        render json: :ok
      rescue UdtVerification::TokenSentTooFrequentlyError
        raise Api::V1::Exceptions::TokenSentTooFrequentlyError
      end

      private

      def check_udt_info
        @udt = Udt.find_by(type_hash: params[:id])
        raise Api::V1::Exceptions::UdtNotFoundError if @udt.nil?
        raise Api::V1::Exceptions::UdtNoContactEmailError if @udt.email.blank?
      end

      def set_locale
        @locale = params[:locale] == "zh_CN" ? "zh_CN" : "en"
      end
    end
  end
end
