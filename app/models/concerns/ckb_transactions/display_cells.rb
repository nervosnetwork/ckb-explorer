# frozen_string_literal: true

module CkbTransactions
  module DisplayCells
    extend ActiveSupport::Concern

    included do
      def display_inputs(previews: false)
        if is_cellbase
          cellbase_display_inputs
        else
          cell_inputs_for_display = cell_inputs.order(id: :asc)
          cell_inputs_for_display = cell_inputs_for_display.limit(10) if previews
          normal_tx_display_inputs(cell_inputs_for_display)
        end
      end

      def display_outputs(previews: false)
        if is_cellbase
          cellbase_display_outputs
        else
          cell_outputs_for_display = outputs.order(id: :asc)
          cell_outputs_for_display = cell_outputs_for_display.limit(10) if previews
          normal_tx_display_outputs(cell_outputs_for_display)
        end
      end

      def cellbase_display_inputs
        cellbase = Cellbase.new(block)
        [
          CkbUtils.hash_value_to_s(
            id: nil,
            from_cellbase: true,
            capacity: nil,
            occupied_capacity: nil,
            address_hash: nil,
            target_block_number: cellbase.target_block_number,
            generated_tx_hash: tx_hash,
          ),
        ]
      end

      def cellbase_display_outputs
        cell_outputs_for_display = outputs.order(id: :asc)
        cellbase = Cellbase.new(block)
        cell_outputs_for_display.map do |output|
          consumed_tx_hash = output.live? ? nil : output.consumed_by.tx_hash
          CkbUtils.hash_value_to_s(
            id: output.id,
            capacity: output.capacity,
            occupied_capacity: output.occupied_capacity,
            address_hash: output.address_hash,
            target_block_number: cellbase.target_block_number,
            base_reward: cellbase.base_reward,
            commit_reward: cellbase.commit_reward,
            proposal_reward: cellbase.proposal_reward,
            secondary_reward: cellbase.secondary_reward,
            status: output.status,
            consumed_tx_hash:,
            generated_tx_hash: output.tx_hash,
            cell_index: output.cell_index,
          )
        end
      end

      def normal_tx_display_inputs(cell_inputs_for_display)
        cell_inputs_for_display.map do |cell_input|
          previous_cell_output = cell_input.previous_cell_output
          unless previous_cell_output
            next({
              from_cellbase: false,
              capacity: "",
              occupied_capacity: "",
              address_hash: "",
              generated_tx_hash: cell_input.previous_tx_hash,
              cell_index: cell_input.previous_index,
              since: {
                raw: hex_since(cell_input.since.to_i),
                median_timestamp: cell_input.block&.median_timestamp.to_i,
              },
            })
          end

          display_input = {
            id: previous_cell_output.id,
            from_cellbase: false,
            capacity: previous_cell_output.capacity,
            occupied_capacity: previous_cell_output.occupied_capacity,
            address_hash: previous_cell_output.address_hash,
            generated_tx_hash: previous_cell_output.ckb_transaction.tx_hash,
            cell_index: previous_cell_output.cell_index,
            cell_type: previous_cell_output.cell_type,
            since: {
              raw: hex_since(cell_input.since.to_i),
              median_timestamp: cell_input.block&.median_timestamp.to_i,
            },
            tags: previous_cell_output.tags,
          }

          if previous_cell_output.nervos_dao_withdrawing?
            display_input.merge!(attributes_for_dao_input(previous_cell_output))
          end
          if previous_cell_output.nervos_dao_deposit?
            display_input.merge!(attributes_for_dao_input(cell_outputs[cell_input.index], false))
          end
          if previous_cell_output.udt?
            display_input.merge!(attributes_for_udt_cell(previous_cell_output))
          end
          if previous_cell_output.xudt?
            display_input.merge!(attributes_for_xudt_cell(previous_cell_output))
          end
          if previous_cell_output.xudt_compatible?
            display_input.merge!(attributes_for_xudt_compatible_cell(previous_cell_output))
          end
          if previous_cell_output.cell_type.in?(%w(m_nft_issuer m_nft_class m_nft_token))
            display_input.merge!(attributes_for_m_nft_cell(previous_cell_output))
          end
          if previous_cell_output.cell_type.in?(%w(nrc_721_token nrc_721_factory))
            display_input.merge!(attributes_for_nrc_721_cell(previous_cell_output))
          end
          if previous_cell_output.cell_type.in?(%w(omiga_inscription_info omiga_inscription))
            display_input.merge!(attributes_for_omiga_inscription_cell(previous_cell_output))
          end
          if previous_cell_output.bitcoin_vout
            display_input.merge!(attributes_for_rgb_cell(previous_cell_output))
          end
          if previous_cell_output.cell_type.in?(%w(spore_cluster spore_cell did_cell))
            display_input.merge!(attributes_for_dob_cell(previous_cell_output))
          end

          CkbUtils.hash_value_to_s(display_input)
        end
      end

      def normal_tx_display_outputs(cell_outputs_for_display)
        cell_outputs_for_display.map do |output|
          consumed_tx_hash = output.live? ? nil : output.consumed_by&.tx_hash
          display_output = {
            id: output.id,
            capacity: output.capacity,
            occupied_capacity: output.occupied_capacity,
            address_hash: output.address_hash,
            status: output.status,
            consumed_tx_hash:,
            cell_type: output.cell_type,
            generated_tx_hash: output.tx_hash,
            cell_index: output.cell_index,
            tags: output.tags,
          }

          display_output.merge!(attributes_for_udt_cell(output)) if output.udt?
          display_output.merge!(attributes_for_xudt_cell(output)) if output.xudt?
          display_output.merge!(attributes_for_xudt_compatible_cell(output)) if output.xudt_compatible?
          display_output.merge!(attributes_for_cota_registry_cell(output)) if output.cota_registry?
          display_output.merge!(attributes_for_cota_regular_cell(output)) if output.cota_regular?
          if output.cell_type.in?(%w(m_nft_issuer m_nft_class m_nft_token))
            display_output.merge!(attributes_for_m_nft_cell(output))
          end
          if output.cell_type.in?(%w(nrc_721_token nrc_721_factory))
            display_output.merge!(attributes_for_nrc_721_cell(output))
          end
          if output.cell_type.in?(%w(omiga_inscription_info omiga_inscription))
            display_output.merge!(attributes_for_omiga_inscription_cell(output))
          end
          if output.bitcoin_vout
            display_output.merge!(attributes_for_rgb_cell(output))
          end
          if output.cell_type.in?(%w(spore_cluster spore_cell did_cell))
            display_output.merge!(attributes_for_dob_cell(output))
          end

          CkbUtils.hash_value_to_s(display_output)
        end
      end

      def attributes_for_udt_cell(udt_cell)
        info = CkbUtils.hash_value_to_s(udt_cell.udt_info)
        { udt_info: info, extra_info: info }
      end

      def attributes_for_cota_registry_cell(cota_cell)
        info = cota_cell.cota_registry_info
        { cota_registry_info: info, extra_info: info }
      end

      def attributes_for_cota_regular_cell(cota_cell)
        info = cota_cell.cota_regular_info
        { cota_regular_info: info, extra_info: info }
      end

      def attributes_for_m_nft_cell(m_nft_cell)
        info = m_nft_cell.m_nft_info
        { m_nft_info: info, extra_info: info }
      end

      def attributes_for_nrc_721_cell(nrc_721_cell)
        info = nrc_721_cell.nrc_721_nft_info
        { nrc_721_token_info: info, extra_info: info }
      end

      def attributes_for_omiga_inscription_cell(omiga_inscription_cell)
        info = omiga_inscription_cell.omiga_inscription_info
        { omiga_inscription_info: info, extra_info: info }
      end

      def attributes_for_dao_input(nervos_dao_withdrawing_cell, is_phase2 = true)
        nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.ckb_transaction
        nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.
          cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
        # start block: the block contains the transaction which generated the deposit cell output
        compensation_started_block = Block.select(:number, :timestamp).find(nervos_dao_deposit_cell.block.id)
        # end block: the block contains the transaction which generated the withdrawing cell
        compensation_ended_block = Block.select(:number, :timestamp).
          find(nervos_dao_withdrawing_cell_generated_tx.block_id)
        interest = CkbUtils.dao_interest(nervos_dao_withdrawing_cell)

        attributes = {
          compensation_started_block_number: compensation_started_block.number,
          compensation_started_timestamp: compensation_started_block.timestamp,
          compensation_ended_block_number: compensation_ended_block.number,
          compensation_ended_timestamp: compensation_ended_block.timestamp,
          interest:,
        }

        if is_phase2
          number, timestamp = Block.where(id: block_id).pick(:number, :timestamp) # locked_until_block
          attributes[:locked_until_block_number] = number
          attributes[:locked_until_block_timestamp] = timestamp
        end

        CkbUtils.hash_value_to_s(attributes)
      end

      def attributes_for_rgb_cell(rgb_cell)
        { rgb_info: rgb_cell.rgb_info }
      end

      def attributes_for_xudt_cell(xudt_cell)
        info = CkbUtils.hash_value_to_s(xudt_cell.udt_info)
        { xudt_info: info, extra_info: info }
      end

      def attributes_for_xudt_compatible_cell(xudt_compatible_cell)
        info = CkbUtils.hash_value_to_s(xudt_compatible_cell.udt_info)
        { xudt_compatible_info: info, extra_info: info }
      end

      def attributes_for_dob_cell(dob_cell)
        info = dob_cell.dob_info
        if dob_cell.cell_type.in?(%w(did_cell spore_cell))
          info[:data] = dob_cell.data
        end
        { dob_info: info, extra_info: info }
      end

      def hex_since(int_since_value)
        "0x#{int_since_value.to_s(16).rjust(16, '0')}"
      end
    end
  end
end
