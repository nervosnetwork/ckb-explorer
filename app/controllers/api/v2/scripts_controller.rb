module Api::V2
  class ScriptsController < ApplicationController
    before_action :set_page_and_page_size
    before_action :find_script

    def ckb_transactions
      head :not_found and return if @script.blank?

      render json: {
        data: {
          id: @script.id,
          code_hash: @script.code_hash,
          hash_type: @script.hash_type,
          ckb_transactions: @script.ckb_transactions.page(@page).per(@page_size)
        },
        meta: {
          total: @script.ckb_transactions.count.to_i,
          page_size: @page_size.to_i
        }
      }
    end

    def deployed_cells
      head :not_found and return if @script.blank?

      render json: {
        data: {
          id: @script.id,
          code_hash: @script.code_hash,
          hash_type: @script.hash_type,
          deployed_cells: @script.cell_outputs.where(status: :live).page(@page).per(@page_size)
        },
        meta: {
          total: @script.cell_outputs.where(status: :live).count.to_i,
          page_size: @page_size.to_i
        }
      }
    end

    def referring_cells
      head :not_found and return if @script.blank?

      my_referring_cells = @script.ckb_transactions.map { |ckb_transaction|
        ckb_transaction.addresses.map { |address|
          address.cell_outputs.where(status: :live)
        }
      }.flatten

      render json: {
        data: {
          id: @script.id,
          code_hash: @script.code_hash,
          hash_type: @script.hash_type,
          my_referring_cells: Kaminari.paginate_array(my_referring_cells).page(@page).per(@page_size)
        },
        meta: {
          total: my_referring_cells.count.to_i,
          page_size: @page_size.to_i
        }
      }
    end

    private
    def set_page_and_page_size
      @page = params[:page] || 1
      @page_size = params[:page_size] || 10
    end

    def find_script
      @script = TypeScript.find_by(code_hash: params[:code_hash], hash_type: params[:hash_type])
      if @script.blank?
        @script = HashScript.find_by(code_hash: params[:code_hash], hash_type: params[:hash_type])
      end
    end
  end
end
