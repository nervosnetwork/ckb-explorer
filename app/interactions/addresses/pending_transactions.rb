module Addresses
  class PendingTransactions < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    string :sort, default: "ckb_transaction_id.desc"
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    def execute
      address = Explore.run!(key:)
      raise AddressNotFoundError if address.is_a?(NullAddress)

      account_books =
        AccountBook.joins(:ckb_transaction).where(
          account_books: { address_id: address.map(&:id) },
          ckb_transactions: { tx_status: "pending" },
        )
      ckb_transaction_ids =
        CellInput.where(ckb_transaction_id: account_books.map(&:ckb_transaction_id)).
          where.not(previous_cell_output_id: nil, from_cell_base: false).
          distinct.pluck(:ckb_transaction_id)
      records =
        CkbTransaction.where(id: ckb_transaction_ids).
          select(select_fields).
          order(transactions_ordering).
          page(page).per(page_size)

      options = FastJsonapi::PaginationMetaGenerator.new(
        request:, records:, page:, page_size:,
      ).call
      options.merge!(params: { previews: true, address: })

      result = CkbTransactionsSerializer.new(records, options)
      wrap_result(result, address)
    end

    private

    def transactions_ordering
      sort_by, sort_order = sort.split(".", 2)
      sort_by =
        case sort_by
        when "time" then "block_timestamp"
        else "id"
        end

      if sort_order.nil? || !sort_order.match?(/^(asc|desc)$/i)
        sort_order = "asc"
      end

      "#{sort_by} #{sort_order} NULLS LAST"
    end

    def select_fields
      %i[id tx_hash block_id block_number block_timestamp
         is_cellbase updated_at capacity_involved created_at]
    end

    # A lock script can correspond to multiple CKB addresses
    def wrap_result(result, address)
      if QueryKeyUtils.valid_address?(key)
        ckb_address = address[0]
        if ckb_address.address_hash == ckb_address.query_address
          result.serialized_json
        else
          result.serialized_json.gsub(ckb_address.address_hash, ckb_address.query_address)
        end
      else
        result.serialized_json
      end
    end
  end
end
