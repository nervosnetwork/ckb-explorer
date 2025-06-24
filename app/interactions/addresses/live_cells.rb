module Addresses
  class LiveCells < ActiveInteraction::Base
    include Api::V1::Exceptions

    object :request, class: ActionDispatch::Request
    string :key, default: nil
    string :bound_status, default: nil
    string :sort, default: "block_timestamp.desc"
    integer :page, default: 1
    integer :page_size, default: CellOutput.default_per_page
    string :tag, default: nil

    def execute
      address = Explore.run!(key:)
      raise AddressNotFoundError if address.is_a?(NullAddress)

      order_by, asc_or_desc = live_cells_ordering
      records = fetch_cell_output_scope(address)
      records = records.order(order_by => asc_or_desc).page(page).per(page_size).fast_page

      options = FastJsonapi::PaginationMetaGenerator.new(request:, records:, page:, page_size:).call
      CellOutputSerializer.new(records, options).serialized_json
    end

    private

    def live_cells_ordering
      sort_by, sort_order = sort.split(".", 2)
      if sort_order.nil? || !sort_order.match?(/^(asc|desc)$/i)
        sort_order = "asc"
      end

      [sort_by, sort_order]
    end

    def fetch_cell_output_scope(address)
      address_ids = address.map(&:id)

      scope =
        if bound_status
          vout_ids = BitcoinVout.where(address_id: address_ids, status: bound_status).pluck(:cell_output_id)
          CellOutput.live.where(id: vout_ids)
        else
          CellOutput.live.where(address_id: address_ids)
        end

      tag.present? ? filter_by_tag(scope) : scope
    end

    def filter_by_tag(scope)
      case tag
      when "fiber"
        lock_script_ids = scope.where.not(lock_script_id: nil).distinct.pluck(:lock_script_id)
        filtered_ids = LockScript.where(id: lock_script_ids, code_hash: Settings.fiber_funding_code_hash).pluck(:id)
        scope.where(lock_script_id: filtered_ids)
      when "multisig"
        lock_script_ids = scope.where.not(lock_script_id: nil).distinct.pluck(:lock_script_id)
        filtered_ids = LockScript.where(id: lock_script_ids).where(
          "(code_hash = ? AND hash_type = ?) OR (code_hash = ? AND hash_type = ?)",
          Settings.multisig_code_hash, "data1",
          Settings.secp_multisig_cell_type_hash, "type"
        ).pluck(:id)
        scope.where(lock_script_id: filtered_ids)
      when "deployment"
        scope_ids = scope.pluck(:id)
        matched_ids = Contract.where(deployed_cell_output_id: scope_ids).pluck(:deployed_cell_output_id)
        scope.where(id: matched_ids)
      else
        CellOutput.none
      end
    end
  end
end
