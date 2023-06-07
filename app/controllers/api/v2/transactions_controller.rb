module Api
  module V2
    class TransactionsController < BaseController
      before_action :find_transaction, only: [:raw, :details]
      def raw
        if stale?(etag: @transaction.tx_hash, public: true)
          expires_in 1.day
          render json: @transaction.to_raw
        end
      end

      def details
        capacities = {}
        @transaction.display_inputs.select{ |e| e[:cell_type] == 'normal' }.each {|input|
          capacities[input[:address_hash]] ||= 0
          capacities[input[:address_hash]] -= input[:capacity].to_d
        }

        @transaction.display_outputs.select{ |e| e[:cell_type] == 'normal' }.each {|output|
          capacities[output[:address_hash]] ||= 0
          capacities[output[:address_hash]] += output[:capacity].to_d
        }
        json = capacities.map { |address, value|
          {
            address: address,
            transfers: [
              {
                asset: "CKB",
                capacity: value,
                token_name: "CKB",
                entity_type: "CKB",
                transfer_type: "simple_transfer"
              }
            ]
          }
        }

        render json: {data: json}
      end

      protected

      def find_transaction
        @transaction = CkbTransaction.cached_find(params[:id])
      end
    end
  end
end
