module Api::V2
  class ScriptsController < BaseController
    before_action :set_page_and_page_size
    before_action :find_script

    def general_info
      head :not_found and return if @script.blank?

      render json: {
        data: get_script_content(@script)
      }
    end

    def ckb_transactions
      head :not_found and return if @script.blank?

      render json: {
        data: {
          ckb_transactions: @script.script.ckb_transactions.page(@page).per(@page_size).map do |tx|
            {
              id: tx.id,
              tx_hash: tx.tx_hash,
              block_id: tx.block_id,
              block_number: tx.block_number,
              block_timestamp: tx.block_timestamp,
              transaction_fee: tx.transaction_fee,
              is_cellbase: tx.is_cellbase,
              header_deps: tx.header_deps,
              cell_deps: tx.cell_deps,
              witnesses: tx.witnesses,
              live_cell_changes: tx.live_cell_changes,
              capacity_involved: tx.capacity_involved,
              contained_address_ids: tx.contained_address_ids,
              tags: tx.tags,
              contained_udt_ids: tx.contained_udt_ids,
              dao_address_ids: tx.dao_address_ids,
              udt_address_ids: tx.udt_address_ids,
              bytes: tx.bytes,
              tx_status: tx.tx_status,
              display_inputs: tx.display_inputs,
              display_outputs: tx.display_outputs
            }
          end
        },
        meta: {
          total: @script.script.ckb_transactions.count.to_i,
          page_size: @page_size.to_i
        }
      }
    end

    def deployed_cells
      head :not_found and return if @script.blank?

      contract = @script.contract
      head :not_found and return if @script.contract.blank?

      deployed_cells = contract.deployed_cells.page(@page).per(@page_size)
      render json: {
        data: {
          deployed_cells: deployed_cells.map{|deployed_cell|
            deployed_cell.cell_output
          }
        },
        meta: {
          total: contract.deployed_cells.count.to_i,
          page_size: @page_size.to_i
        }
      }
    end

    def referring_cells
      head :not_found and return if @script.blank?
      cell_dependencies = @script.script.cell_dependencies.page(@page).per(@page_size)
      render json: {
        data: {
          referring_cells: cell_dependencies.map {|cell_dependency|
            cell_dependency.cell_output
          }
        },
        meta: {
          total: @script.script.cell_dependencies.count,
          page_size: @page_size.to_i
        }
      }
    end

    private

    def get_script_content(script)
      column_name = script.instance_of?(TypeScript) ? "type_script_id" : "lock_script_id"
      @my_referring_cells = CellOutput.live.where(column_name => script.id)
      @deployed_cells = @contract&.deployed_cells&.live
      {
        id: script.id,
        code_hash: script.code_hash,
        hash_type: script.hash_type,
        script_type: script.class.to_s,
        capacity_of_deployed_cells: @deployed_cells&.sum(:capacity),
        capacity_of_referring_cells: @my_referring_cells.sum(:capacity),
        count_of_transactions: @contract&.ckb_transactions&.count.to_i,
        count_of_deployed_cells: @deployed_cells&.count.to_i,
        count_of_referring_cells: @my_referring_cells.size.to_i
      }
    end

    def set_page_and_page_size
      @page = params[:page] || 1
      @page_size = params[:page_size] || 10
    end

    def find_script
      @script = TypeScript.find_by(code_hash: params[:code_hash], hash_type: params[:hash_type])
      @script = LockScript.find_by(code_hash: params[:code_hash], hash_type: params[:hash_type]) if @script.blank?
      @contract = @script.script.contract
    end
  end
end
