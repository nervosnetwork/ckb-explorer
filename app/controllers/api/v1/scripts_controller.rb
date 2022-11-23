module Api
  module V1
    class ScriptsController < ApplicationController
      before_action :validate_query_params

      def details
        script = TypeScript.find_by(code_hash: params[:code_hash], hash_type: params[:hash_type])
        ckb_transactions = script.ckb_transactions
        deployed_cells = script.cell_outputs.where(status: :live)
        referring_cells = ckb_transactions.map { |ckb_transaction|
          ckb_transaction.addresses.map { |address|
            address.cell_outputs.where(status: :live)
          }
        }.flatten

        render json: ScriptSerializer.new(script, params: {
          ckb_transactions: ckb_transactions,
          deployed_cells: deployed_cells,
          referring_cells: referring_cells
        })
      rescue ActiveRecord::RecordNotFound
        raise Api::V1::Exceptions::ScriptNotFoundError
      end

      private

      def validate_query_params
        puts "== params: #{params.inspect}"
        validator = Validations::Script.new(params)

        if validator.invalid?
          errors = validator.error_object[:errors]
          status = validator.error_object[:status]

          render json: errors, status: status
        end
      end
    end
  end
end
