module GraphNodes
  class Transactions < ActiveInteraction::Base
    string :node_id, default: nil
    string :sort, default: "block_timestamp.desc"
    integer :page, default: 1
    integer :page_size, default: FiberGraphChannel.default_per_page

    string :type_hash, default: nil
    decimal :min_token_amount, default: nil
    decimal :max_token_amount, default: nil

    string :address_hash, default: nil
    string :status, default: nil

    integer :start_date, default: nil
    integer :end_date, default: nil

    validates :status, inclusion: { in: %w[open closed], allow_nil: true }

    def execute
      channels = FiberGraphChannel.with_deleted
      channels = channels.where(node1: node_id).or(channels.where(node2: node_id))
      return Kaminari.paginate_array([]).page(page).per(page_size) if channels.empty?

      channels = filter_by_address(channels)
      channels = filter_by_type_hash(channels)

      wrap_result(channels)
    end

    private

    def filter_by_address(channels)
      return channels unless address_hash

      address = Address.find_address!(address_hash)
      channels.includes(:fiber_account_books).where(fiber_account_books: { address: })
    end

    def filter_by_type_hash(channels)
      return channels unless type_hash

      if type_hash.eql?("0x0")
        channels = channels.where(udt_id: nil)
        channels = channels.where(capacity: min_token_amount..) if min_token_amount
        channels = channels.where(capacity: ..max_token_amount) if max_token_amount
      else
        channels = channels.includes(:udt).where(udt: { type_hash: })
        channels = channels.includes(:funding_cell).where(funding_cell: { udt_amount: min_token_amount.. }) if min_token_amount
        channels = channels.includes(:funding_cell).where(funding_cell: { udt_amount: ..max_token_amount }) if max_token_amount
      end

      channels
    end

    def wrap_result(channels)
      transactions = channels.flat_map do |channel|
        list = []
        list << transaction_data(channel.open_transaction_info, channel, true)
        if channel.closed_transaction
          list << transaction_data(channel.closed_transaction_info, channel, false)
        end
        list
      end

      transactions = sort_transactions(transactions)
      transactions = filter_by_status(transactions)
      transactions = filter_by_block_timestamp(transactions)

      Kaminari.paginate_array(transactions).page(page).per(page_size)
    end

    def transaction_data(tx_info, channel, is_open)
      { is_open: is_open, is_udt: channel.udt.present? }.merge(tx_info)
    end

    def sort_transactions(transactions)
      direction = sort == "block_timestamp.desc" ? -1 : 1
      transactions.sort_by { |tx| tx[:block_timestamp] * direction }
    end

    def filter_by_block_timestamp(transactions)
      return transactions unless start_date || end_date

      transactions.select do |tx|
        ts = tx[:block_timestamp].to_i
        (start_date.nil? || ts >= start_date) && (end_date.nil? || ts <= end_date)
      end
    end

    def filter_by_status(transactions)
      case status
      when "open"
        transactions.select { |t| t[:is_open] }
      when "closed"
        transactions.reject { |t| t[:is_open] }
      else
        transactions
      end
    end
  end
end
