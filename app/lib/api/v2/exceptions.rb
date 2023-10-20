module Api
  module V2
    module Exceptions
      class Error < StandardError
        attr_accessor :code, :status, :title, :detail, :href

        def initialize(code:, status:, title:, detail:, href:)
          @code = code
          @status = status
          @title = title
          @detail = detail
          @href = href
        end
      end

      class TokenCollectionNotFoundError < Error
        def initialize
          super(code: 2001, status: 404, title: "Token Collection Not Found", detail: "No token collection found by given script hash or id", href: "")
        end
      end

      class AddressNotMatchEnvironmentError < Error
        def initialize(ckb_net_mode)
          super(code: 2022, status: 422, title: "Address is invalid", detail: "This address is not the #{ckb_net_mode} address", href: "")
        end
      end

      class InvalidPortfolioMessageError < Error
        def initialize
          super(code: 2003, status: 400, title: "portfolio message is invalid", detail: "", href: "")
        end
      end

      class InvalidPortfolioSignatureError < Error
        def initialize
          super(code: 2004, status: 400, title: "portfolio signature is invalid", detail: "", href: "")
        end
      end
    end
  end
end
