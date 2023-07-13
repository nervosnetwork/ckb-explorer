module Api
  module V2
    class CkbTransactionsController < ApplicationController
      before_action :find_transaction, only: :details
      before_action :set_page_and_page_size, only: :details

      def details
        capacities = {}
        @ckb_transaction.display_inputs.select{ |e| e[:cell_type] == 'normal' }.each {|input|
          capacities[input[:address_hash]] ||= 0
          capacities[input[:address_hash]] -= input[:capacity].to_d
        }

        @ckb_transaction.display_outputs.select{ |e| e[:cell_type] == 'normal' }.each {|output|
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
                transfer_type: "ordinary_transfer"
              }
            ]
          }
        }

        render json: {data: json}
      end

      private
      def find_transaction
        @ckb_transaction = CkbTransaction.find_by(tx_hash: params[:id])
      end

      def set_page_and_page_size
        @page = params[:page] || 1
        @page_size = params[:page_size] || 10
      end

      def get_transaction_content address_ids, cell_outputs
        transaction_data = []
        transfers = []
        address_ids.each do |address_id|
          cell_outputs.where(address_id: address_id.address_id).each do |cell_output|
            entity_type = "CKB"
            transfer_type = "ordinary_transfer"
            if cell_output.nervos_dao_deposit?
              transfer_type = "nervos_dao_deposit"
            elsif cell_output.nervos_dao_withdrawing?
              transfer_type = "nervos_dao_withdrawing"
              interest_data = get_nervos_dao_withdrawing_data(cell_output)
              transfer.merge(interest_data)
            elsif cell_output.cell_type.in?(%w(nrc_721_token nrc_721_factory))
              entity_type = "nft"
              transfer_type = "nft_transfer"
            elsif cell_output.cell_type.in?(%w(m_nft_issuer m_nft_class m_nft_token))
              transfer_type = "nft_mint"
              entity_type = "nft"
              nft_token =  "NFT"   # token 缩写
              nft_id =  "001"       # NFT ID
            end
            transfer = {
              asset: "unknown #62bc",
              capacity: cell_output.capacity.to_s,
              entity_type: entity_type,
              transfer_type: transfer_type,
            }
            transfers.push(transfer)
          end
          address = Address.find address_id.address_id
          data = {
            address: address.address_hash,
            transfers: transfers
          }
          transaction_data.push(data)
        end
        return transaction_data
      end

      def get_nervos_dao_withdrawing_data
        nervos_dao_deposit_cell = @transaction.cell_inputs.order(:id)[cell_output.cell_index].previous_cell_output
        compensation_started_block = Block.find(nervos_dao_deposit_cell.block.id)
        compensation_ended_block = Block.select(:number, :timestamp).find(@transaction.block_id)
        interest = CkbUtils.dao_interest(cell_output)
        interest_data = {
          compensation_started_block_number: compensation_started_block.number.to_s,
          compensation_ended_block_number: compensation_ended_block.number.to_s,
          compensation_started_timestamp: compensation_started_block.timestamp.to_s,
          compensation_ended_timestamp: compensation_ended_block.timestamp.to_s,
          interest: interest,
          locked_until_block_timestamp: @transaction.block.timestamp,
          locked_until_block_number: @transaction.block.number,
        }
        return interest_data
      end
    end
  end
end
