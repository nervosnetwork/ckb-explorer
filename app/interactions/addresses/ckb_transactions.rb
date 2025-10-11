module Addresses
  class CkbTransactions < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    string :sort, default: "time.desc"
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    def execute
      is_bitcoin = BitcoinUtils.valid_address?(key)

      if is_bitcoin
        address = BitcoinAddress.find_by(address_hash: key)
        raise AddressNotFoundError unless address
        address = [address]

        account_books = BtcAccountBook.
          where(bitcoin_address_id: address[0].id).
          order(account_books_ordering).
          page(page).per(page_size)

        total_count = BtcAccountBook.where(bitcoin_address_id: address[0].id).count
      else
        address = Explore.run!(key:)
        raise AddressNotFoundError if address.is_a?(NullAddress)

        address_id = address.map(&:id).first
        account_books = AccountBook.tx_committed.where(address_id:).
          order(account_books_ordering).
          select(:ckb_transaction_id).
          page(page).per(page_size)

        total_count = Address.find(address_id).ckb_transactions_count
      end

      ckb_transaction_ids = account_books.map(&:ckb_transaction_id)

      includes = { :cell_inputs => [:previous_cell_output], :outputs => {}, :bitcoin_annotation => [] }
      includes[:bitcoin_transfers] = {} if is_bitcoin

      records = CkbTransaction.where(id: ckb_transaction_ids)
            .includes(includes)
            .select(select_fields)
            .order(transactions_ordering)
            

      options = paginate_options(records, total_count)
      options.merge!(params: { previews: true, address_id: })

      result = CkbTransactionsSerializer.new(records, options)
      wrap_result(result, address)
    end

    private

    def account_books_ordering
      _, sort_order = sort.split(".", 2)
      sort_order = "asc" unless sort_order&.match?(/^(asc|desc)$/i)

      "ckb_transaction_id #{sort_order}"
    end

    def transactions_ordering
      _, sort_order = sort.split(".", 2)
      sort_order = "asc" unless sort_order&.match?(/^(asc|desc)$/i)

      "ckb_transactions.id #{sort_order}"
    end

    def paginate_options(records, total_count)
      count = [total_count, Settings.query_default_limit].min
      FastJsonapi::PaginationMetaGenerator.new(
        request:, records:, page:, page_size:, total_pages: (count.to_f / page_size).ceil, total_count:,
      ).call
    end

    def select_fields
      %i[ckb_transactions.id ckb_transactions.tx_hash ckb_transactions.tx_index ckb_transactions.block_id ckb_transactions.block_number ckb_transactions.block_timestamp
      ckb_transactions.is_cellbase ckb_transactions.updated_at ckb_transactions.capacity_involved ckb_transactions.created_at ckb_transactions.tx_status]
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
