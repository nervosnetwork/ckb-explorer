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

      order_by = "ckb_transactions.block_timestamp desc nulls last, ckb_transactions.id desc"
      ckb_transactions = udt.ckb_transactions.tx_committed.select(select_fields).order(order_by)
      ckb_transactions = ckb_transactions.where(tx_hash:) if tx_hash.present?

      if address_hash.present?
        address = Addresses::Explore.run!(key: address_hash)
        raise AddressNotFoundError if address.is_a?(NullAddress)

        ckb_transactions = ckb_transactions.joins(:account_books).
          where(account_books: { address_id: address.map(&:id) }).distinct
      end

      records = ckb_transactions.page(page).per(page_size)
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
      %i[id tx_hash block_id block_number block_timestamp
         is_cellbase updated_at created_at tags]
    end
  end
end
