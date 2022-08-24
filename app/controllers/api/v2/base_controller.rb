module Api
  module V2
    class BaseController < ActionController::API
      include Pagy::Backend

      protected
      def address_to_lock_hash(address)
        if address =~ /\A0x/
          address
        else
          parsed = CkbUtils.parse_address(address)
          parsed.script.compute_hash
        end        
      end
    end
  end
end
