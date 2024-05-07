module Api
  module V2
    class CkbTransactionsController < BaseController
      include CellDataComparator

      before_action :set_ckb_transaction
      before_action :set_pagination_params, only: %i[display_inputs display_outputs]

      def details
        expires_in 10.seconds, public: true, must_revalidate: true
        transfers = compare_cells(@ckb_transaction)

        render json: { data: transfers }
      end

      def display_inputs
        expires_in 15.seconds, public: true, must_revalidate: true

        if @ckb_transaction.is_cellbase
          cell_inputs = @ckb_transaction.cellbase_display_inputs
          total_count = cell_inputs.count
        else
          cell_inputs = @ckb_transaction.cell_inputs.order(id: :asc).
            page(@page).per(@page_size).fast_page
          total_count = cell_inputs.total_count
          cell_inputs = @ckb_transaction.normal_tx_display_inputs(cell_inputs)
        end

        render json: {
          data: cell_inputs,
          meta: { total: total_count, page_size: @page_size },
        }
      end

      def display_outputs
        expires_in 15.seconds, public: true, must_revalidate: true

        if @ckb_transaction.is_cellbase
          cell_outputs = @ckb_transaction.cellbase_display_outputs
          total_count = cell_outputs.count
        else
          cell_outputs = @ckb_transaction.outputs.order(id: :asc).
            page(@page).per(@page_size).fast_page
          total_count = cell_outputs.total_count
          cell_outputs = @ckb_transaction.normal_tx_display_outputs(cell_outputs)
        end

        render json: {
          data: cell_outputs,
          meta: { total: total_count, page_size: @page_size },
        }
      end

      def rgb_digest
        expires_in 10.seconds, public: true, must_revalidate: true

        transfers = [].tap do |res|
          combine_transfers(@ckb_transaction).each do |address_id, transfers|
            vout = BitcoinVout.includes(:bitcoin_address).find_by(address_id:)
            next unless vout

            res << { address: vout&.bitcoin_address&.address_hash, transfers: }
          end
        end

        bitcoin_transaction = BitcoinTransaction.includes(:bitcoin_vouts).find_by(
          bitcoin_vouts: { ckb_transaction_id: @ckb_transaction.id },
        )
        op_return = @ckb_transaction.bitcoin_vouts.find_by(op_return: true)
        if op_return && bitcoin_transaction
          txid = bitcoin_transaction.txid
          commitment = op_return.commitment
          confirmations = bitcoin_transaction.confirmations
        end

        render json: {
          data: { txid:, confirmations:, commitment:, transfers: },
        }
      end

      private

      def set_ckb_transaction
        @ckb_transaction = CkbTransaction.find_by(tx_hash: params[:id])
        return head :not_found unless @ckb_transaction
      end

      def set_pagination_params
        @page = params.fetch(:page, 1)
        @page_size = params.fetch(:page_size, CkbTransaction.default_per_page)
      end
    end
  end
end
