module Api
  module V2
    class BaseController < ActionController::API
      include Pagy::Backend

      rescue_from Api::V2::Exceptions::Error, with: :api_error

      protected

      def address_to_lock_hash(address)
        if address =~ /\A0x/
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
    end
  end
end
