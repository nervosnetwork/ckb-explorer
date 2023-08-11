module Api
  module V2
    class CkbTransactionsController < BaseController
      # transaction lite info
      def details
        ckb_transaction = CkbTransaction.where(tx_hash: params[:id]).order(tx_status: :desc).first
        head :not_found and return if ckb_transaction.blank?

        expires_in 10.seconds, public: true, must_revalidate: true

        input_capacities = build_cell_capacities(ckb_transaction.display_inputs)
        output_capacities = build_cell_capacities(ckb_transaction.display_outputs)
        transfers = build_transfers(input_capacities, output_capacities)

        render json: { data: transfers }
      end

      private

      def build_cell_capacities(outputs)
        cell_capacities = Hash.new { |hash, key| hash[key] = {} }
        outputs.each do |output|
          parsed_output = JSON.parse(output.to_json, object_class: OpenStruct)
          next if parsed_output.from_cellbase

          unit = token_unit(parsed_output)
          address = parsed_output.address_hash
          udt_info = parsed_output.udt_info

          if (cell_capacity = cell_capacities[[address, unit]]).blank?
            capacity = unit == "CKB" ? parsed_output.capacity.to_f : 0.0
            cell_capacity = {
              capacity: capacity,
              cell_type: parsed_output.cell_type,
              udt_info: {
                symbol: udt_info&.symbol,
                amount: udt_info&.amount.to_f,
                decimal: udt_info&.decimal,
                type_hash: udt_info&.type_hash,
                published: !!udt_info&.published,
                display_name: udt_info&.display_name,
                uan: udt_info&.uan
              }
            }
          elsif unit == "CKB"
            cell_capacity[:capacity] += parsed_output.capacity.to_f
          else
            cell_capacity[:udt_info][:amount] += udt_info.amount.to_f
          end

          cell_capacities[[address, unit]] = cell_capacity
        end

        cell_capacities
      end

      def build_transfers(input_capacities, output_capacities)
        capacities = Hash.new { |hash, key| hash[key] = [] }
        keys = input_capacities.keys | output_capacities.keys
        keys.each do |key|
          address_hash, unit = key
          input = input_capacities[key]
          output = output_capacities[key]

          # There may be keys in both input_capacities and output_capacities that do not exist
          cell_type = output[:cell_type] || input[:cell_type]
          capacity_change = output[:capacity].to_f - input[:capacity].to_f

          transfer = { capacity: capacity_change, cell_type: cell_type }
          if unit != "CKB"
            output_amount = output[:udt_info] ? output[:udt_info][:amount] : 0.0
            input_amount = input[:udt_info] ? input[:udt_info][:amount] : 0.0
            amount_change = output_amount - input_amount
            transfer[:udt_info] = output[:udt_info] || input[:udt_info]
            transfer[:udt_info][:amount] = amount_change
          end

          capacities[address_hash] << CkbUtils.hash_value_to_s(transfer)
        end

        capacities.map do |address, value|
          { address_hash: address, transfers: value }
        end
      end

      def token_unit(cell)
        if (udt_info = cell.udt_info).present?
          udt_info.type_hash
        else
          "CKB"
        end
      end
    end
  end
end
