require "jbuilder"

module Api
  module V2
    class ScriptsController < BaseController
      before_action :set_page_and_page_size
      before_action :find_script

      def general_info
        head :not_found and return if @script.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        render json: { data: get_script_content }
      end

      def ckb_transactions
        head :not_found and return if @script.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        scope = CellDependency.where(contract_id: @contract.id).order(ckb_transaction_id: :desc)
        tx_ids = scope.page(@page).per(@page_size).pluck(:ckb_transaction_id)
        @ckb_transactions = CkbTransaction.find(tx_ids)
        @total = scope.count
      end

      def deployed_cells
        head :not_found and return if @script.blank? || @script.contract.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @deployed_cells = @contract.deployed_cells.page(@page).per(@page_size).fast_page
      end

      def referring_cells
        head :not_found and return if @script.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @referring_cells = @contract.referring_cells.page(@page).per(@page_size).fast_page
      end

      private

      def get_script_content
        referring_cells = @contract&.referring_cell_outputs
        deployed_cells = @contract&.deployed_cell_outputs&.live
        transactions = @contract&.cell_dependencies

        {
          id: @script.id,
          code_hash: @script.code_hash,
          hash_type: @script.hash_type,
          script_type: @script.class.to_s,
          capacity_of_deployed_cells: deployed_cells&.sum(:capacity),
          capacity_of_referring_cells: referring_cells&.sum(:capacity),
          count_of_transactions: transactions&.count.to_i,
          count_of_deployed_cells: deployed_cells&.count.to_i,
          count_of_referring_cells: referring_cells&.count.to_i
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
end
