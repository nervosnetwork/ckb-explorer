module Addresses
  class CkbTransactions < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    string :sort, default: "time.desc"
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    def execute
      address = Explore.run!(key:)
      raise AddressNotFoundError if address.is_a?(NullAddress)

      address_id = address.map(&:id)

      order_by, asc_or_desc = account_books_ordering
      records = CkbTransaction.tx_committed.joins(:account_books).where(
        account_books: { address_id: },
      ).order(order_by => asc_or_desc).distinct.page(page).per(page_size)

      options = paginate_options(records, address_id)
      options.merge!(params: { previews: true, address: })

      result = CkbTransactionsSerializer.new(records, options)
      wrap_result(result, address)
    end

    private

    def account_books_ordering
      sort_by = "ckb_transactions.block_timestamp"
      _, sort_order = sort.split(".", 2)

      sort_order = "asc" unless sort_order&.match?(/^(asc|desc)$/i)

      [sort_by, sort_order]
    end

    def paginate_options(records, address_id)
      total_count = AccountBook.where(address_id:).distinct.count(:ckb_transaction_id)
      FastJsonapi::PaginationMetaGenerator.new(
        request:, records:, page:, page_size:, total_count:,
      ).call
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
