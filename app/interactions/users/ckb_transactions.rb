module Users
  class CkbTransactions < ActiveInteraction::Base
    include Api::V2::Exceptions

    object :user
    object :request, class: ActionDispatch::Request
    string :address_hash, default: nil
    string :tx_hash, default: nil
    string :sort, default: "ckb_transaction_id.desc"
    integer :page, default: 1
    integer :page_size, default: CkbTransaction.default_per_page

    def execute
      account_books = sort_account_books(filter_account_books).page(page).per(page_size).fast_page
      transactions = CkbTransaction.where(id: account_books.map(&:ckb_transaction_id)).
        select(:id, :tx_hash, :block_id, :block_number, :block_timestamp,
               :is_cellbase, :updated_at, :capacity_involved).
        order(id: :desc)

      options = FastJsonapi::PaginationMetaGenerator.new(
        records: transactions,
        request:,
        page:,
        page_size:,
      ).call
      options[:params] = { previews: true, address_id: user.addresses.map(&:id) }

      transactions_serializer = CkbTransactionsSerializer.new(transactions, options)
      transactions_serializer.serialized_json
    end

    private

    def filter_account_books
      address_ids = user.address_ids
      if address_hash.present?
        address = Address.find_address!(address_hash)
        address_ids = [address.id]
      end

      scope = AccountBook.joins(:ckb_transaction).where(
        account_books: { address_id: address_ids },
        ckb_transactions: { tx_status: "committed" },
      )
      scope = scope.where(ckb_transactions: { tx_hash: }) if tx_hash.present?

      scope
    rescue StandardError
      raise AddressNotFoundError.new
    end

    def sort_account_books(records)
      sorting, ordering = sort.split(".", 2)
      sorting = "ckb_transactions.id" if sorting == "time"

      if ordering.nil? || !ordering.match?(/^(asc|desc)$/i)
        ordering = "asc"
      end

      records.order("#{sorting} #{ordering}")
    end
  end
end
