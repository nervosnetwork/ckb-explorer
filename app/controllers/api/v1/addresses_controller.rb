module Api
  module V1
    class AddressesController < ApplicationController
      before_action :validate_query_params

      def show
        if BitcoinUtils.valid_address?(params[:id])
          bitcoin_address = BitcoinAddress.find_by(address_hash: params[:id])
          address = bitcoin_address ? bitcoin_address.ckb_address : NullAddress.new(params[:id])
        else
          address = Address.find_address!(params[:id])
        end

        render json: json_response(address)
      end

      private

      def validate_query_params
        validator = Validations::Address.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status:
        end
      end

      def json_response(address)
        if QueryKeyUtils.valid_hex?(params[:id])
          LockHashSerializer.new(address)
        else
          presented_address = address.is_a?(NullAddress) ? NullAddress.new(params[:id]) : address
          AddressSerializer.new(presented_address)
        end
      end
    end
  end
end
