require "jbuilder"

module Api
  module V2
    class ScriptsController < BaseController
      before_action :set_page_and_page_size
      before_action :set_contracts, excepts: [:index]

      def index
        scope = Contract.live_verified
        if params[:script_type].present?
          if params[:script_type].include?("lock")
            scope = scope.where(is_lock_script: true)
          end
          if params[:script_type].include?("type")
            scope = scope.where(is_type_script: true)
          end
        end
        if params[:notes].present?
          scope = combine_note_conditions(scope, params[:notes])
        end

        @contracts = sort_scripts(scope).page(@page).per(@page_size)
      end

      def general_info
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        render json: { data: get_script_content }
      end

      def ckb_transactions
        head :not_found and return if @contracts.blank?

        @ckb_transactions =
          if @contracts.length == 1 && @contracts.first.type_hash == Contract::ZERO_LOCK_HASH
            address_ids = LockScript.zero_lock.select(:address_id)
            tx_ids = AccountBook.where(address_id: address_ids).
              order("block_number DESC, tx_index DESC").
              select(:ckb_transaction_id).
              limit(Settings.query_default_limit)
            CkbTransaction.where(id: tx_ids).
              order("block_number DESC, tx_index DESC").
              page(@page).per(@page_size)
          else
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
                select("ckb_transactions.*").
                order("cell_dependencies.block_number DESC, cell_dependencies.tx_index DESC").
                limit(Settings.query_default_limit)
            CkbTransaction.from(base_query, :ckb_transactions).
              order("block_number DESC, tx_index DESC").
              page(@page).
              per(@page_size)
          end
      end

      def deployed_cells
        head :not_found and return if @contracts.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds

        @deployed_cells =
          if @contracts.length == 1 && @contracts.first.type_hash == Contract::ZERO_LOCK_HASH
            { data: { deployed_cells: [], meta: { total: 0, page_size: @page_size.to_i } } }.to_json
          else
            CellOutput.where(id: @contracts.map(&:deployed_cell_output_id)).page(@page).per(@page_size)
          end
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

      def combine_note_conditions(scope, notes_param)
        note_conditions = []

        if notes_param.include?("ownerless_cell")
          note_conditions << scope.where(is_zero_lock: true)
        end

        if notes_param.include?("deprecated")
          note_conditions << scope.where(deprecated: true)
        end

        if notes_param.include?("rfc")
          note_conditions << scope.where.not(rfc: nil)
        end

        if notes_param.include?("website")
          note_conditions << scope.where.not(website: nil)
        end

        if notes_param.include?("open_source")
          note_conditions << scope.where.not(source_url: nil)
        end

        if note_conditions.any?
          note_conditions.reduce { |acc, cond| acc.or(cond) }
        else
          scope
        end
      end

      def get_script_content
        @contracts.map do |contract|
          {
            name: contract.name,
            type_hash: contract.type_hash,
            data_hash: contract.data_hash,
            hash_type: contract.hash_type,
            is_lock_script: contract.is_lock_script,
            is_type_script: contract.is_type_script,
            rfc: contract.rfc,
            website: contract.website,
            description: contract.description,
            deprecated: contract.deprecated,
            verified: contract.verified,
            source_url: contract.source_url,
            capacity_of_deployed_cells: contract.deployed_cell_output.capacity.to_s,
            capacity_of_referring_cells: contract.total_referring_cells_capacity.to_s,
            count_of_transactions: contract.ckb_transactions_count,
            count_of_referring_cells: contract.referring_cells_count,
            script_out_point: "#{contract.contract_cell&.tx_hash}-#{contract.contract_cell&.cell_index}",
            dep_type: contract.dep_type,
            is_zero_lock: contract.is_zero_lock,
            is_deployed_cell_dead: contract.deployed_cell_output&.status == "dead",
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
            Contract.includes(:deployed_cell_output, :contract_cell).where(data_hash: params[:code_hash])
          when "type"
            Contract.includes(:deployed_cell_output, :contract_cell).where(type_hash: params[:code_hash])
          end
      end

      def sort_scripts(records)
        sort, order = params.fetch(:sort, "deployed_block_timestamp.asc").split(".", 2)
        sort =
          case sort
          when "capacity" then "total_referring_cells_capacity"
          when "timestamp" then "deployed_block_timestamp"
          else
            sort
          end

        order = "asc" unless order&.match?(/^(asc|desc)$/i)
        records.order("#{sort} #{order}")
      end
    end
  end
end
