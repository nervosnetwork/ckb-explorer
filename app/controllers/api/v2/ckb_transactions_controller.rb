module Api
  module V2
    class CkbTransactionsController < BaseController
      include CellDataComparator

      before_action :set_page_and_page_size, only: %i[display_inputs display_outputs]

      def details
        ckb_transaction = CkbTransaction.find_by(tx_hash: params[:id])
        head :not_found and return if ckb_transaction.blank?

        expires_in 10.seconds, public: true, must_revalidate: true
        transfers = compare_cells(ckb_transaction)

        render json: { data: transfers }
      end

      def display_inputs
        expires_in 1.hour, public: true, must_revalidate: true

        ckb_transaction = CkbTransaction.find_by(tx_hash: params[:id])
        head :not_found and return if ckb_transaction.blank?

        if ckb_transaction.is_cellbase
          cell_inputs = ckb_transaction.cellbase_display_inputs
          total_count = cell_inputs.count
        else
          cell_inputs = ckb_transaction.cell_inputs.order(id: :asc).
            page(@page).per(@page_size).fast_page
          total_count = cell_inputs.total_count
          cell_inputs = ckb_transaction.normal_tx_display_inputs(cell_inputs)
        end

        render json: {
          data: cell_inputs,
          meta: {
            total: total_count,
            page_size: @page_size.to_i,
          },
        }
      end

      def display_outputs
        expires_in 1.hour, public: true, must_revalidate: true

        ckb_transaction = CkbTransaction.find_by(tx_hash: params[:id])
        head :not_found and return if ckb_transaction.blank?

        if ckb_transaction.is_cellbase
          cell_outputs = ckb_transaction.cellbase_display_outputs
          total_count = cell_outputs.count
        else
          cell_outputs = ckb_transaction.outputs.order(id: :asc).
            page(@page).per(@page_size).fast_page
          total_count = cell_outputs.total_count
          cell_outputs = ckb_transaction.normal_tx_display_outputs(cell_outputs)
        end

        render json: {
          data: cell_outputs,
          meta: {
            total: total_count, page_size: @page_size.to_i
          },
        }
      end

      private

      def set_page_and_page_size
        @page = params.fetch(:page, 1)
        @page_size = params.fetch(:page_size, CkbTransaction.default_per_page)
      end
    end
  end
end
