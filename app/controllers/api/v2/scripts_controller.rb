require "jbuilder"

module Api
  module V2
    class ScriptsController < BaseController
      before_action :set_page_and_page_size
      before_action :set_contracts, excepts: [:index]

      def index
        scope = Contract.where(verified: true)
        @contracts = sort_scripts(scope).page(@page).per(@page_size)
      end

      def general_info
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        render json: { data: get_script_content }
      end

      def ckb_transactions
        head :not_found and return if @contracts.blank?

        contract_ids = @contracts.map { |contract| contract.id }
        contract_cell_ids = CellDepsOutPoint.list_contract_cell_ids_by_contract(contract_ids)
        restrict_query =
          if params[:restrict] == "true"
            CkbTransaction.joins(:cell_dependencies).
              where(cell_dependencies: { contract_cell_id: contract_cell_ids, is_used: true })
          else
            CkbTransaction.joins(:cell_dependencies).
              where(cell_dependencies: { contract_cell_id: contract_cell_ids })
          end

        base_query =
          restrict_query.
            order("cell_dependencies.block_number DESC, cell_dependencies.tx_index DESC").
            limit(Settings.query_default_limit)
        @ckb_transactions = CkbTransaction.from("(#{base_query.to_sql}) AS ckb_transactions").
          order("block_number DESC, tx_index DESC").
          page(@page).
          per(@page_size)
      end

      def deployed_cells
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        @deployed_cells = CellOutput.where(id: @contracts.map(&:deployed_cell_output_id)).page(@page).per(@page_size)
      end

      def referring_cells
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        scope = Contract.referring_cells_query(@contracts).
          order("block_timestamp DESC, cell_index DESC").
          limit(Settings.query_default_limit)
        if params[:args].present?
          type_script = TypeScript.find_by(args: params[:args])
          scope = scope.or(CellOutput.where(type_script_id: type_script.id))
        end
        if params[:address_hash].present?
          address = Addresses::Explore.run!(key: params[:address_hash])
          scope = scope.where(address_id: address.map(&:id))
        end

        @referring_cells =
          CellOutput.from("(#{scope.to_sql}) AS cell_outputs").
            order("block_timestamp DESC, cell_index DESC").
            page(@page).
            per(@page_size)
      end

      private

      def get_script_content
        sum_hash =
          @contracts.inject({
                              capacity_of_deployed_cells: 0,
                              capacity_of_referring_cells: 0,
                              count_of_transactions: 0,
                              count_of_deployed_cells: 0,
                              count_of_referring_cells: 0,
                            }) do |sum, contract|
            sum[:capacity_of_deployed_cells] += contract.total_deployed_cells_capacity
            sum[:capacity_of_referring_cells] += contract.total_referring_cells_capacity
            sum[:count_of_transactions] += contract.ckb_transactions_count
            sum[:count_of_deployed_cells] += 1
            sum[:count_of_referring_cells] += contract.referring_cells_count
            sum
          end
        {
          id: @contracts.first.type_hash,
          code_hash: params[:code_hash],
          hash_type: params[:hash_type],
          script_type: @contracts.first.is_lock_script ? "LockScript" : "TypeScript",
        }.merge(sum_hash)
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
            Contract.where(type_hash: params[:code_hash])
          end
      end

      def sort_scripts(records)
        sort, order = params.fetch(:sort, "deployed_cell_output_id.asc").split(".", 2)
        sort =
          case sort
          when "transactions" then "h24_ckb_transactions_count"
          else
            sort
          end

        order = "asc" unless order&.match?(/^(asc|desc)$/i)
        records.order("#{sort} #{order}")
      end
    end
  end
end
