require "jbuilder"

module Api
  module V2
    class ScriptsController < BaseController
      before_action :set_page_and_page_size
      before_action :set_contracts

      def general_info
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        render json: { data: get_script_content }
      end

      def ckb_transactions
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @ckb_transaction_ids = @contracts.joins(cell_deps_point_outputs: :cell_dependency).
          order("cell_dependencies.block_number DESC, cell_dependencies.tx_index ASC").
          pluck("cell_dependencies.ckb_transaction_id").
          page(@page).
          per(@page_size)
        CkbTransaction.where(id: @ckb_transaction_ids).order("block_number DESC, tx_index ASC")
      end

      def deployed_cells
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        CellOutput.live.where(id: @contracts.map(&:deployed_cell_output_id)).page(@page).per(@page_size)
      end

      def referring_cells
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        script_ids = Contract.query_script_ids(@contracts)
        scope = CellOutput.live.by_scripts(script_ids[:lock_script], script_ids[:type_script])
        if params[:args].present?
          type_script = TypeScript.find_by(args: params[:args])
          scope = scope.or(CellOutput.where(type_script_id: type_script.id))
        end
        if params[:address_hash].present?
          address = Addresses::Explore.run!(key: params[:address_hash])
          scope = scope.where(address_id: address.map(&:id))
        end

        @referring_cells = sort_referring_cells(scope).page(@page).per(@page_size)
      end

      private

      def get_script_content
        @contracts.map do |contract|
          {
            type_hash: contract.type_hash,
            data_hash: contract.data_hash,
            is_lock_script: contract.is_lock_script,
            is_type_script: contract.is_type_script,
            # capacity_of_deployed_cells: contract.total_deployed_cells_capacity,
            # capacity_of_referring_cells: contract.total_referring_cells_capacity,
          }
        end
      end

      def set_page_and_page_size
        @page = params[:page] || 1
        @page_size = params[:page_size] || 10
      end

      def set_contracts
        @contracts =
          case params[:hash_type]
          when "data", "data1", "data2"
            Contract.where(data_hash: params[:code_hash])
          when "type"
            Contract.find_by(type_hash: params[:code_hash])
          end
      end

      def sort_referring_cells(records)
        sort, order = params.fetch(:sort, "block_timestamp.desc").split(".", 2)
        sort =
          case sort
          when "created_time" then "block_timestamp"
          else "block_timestamp"
          end
        order = "asc" unless order&.match?(/^(asc|desc)$/i)
        records.order("#{sort} #{order}")
      end
    end
  end
end
