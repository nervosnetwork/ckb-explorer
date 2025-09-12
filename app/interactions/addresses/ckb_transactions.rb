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
      account_books = AccountBook.tx_committed.where(address_id:).
        order(account_books_ordering).
        select(:ckb_transaction_id, :block_number, :tx_index).
        distinct.page(page).per(page_size)

      records = CkbTransaction.where(id: account_books.map(&:ckb_transaction_id))
            .includes(:cell_inputs, :outputs, :bitcoin_annotation => [])
            # .select(select_fields + ["COUNT(cell_inputs.id) AS cell_inputs_count", "COUNT(cell_outputs.id) AS cell_outputs_count"])
            .select(select_fields)
            # .joins("LEFT JOIN cell_inputs ON cell_inputs.ckb_transaction_id = ckb_transactions.id")
            # .joins("LEFT JOIN cell_outputs ON cell_outputs.ckb_transaction_id = ckb_transactions.id")
            # .group(select_fields.join(','))
            .order(transactions_ordering)

      options = paginate_options(records, address_id)
      options.merge!(params: { previews: true, address_id: })

      result = CkbTransactionsSerializer.new(records, options)
      wrap_result(result, address)
    end

    private

    def account_books_ordering
      _, sort_order = sort.split(".", 2)
      sort_order = "asc" unless sort_order&.match?(/^(asc|desc)$/i)

      "block_number #{sort_order}, tx_index desc"
    end

    def transactions_ordering
      sort_by = "ckb_transactions.block_number"
      _, sort_order = sort.split(".", 2)
      sort_order = "asc" unless sort_order&.match?(/^(asc|desc)$/i)

      "#{sort_by} #{sort_order}, ckb_transactions.tx_index desc"
    end

    def paginate_options(records, address_id)
      total_count = Address.where(id: address_id).sum(:ckb_transactions_count)
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
