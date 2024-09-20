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

      class ParamsInvalidError < Error
        def initialize(detail)
          super(code: 2000, status: 404, title: "Params are invalid", detail:, href:)
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

      class UserNotExistError < Error
        def initialize(detail)
          super(code: 2005, status: 400, title: "user not exist", detail:, href: "")
        end
      end

      class DecodeJWTFailedError < Error
        def initialize(detail)
          super(code: 2006, status: 400, title: "decode JWT failed", detail:, href: "")
        end
      end

      class PortfolioLatestDiscrepancyError < Error
        def initialize(detail)
          super(code: 2007, status: 400, title: "portfolio has not synchronized the latest addresses", detail:, href: "")
        end
      end

      class SyncPortfolioAddressesError < Error
        def initialize
          super(code: 2008, status: 400, title: "sync portfolio addresses failed", detail: "", href: "")
        end
      end

      class AddressNotFoundError < Error
        def initialize
          super code: 2009, status: 404, title: "address Not Found", detail: "No address found by given address hash or lock hash", href: ""
        end
      end

      class FiberPeerParamsInvalidError < Error
        def initialize(detail)
          super code: 2010, status: 404, title: "fiber peer params invalid", detail: , href: ""
        end
      end

      class FiberPeerNotFoundError < Error
        def initialize
          super code: 2011, status: 404, title: "fiber peer Not Found", detail: "No peer found by given peer id", href: ""
        end
      end

      class FiberChannelNotFoundError < Error
        def initialize
          super code: 2012, status: 404, title: "fiber channel Not Found", detail: "No channel found by given channel_id", href: ""
        end
      end
    end
  end
end
