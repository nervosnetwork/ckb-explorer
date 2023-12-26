require "jbuilder"

module Api
  module V2
    class ScriptsController < BaseController
      before_action :set_page_and_page_size
      before_action :find_script

      def general_info
        head :not_found and return if @script.blank? || @contract.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        render json: { data: get_script_content }
      end

      def ckb_transactions
        head :not_found and return if @contract.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @ckb_transactions =
          if @contract.ckb_transactions_count.zero?
            CkbTransaction.none
          else
            @contract.ckb_transactions.order(id: :desc).page(@page).per(@page_size)
          end
      end

      def deployed_cells
        head :not_found and return if @contract.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @deployed_cells =
          if @contract.deployed_cells_count.zero?
            CellOutput.none
          else
            @contract.deployed_cell_outputs.live.page(@page).per(@page_size)
          end
      end

      def referring_cells
        head :not_found and return if @contract.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @referring_cells =
          if @contract.referring_cells_count.zero?
            CellOutput.none
          else
            @contract.referring_cell_outputs.live.page(@page).per(@page_size)
          end
      end

      private

      def get_script_content
        deployed_cells = @contract.deployed_cell_outputs
        if deployed_cells.present?
          deployed_type_script = deployed_cells[0].type_script
          if deployed_type_script && deployed_type_script.code_hash == Settings.type_id_code_hash
            type_id = deployed_type_script.script_hash
          end
        end

        {
          id: type_id,
          code_hash: @script.code_hash,
          hash_type: @script.hash_type,
          script_type: @script.class.to_s,
          capacity_of_deployed_cells: @contract.total_deployed_cells_capacity,
          capacity_of_referring_cells: @contract.total_referring_cells_capacity,
          count_of_transactions: @contract.ckb_transactions_count,
          count_of_deployed_cells: @contract.deployed_cells_count,
          count_of_referring_cells: @contract.referring_cells_count
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
