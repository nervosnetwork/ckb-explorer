module CkbSync
  class Transactions
    attr_accessor :parsers

    def initialize(raw_txs)
      @parsers =
        raw_txs.map do |raw_tx|
          transaction, extra_data =
            if raw_tx.is_a?(CKB::Types::Transaction)
              [raw_tx, {}]
            else
              [CKB::Types::Transaction.from_h(raw_tx["transaction"].with_indifferent_access), raw_tx.except("transaction")]
            end

          tx_parser = CkbSync::TransactionParser.new(transaction, extra_data)
          tx_parser.parse
          tx_parser
        end
    end

    def import
      @parsers.each_slice(100).to_a.each do |group_parsers|
        tx_attrs = []
        cell_outputs_attrs = []
        cell_data_attrs = []
        cell_inputs_attrs = []
        cell_deps_attrs = []
        witnesses_attrs = []
        header_deps_attrs = []
        lock_script_attrs = Set.new
        addresses_attrs = Set.new
        type_script_attrs = Set.new
        account_books_attrs = Set.new

        group_parsers.each do |parser|
          tx_attrs << parser.tx_attr
          cell_outputs_attrs.concat(parser.cell_outputs_attrs)
          cell_data_attrs.concat(parser.cell_data_attrs)
          witnesses_attrs.concat(parser.witnesses_attrs)
          cell_deps_attrs.concat(parser.cell_deps_attrs)
          header_deps_attrs.concat(parser.header_deps_attrs)
          cell_inputs_attrs.concat(parser.cell_inputs_attrs)
          lock_script_attrs.merge(parser.lock_script_attrs)
          addresses_attrs.merge(parser.addresses_attrs)
          type_script_attrs.merge(parser.type_script_attrs)
          account_books_attrs.merge(parser.account_books_attrs)
        end
        ApplicationRecord.transaction do
          tx_returnings = CkbTransaction.upsert_all(tx_attrs, unique_by: %i[tx_status tx_hash], returning: %i[id tx_hash])
          tx_mappings = tx_returnings.rows.to_h { |id, tx_hash| [tx_hash.sub(/^\\x/, "0x"), id] }
          lock_script_returnings = LockScript.upsert_all(lock_script_attrs.to_a, unique_by: :script_hash, returning: %i[id script_hash])
          lock_script_mappings = lock_script_returnings.rows.to_h { |id, script_hash| [script_hash, id] }
          new_addresses_attrs =
            addresses_attrs.to_a.map do |attr|
              attr.merge({ lock_script_id: lock_script_mappings[attr[:lock_hash]] })
            end
          address_returnings = Address.upsert_all(new_addresses_attrs, unique_by: :lock_hash, returning: %i[id lock_hash])
          address_mappings = address_returnings.rows.to_h { |id, lock_hash| [[lock_hash.sub(/^\\x/, "")].pack("H*"), id] }
          type_script_mappings = {}
          if type_script_attrs.present?
            type_script_returnings = TypeScript.upsert_all(type_script_attrs.to_a, unique_by: :script_hash, returning: %i[id script_hash])
            type_script_mappings = type_script_returnings.rows.to_h { |id, script_hash| [script_hash, id] }
          end
          new_account_books_attrs =
            account_books_attrs.to_a.map do |attr|
              { ckb_transaction_id: tx_mappings[attr[:tx_hash]], address_id: address_mappings[attr[:lock_script_hash]] }
            end
          AccountBook.upsert_all(new_account_books_attrs, unique_by: %i[address_id ckb_transaction_id])
          new_cell_outputs_attrs =
            cell_outputs_attrs.map do |attr|
              attr.merge({ ckb_transaction_id: tx_mappings[attr[:tx_hash]], lock_script_id: lock_script_mappings[attr[:lock_script_hash]],
                           type_script_id: type_script_mappings[attr[:type_hash]], address_id: address_mappings[attr[:lock_script_hash]] }).except(:lock_script_hash)
            end
          cell_outputs_returnings = CellOutput.upsert_all(new_cell_outputs_attrs, unique_by: %i[tx_hash cell_index status], returning: %i[id tx_hash cell_index])
          cell_output_mappings = cell_outputs_returnings.rows.to_h { |id, tx_hash, cell_index| ["#{tx_hash.sub(/^\\x/, '0x')}-#{cell_index}", id] }
          new_cell_data_attrs =
            cell_data_attrs.map do |attr|
              { cell_output_id: cell_output_mappings["#{attr[:tx_hash]}-#{attr[:cell_index]}"], data: attr[:data] }
            end
          CellDatum.upsert_all(new_cell_data_attrs, unique_by: :cell_output_id) if new_cell_data_attrs.present?
          new_witnesses_attrs =
            witnesses_attrs.map do |attr|
              { ckb_transaction_id: tx_mappings[attr[:tx_hash]], data: attr[:data], index: attr[:index] }
            end
          Witness.upsert_all(new_witnesses_attrs, unique_by: %i[ckb_transaction_id index])
          new_header_deps_attrs =
            header_deps_attrs.map do |attr|
              { ckb_transaction_id: tx_mappings[attr[:tx_hash]], header_hash: attr[:header_hash], index: attr[:index] }
            end
          HeaderDependency.upsert_all(new_header_deps_attrs, unique_by: %i[ckb_transaction_id index]) if new_header_deps_attrs.present?
          cell_dep_conditions = cell_deps_attrs.map { |cell_dep| { tx_hash: cell_dep[:out_point_tx_hash], cell_index: cell_dep[:out_point_index] } }
          cell_dep_returnings = batch_query_outputs(cell_dep_conditions, %i[id tx_hash cell_index])
          cell_dep_mappings = cell_dep_returnings.to_h { |id, tx_hash, cell_index| ["#{tx_hash}-#{cell_index}", id] }
          new_cell_deps_attrs =
            cell_deps_attrs.map do |attr|
              { ckb_transaction_id: tx_mappings[attr[:tx_hash]], contract_cell_id: cell_dep_mappings["#{attr[:out_point_tx_hash]}-#{attr[:out_point_index]}"], dep_type: attr[:dep_type] }
            end.filter { |attr| !attr[:contract_cell_id].nil? }
          CellDependency.upsert_all(new_cell_deps_attrs, unique_by: %i[ckb_transaction_id contract_cell_id]) if new_cell_deps_attrs.present?

          input_conditions = cell_inputs_attrs.filter do |input|
                               input[:previous_tx_hash] != CellOutput::SYSTEM_TX_HASH
                             end.map { |input| { tx_hash: input[:previous_tx_hash], cell_index: input[:previous_index] } }
          input_returnings = batch_query_outputs(input_conditions, %i[id cell_type tx_hash cell_index capacity])
          input_mappings = input_returnings.to_h { |id, cell_type, tx_hash, cell_index| ["#{tx_hash}-#{cell_index}", "#{cell_type}-#{id}"] }
          new_cell_inputs_attrs =
            cell_inputs_attrs.map do |attr|
              attr[:ckb_transaction_id] = tx_mappings[attr[:tx_hash]]
              if attr[:previous_tx_hash] != CellOutput::SYSTEM_TX_HASH && input_mappings["#{attr[:previous_tx_hash]}-#{attr[:previous_index]}"].present?
                cell_type, previous_cell_output_id = input_mappings["#{attr[:previous_tx_hash]}-#{attr[:previous_index]}"].split("-")
                attr[:previous_cell_output_id] = previous_cell_output_id
                attr[:cell_type] = cell_type
              end
              attr.except(:tx_hash)
            end
          CellInput.upsert_all(new_cell_inputs_attrs, unique_by: %i[ckb_transaction_id index])
        end
      end
    end

    private

    def batch_query_outputs(conditions, returnings = %i[id cell_type tx_hash cell_index])
      relation = CellOutput.none

      conditions.each do |condition|
        relation = relation.or(CellOutput.where(condition))
      end

      relation.pluck(Arel.sql(returnings.join(", ")))
    end
  end
end
