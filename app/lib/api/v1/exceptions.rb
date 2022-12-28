module Api
  module V1
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

      class InvalidContentTypeError < Error
        def initialize
          super code: 1001, status: 415, title: "Unsupported Media Type", detail: "Content Type must be application/vnd.api+json", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class InvalidAcceptError < Error
        def initialize
          super code: 1002, status: 406, title: "Not Acceptable", detail: "Accept must be application/vnd.api+json", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class BlockQueryKeyInvalidError < Error
        def initialize
          super code: 1003, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a block hash or a block height", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class BlockNotFoundError < Error
        def initialize
          super code: 1004, status: 404, title: "Block Not Found", detail: "No block records found by given block hash or number", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CkbTransactionTxHashInvalidError < Error
        def initialize
          super code: 1005, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a transaction hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CkbTransactionNotFoundError < Error
        def initialize
          super code: 1006, status: 404, title: "Transaction Not Found", detail: "No transaction records found by given transaction hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class PageParamError < Error
        def initialize
          super code: 1007, status: 400, title: "Page Param Invalid", detail: "Params page should be a integer", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class PageSizeParamError < Error
        def initialize
          super code: 1008, status: 400, title: "Page Size Param Invalid", detail: "Params page size should be a integer", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class AddressHashInvalidError < Error
        def initialize
          super code: 1009, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a address hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class AddressNotFoundError < Error
        def initialize
          super code: 1010, status: 404, title: "Address Not Found", detail: "No address found by given address hash or lock hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class BlockHashInvalidError < Error
        def initialize
          super code: 1011, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a block hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class BlockTransactionsNotFoundError < Error
        def initialize
          super code: 1012, status: 404, title: "Block Transactions Not Found", detail: "No transaction records found by given address hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CellInputIdInvalidError < Error
        def initialize
          super code: 1013, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a integer", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CellInputNotFoundError < Error
        def initialize
          super code: 1014, status: 404, title: "Cell Input Not Found", detail: "No cell input records found by given id", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CellOutputIdInvalidError < Error
        def initialize
          super code: 1015, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a integer", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CellOutputNotFoundError < Error
        def initialize
          super code: 1016, status: 404, title: "Cell Output Not Found", detail: "No cell output records found by given id", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class SuggestQueryKeyInvalidError < Error
        def initialize
          super code: 1017, status: 422, title: "Query parameter is invalid", detail: "Query parameter should be a block height, block hash, tx hash or address hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class SuggestQueryResultNotFoundError < Error
        def initialize
          super code: 1018, status: 404, title: "No matching records found", detail: "No records found by given query key", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class StatisticInfoNameInvalidError < Error
        def initialize
          super code: 1019, status: 422, title: "URI parameters is invalid", detail: "Given statistic info name is invalid", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class NetInfoNameInvalidError < Error
        def initialize
          super code: 1020, status: 422, title: "URI parameters is invalid", detail: "Given net info name is invalid", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class ContractNotFoundError < Error
        def initialize
          super code: 1021, status: 404, title: "Contract Not Found", detail: "No contract records found by given contract name", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class CellOutputDataSizeExceedsLimitError < Error
        def initialize
          super code: 1022, status: 400, title: "Output Data is Too Large", detail: "You can download output data up to #{CellOutput::MAXIMUM_DOWNLOADABLE_SIZE / 1000} KB", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class AddressNotMatchEnvironmentError < Error
        def initialize(ckb_net_mode)
          super code: 1023, status: 422, title: "URI parameters is invalid", detail: "This address is not the #{ckb_net_mode} address", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class IndicatorNameInvalidError < Error
        def initialize
          super code: 1024, status: 422, title: "URI parameters is invalid", detail: "Given indicator name is invalid", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class TypeHashInvalidError < Error
        def initialize
          super code: 1025, status: 422, title: "URI parameters is invalid", detail: "URI parameters should be a type hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class UdtNotFoundError < Error
        def initialize
          super code: 1026, status: 404, title: "UDT Not Found", detail: "No UDT records found by given type hash", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end

      class ScriptCodeHashParamsInvalidError < Error
        def initialize
          super code: 1027, status: 404, title: "URI parameters invalid", detail: "code hash should be start with 0x", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end
      class ScriptHashTypeParamsInvalidError < Error
        def initialize
          super code: 1028, status: 404, title: "URI parameters invalid", detail: "hash type should be 'type'", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end
      class ScriptNotFoundError < Error
        def initialize
          super code: 1029, status: 404, title: "Script not found", detail: "Script not found", href: "https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html"
        end
      end
    end
  end
end
