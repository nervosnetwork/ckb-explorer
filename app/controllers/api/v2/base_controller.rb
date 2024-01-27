module Api
  module V2
    class BaseController < ActionController::API
      include Pagy::Backend

      rescue_from Api::V2::Exceptions::Error, with: :api_error

      def address_to_lock_hash(address)
        if address.start_with?("0x")
          address
        else
          parsed = CkbUtils.parse_address(address)
          parsed.script.compute_hash
        end
      end

      # this method is a monkey patch for fast_page using with pagy.
      def pagy_get_items(collection, pagy)
        collection.offset(pagy.offset).limit(pagy.items).fast_page
      end

      def api_error(error)
        render json: RequestErrorSerializer.new([error], message: error.title), status: error.status
      end

      attr_reader :current_user

      def validate_jwt!
        jwt = request.headers["Authorization"]&.split&.last
        payload = PortfolioUtils.decode_jwt(jwt)

        user = User.find_by(uuid: payload[0]["uuid"])
        raise Api::V2::Exceptions::UserNotExistError.new("validate jwt") unless user

        @current_user = user
      rescue JWT::VerificationError => e
        raise Api::V2::Exceptions::DecodeJWTFailedError.new(e.message)
      rescue JWT::ExpiredSignature => e
        raise Api::V2::Exceptions::DecodeJWTFailedError.new(e.message)
      rescue JWT::DecodeError => e
        raise Api::V2::Exceptions::DecodeJWTFailedError.new(e.message)
      end
    end
  end
end
