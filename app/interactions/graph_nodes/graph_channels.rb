module GraphNodes
  class GraphChannels < ActiveInteraction::Base
    string :node_id, default: nil
    string :sort, default: "position_time.desc"
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
    validate :validate_date!

    def execute
      scope = FiberGraphChannel.with_deleted
      scope = scope.where(node1: node_id).or(scope.where(node2: node_id))
      return FiberGraphChannel.none if scope.empty?

      scope = filter_by_address(scope)
      scope = filter_by_status(scope)
      scope = filter_by_date(scope)
      scope = filter_by_type_hash(scope)

      sort_column, sort_direction = channels_ordering
      scope.order(sort_column => sort_direction).page(page).per(page_size).fast_page
    end

    private

    def filter_by_address(scope)
      return scope unless address_hash

      address = Address.find_address!(address_hash)
      scope.includes(:fiber_account_books).where(fiber_account_books: { address: })
    end

    def filter_by_status(scope)
      case status
      when "closed"
        scope.where.not(closed_transaction_id: nil)
      when "open"
        scope.where(closed_transaction_id: nil)
      else
        scope
      end
    end

    def filter_by_date(scope)
      scope = scope.where(created_timestamp: start_date..) if start_date
      scope = scope.where(created_timestamp: ..end_date) if end_date
      scope
    end

    def filter_by_type_hash(scope)
      return scope unless type_hash

      if type_hash.eql?("0x0")
        scope = scope.where(udt_id: nil)
        scope = scope.where(capacity: min_token_amount..) if min_token_amount
        scope = scope.where(capacity: ..max_token_amount) if max_token_amount
      else
        scope = scope.includes(:udt).where(udt: { type_hash: })
        scope = scope.includes(:funding_cell).where(funding_cell: { udt_amount: min_token_amount.. }) if min_token_amount
        scope = scope.includes(:funding_cell).where(funding_cell: { udt_amount: ..max_token_amount }) if max_token_amount
      end

      scope
    end

    def channels_ordering
      sort_by_param, sort_order = sort.to_s.split(".", 2)
      sort_by = { "position_time" => "created_timestamp" }.fetch(sort_by_param, "capacity")
      sort_order = sort_order&.downcase
      sort_order = "asc" unless %w[asc desc].include?(sort_order)

      [sort_by, sort_order]
    end

    def validate_date!
      if start_date.present? && end_date.present? && start_date > end_date
        raise "invalid date"
      end
    end
  end
end
