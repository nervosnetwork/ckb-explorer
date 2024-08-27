require "jbuilder"

module Api
  module V2
    class ScriptsController < BaseController
      before_action :set_page_and_page_size, except: :referring_capacities
      before_action :find_script, except: :referring_capacities

      def general_info
        head :not_found and return if @script.blank? || @contract.blank?

        expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        render json: { data: get_script_content }
      end

      def ckb_transactions
        head :not_found and return if @contract.blank?

        # expires_in 15.seconds, public: true, must_revalidate: true, stale_while_revalidate: 5.seconds
        @ckb_transactions =
          if @contract.ckb_transactions_count.zero?
            CkbTransaction.none
          else
            @contract.ckb_transactions.order(block_number: :desc).page(@page).per(@page_size).fast_page
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

        if @contract.referring_cells_count.zero?
          @referring_cells = CellOutput.none
        else
          scope = @contract.referring_cell_outputs.live.where.not(block_id: nil)
          if params[:args].present?
            type_script = TypeScript.find_by(args: params[:args])
            scope = scope.where(cell_outputs: { type_script_id: type_script.id })
          end
          if params[:address_hash].present?
            address = Addresses::Explore.run!(key: params[:address_hash])
            scope = if address.is_a?(NullAddress)
                      CellOutput.none
                    else
                      scope.where(cell_outputs: { address_id: address.map(&:id) })
                    end
          end

          @referring_cells = sort_referring_cells(scope).page(@page).per(@page_size)
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
          count_of_referring_cells: @contract.referring_cells_count,
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
