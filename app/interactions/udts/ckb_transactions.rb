module Udts
  class CkbTransactions < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    with_options default: nil do
      string :type_hash
      string :tx_hash
      string :address_hash
    end
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    validate :validate_type_hash!
    validate :validate_tx_hash!

    def execute
      udt = Udt.find_by(type_hash:, published: true)
      raise UdtNotFoundError if udt.blank?

      order_by = "ckb_transactions.block_timestamp desc nulls last, ckb_transactions.tx_index desc"
      ckb_transactions = udt.ckb_transactions.tx_committed.select(select_fields).order(order_by)
      ckb_transactions = ckb_transactions.where(tx_hash:) if tx_hash.present?

      if address_hash.present?
        address = Addresses::Explore.run!(key: address_hash)
        raise AddressNotFoundError if address.is_a?(NullAddress)

        ckb_transactions = ckb_transactions.joins(:account_books).
          where(account_books: { address_id: address.map(&:id) }).distinct
      end

      includes = { :cell_inputs => {:previous_cell_output => {:type_script => [], :bitcoin_vout => [], :lock_script => [] }, :block => []}, :cell_outputs => {}, :bitcoin_annotation => [], :account_books => {} }

      records = ckb_transactions
                  .includes(includes)
                  .select(select_fields)
                  .page(page).per(page_size)
      options = FastJsonapi::PaginationMetaGenerator.new(
        request:, records:, page:, page_size:,
      ).call
      options.merge!(params: { previews: true })
      CkbTransactionsSerializer.new(records, options).serialized_json
    end

    private

    def validate_type_hash!
      if type_hash.blank? || !QueryKeyUtils.valid_hex?(type_hash)
        raise TypeHashInvalidError.new
      end
    end

    def validate_tx_hash!
      if tx_hash.present? && !QueryKeyUtils.valid_hex?(tx_hash)
        raise CkbTransactionTxHashInvalidError.new
      end
    end

    def select_fields
      %i[ckb_transactions.id ckb_transactions.tx_hash ckb_transactions.tx_index ckb_transactions.block_id ckb_transactions.block_number ckb_transactions.block_timestamp
      ckb_transactions.is_cellbase ckb_transactions.updated_at ckb_transactions.created_at ckb_transactions.tags]
    end
  end
end
