require "jbuilder"
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

      scope = CellDependency.where(contract_id: @contract.id).order(ckb_transaction_id: :desc)
      tx_ids = scope.page(params[:page]).pluck(:ckb_transaction_id)
      @ckb_transactions = CkbTransaction.find(tx_ids)
      @total = scope.count
    end

    def deployed_cells
      head :not_found and return if @script.blank? || @script.contract.blank?

      @deployed_cells = @contract.deployed_cells.page(@page).per(@page_size).fast_page
    end

    private

    def get_script_content(script)
      column_name = script.instance_of?(TypeScript) ? "type_script_id" : "lock_script_id"
      @my_referring_cells = CellOutput.live.where(column_name => script.id)
      @deployed_cells = @contract&.deployed_cell_outputs&.live
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
      @script = TypeScript.find_by(code_hash: params[:code_hash],
                                   hash_type: params[:hash_type])
      if @script.blank?
        @script = LockScript.find_by(code_hash: params[:code_hash],
                                     hash_type: params[:hash_type])
      end
      @contract = Contract.find_by(code_hash: params[:code_hash],
                                   hash_type: params[:hash_type])
    end
  end
end
