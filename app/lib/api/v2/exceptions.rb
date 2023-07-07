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
          super code: 2001, status: 404, title: "Token Collection Not Found", detail: "No token collection found by given script hash or id", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end
    end
  end
end
