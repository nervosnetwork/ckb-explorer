# frozen_string_literal: true

module CellOutputs
  module ExtraInfo
    extend ActiveSupport::Concern
    included do
      def udt_info
        return unless cell_type.in?(%w(udt xudt xudt_compatible ssri))

        udt_info = Udt.find_by(type_hash:, published: true)
        CkbUtils.hash_value_to_s(
          symbol: udt_info&.symbol,
          amount: udt_amount,
          decimal: udt_info&.decimal,
          type_hash:,
          published: !!udt_info&.published,
        )
      end

      def m_nft_info
        return unless cell_type.in?(%w(m_nft_issuer m_nft_class m_nft_token))

        case cell_type
        when "m_nft_issuer"
          value = { issuer_name: CkbUtils.parse_issuer_data(data).info["name"] }
        when "m_nft_class"
          parsed_data = CkbUtils.parse_token_class_data(data)
          value = { class_name: parsed_data.name, total: parsed_data.total, type_hash: }
        when "m_nft_token"
          # issuer_id size is 20 bytes, class_id size is 4 bytes
          m_nft_class_type = TypeScript.where(
            code_hash: CkbSync::Api.instance.token_class_script_code_hash,
            args: type_script.args[0..49],
          ).first

          if m_nft_class_type.present?
            m_nft_class_cell = m_nft_class_type.cell_outputs.last
            parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
            value = {
              class_name: parsed_class_data.name,
              token_id: type_script.args[50..-1],
              total: parsed_class_data.total,
              collection: {
                type_hash: m_nft_class_type.script_hash,
              },
            }
          else
            value = { class_name: "", token_id: nil, total: "" }
          end
        else
          raise "invalid cell type"
        end

        CkbUtils.hash_value_to_s(value)
      end

      def dob_info
        return unless cell_type.in?(%w(spore_cluster spore_cell did_cell))

        value =
          case cell_type
          when "spore_cluster"
            tc = TokenCollection.find_by(sn: type_hash)
            { cluster_name: tc&.name, published: !tc.nil?, type_hash: }
          else
            ti = TokenItem.find_by(type_script_id:)
            if ti
              coll = ti.collection

              {
                cluster_name: coll&.name,
                token_id: ti.token_id,
                collection: {
                  type_hash: coll&.sn,
                },
                published: true,
              }
            else
              {}
            end
          end

        CkbUtils.hash_value_to_s(value)
      end

      def nrc_721_nft_info
        return unless cell_type.in?(%w(nrc_721_token nrc_721_factory))

        case cell_type
        when "nrc_721_factory"
          factory_cell_type_script = type_script
          factory_cell = NrcFactoryCell.find_by(
            code_hash: factory_cell_type_script.code_hash,
            hash_type: factory_cell_type_script.hash_type,
            args: factory_cell_type_script.args,
          )
          value = {
            symbol: factory_cell&.symbol,
            amount: udt_amount,
            decimal: "",
            type_hash:,
            published: true,
          }
        when "nrc_721_token"
          udt = Udt.find_by(type_hash:)
          factory_cell = NrcFactoryCell.where(id: udt.nrc_factory_cell_id).first
          udt_account = UdtAccount.where(udt_id: udt.id).first
          value = {
            symbol: factory_cell&.symbol,
            amount: udt_account.nft_token_id,
            decimal: udt_account.decimal,
            type_hash:,
            published: true,
            collection: {
              type_hash: factory_cell&.type_script&.script_hash,
            },
          }
        else
          raise "invalid cell type"
        end

        CkbUtils.hash_value_to_s(value)
      end

      def omiga_inscription_info
        return unless cell_type.in?(%w(omiga_inscription_info omiga_inscription))

        case cell_type
        when "omiga_inscription_info"
          info = OmigaInscriptionInfo.find_by(
            code_hash: type_script.code_hash,
            hash_type: type_script.hash_type,
            args: type_script.args,
          )
          value = {
            symbol: info.symbol,
            name: info.name,
            decimal: info.decimal,
            amount: 0,
          }
        when "omiga_inscription"
          udt = Udt.find_by(type_hash:)
          value = {
            symbol: udt.symbol,
            name: udt.full_name,
            decimal: udt.decimal,
            amount: udt_amount,
            type_hash:,
          }
        else
          raise "invalid cell type"
        end

        CkbUtils.hash_value_to_s(value)
      end

      def cota_registry_info
        return unless cota_registry?

        code_hash = CkbSync::Api.instance.cota_registry_code_hash
        CkbUtils.hash_value_to_s(
          symbol: "", amount: udt_amount, decimal: "", type_hash:,
          published: "true", code_hash:
        )
      end

      def cota_regular_info
        return unless cota_regular?

        code_hash = CkbSync::Api.instance.cota_regular_code_hash
        CkbUtils.hash_value_to_s(
          symbol: "", amount: udt_amount, decimal: "", type_hash:,
          published: "true", code_hash:
        )
      end

      def rgb_info
        return unless bitcoin_vout

        CkbUtils.hash_value_to_s(
          txid: bitcoin_vout.bitcoin_transaction.txid,
          index: bitcoin_vout.index,
          address: bitcoin_vout.bitcoin_address&.address_hash,
          status: bitcoin_vout.status,
          consumed_txid: bitcoin_vout.consumed_by&.txid,
        )
      end

      def tags
        tags = []
        tags << "fiber" if lock_script.code_hash == Settings.fiber_funding_code_hash
        tags << "deployment" if Contract.exists?(deployed_cell_output_id: id)
        tags << "multisig" if
        (lock_script.code_hash == Settings.multisig_code_hash && lock_script.hash_type == "data1") ||
          (lock_script.code_hash == Settings.secp_multisig_cell_type_hash && lock_script.hash_type == "type")
        tags
      end
    end
  end
end
