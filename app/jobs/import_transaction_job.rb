# process a raw transaction and save related records to database
class ImportTransactionJob < ApplicationJob
  queue_as :default
  attr_accessor :tx, :txid, :sdk_tx, :cell_dependencies_attrs,
                :by_type_hash, :by_data_hash,
                :deployed_cells_attrs,
                :addresses,
                :address_changes

  # @param tx_hash [String]
  def perform(tx_hash, extra_data = {})
    self.address_changes = {}
    if tx_hash.is_a?(Hash)
      CkbTransaction.write_raw_hash_cache tx_hash["hash"], tx_hash
      tx_hash = tx_hash["hash"]
    end
    # raw = CkbTransaction.fetch_raw_hash(tx_hash)
    @tx = CkbTransaction.unscoped.create_with(tx_status: :pending).find_or_create_by! tx_hash: tx_hash
    return unless tx.tx_pending?

    Rails.logger.info "Importing #{tx.tx_hash}"
    @sdk_tx = CkbTransaction.fetch_sdk_transaction(tx_hash)
    unless @sdk_tx
      Rails.logger.info "Cannot fetch transaction details for #{tx_hash}"
      return
    end
    @tx.cycles = extra_data[:cycles]
    if extra_data[:timestamp]
      @tx.created_at = Time.at(extra_data[:timestamp].to_d / 1000).utc
    end
    @tx.transaction_fee = extra_data[:fee]
    @tx.bytes = extra_data[:size] || @sdk_tx.serialized_size_in_block
    @tx.version = @sdk_tx.version
    @tx.live_cell_changes = sdk_tx.outputs.count - sdk_tx.inputs.count
    if extra_data[:block_hash]
      block = Block.find_by block_hash: extra_data["block_hash"]
      @tx.included_block_ids << block.id
    end
    @tx.save
    @txid = tx.id
    @deployed_cells_attrs = []
    @cell_dependencies_attrs = []
    @by_type_hash = {}
    @by_data_hash = {}

    capacity_involved = 0

    # process inputs
    sdk_tx.inputs.each_with_index do |input, index|
      if input.previous_output.tx_hash == CellOutput::SYSTEM_TX_HASH
        tx.cell_inputs.create_with(index: index).create_or_find_by(previous_cell_output_id: nil, from_cell_base: true)
      else
        cell = CellOutput.find_by(tx_hash: input.previous_output.tx_hash, cell_index: input.previous_output.index)

        if cell
          process_input tx.cell_inputs.create_with(previous_cell_output_id: cell.id).create_or_find_by!(
            ckb_transaction_id: txid, index: index
          )
          process_deployed_cell(cell.lock_script)
          process_deployed_cell(cell.type_script) if cell.type_script
          capacity_involved += cell.capacity
        else
          tx.cell_inputs.create_or_find_by!(
            previous_tx_hash: input.previous_output.tx_hash,
            previous_index: input.previous_output.index,
            since: input.since
          )
          puts "Missing input #{input.previous_output.to_h} in #{tx_hash}"
          # cannot find corresponding cell output,
          # maybe the transaction contains the cell output has not been processed,
          # so add current transaction to pending list, and wait for future processing

          list = Kredis.unique_list "pending_transactions_for_input:#{input.previous_output.tx_hash}"
          list << tx_hash
        end
      end
    end
    @tx.update_column :capacity_involved, capacity_involved
    # process outputs
    sdk_tx.outputs.each_with_index do |output, index|
      output_data = sdk_tx.outputs_data[index]
      lock = LockScript.process(output.lock)
      t = TypeScript.process(output.type) if output.type
      cell = tx.cell_outputs.find_or_create_by(
        cell_index: index
      )
      cell.lock_script = lock
      cell.type_script = t
      cell.data = output_data
      cell.update!(
        address_id: lock.address_id,
        capacity: output.capacity,
        occupied_capacity: cell.calculate_min_capacity,
        status: "pending"
      )

      if output_data.present? && output_data != "0x"
        (cell.cell_data || cell.build_cell_data).update(data: [output_data[2..]].pack("H*"))
      end
      process_output cell
      process_deployed_cell(cell.lock_script)
      process_deployed_cell(cell.type_script) if cell.type_script
    end

    process_cell_deps
    process_header_deps
    process_witnesses
    save_relationship
    save_changes

    # notify pending transaction to reprocess again
    pending_list = Kredis.unique_list "pending_transactions_for_input:#{tx_hash}"
    pending_list.elements.each do |_tx|
      ImportTransactionJob.perform_later _tx
    end
    pending_list.clear
  end

  def parse_code_dep(cell_dep)
    # this cell output is the contract cell, i.e. one of deployed cells of the contract
    cell_output = CellOutput.find_by_pointer cell_dep["out_point"]["tx_hash"], cell_dep["out_point"]["index"]

    attr = {
      contract_cell_id: cell_output.id,
      dep_type: cell_dep["dep_type"],
      ckb_transaction_id: ckb_transaction.id,
      # check if we already known the relationship between the contract cell and contract
      contract_id: DeployedCell.cell_output_id_to_contract_id(cell_output.id),
      implicit: cell_dep["implicit"] || false
    }

    # we don't know how the cells in transaction may refer to the contract cell
    # so we make index for both `data` and `type` of `hash_type`
    cell_output.data_hash ||= CKB::Blake2b.hexdigest(cell_output.binary_data)

    ## data type refer by the hash value of data field of cell
    by_data_hash[cell_output.data_hash] = attr

    ## `type` type refer by the hash value of type field of cell
    if cell_output.type_script_id
      cell_output.type_hash ||= cell_output.type_script.script_hash
      by_type_hash[cell_output.type_hash] = attr
    end

    cell_output.save if cell_output.changed? # save data_hash type_hash to cell_output
    cell_dependencies_attrs << attr
    cell_output
  end

  def save_relationship
    @deployed_cells_attrs = deployed_cells_attrs.uniq { |a| a[:cell_output_id] }
    if cell_dependencies_attrs.present?
      CellDependency.upsert_all cell_dependencies_attrs.uniq { |a|
                                  a[:contract_cell_id]
                                }, unique_by: [:ckb_transaction_id, :contract_cell_id]
    end
    DeployedCell.upsert_all deployed_cells_attrs, unique_by: [:cell_output_id] if deployed_cells_attrs.present?
    deployed_cells_attrs.each do |deployed_cell_attr|
      DeployedCell.write_cell_output_id_to_contract_id(
        deployed_cell_attr[:cell_output_id],
        deployed_cell_attr[:contract_id]
      )
    end
  end

  def process_deployed_cell(lock_script_or_type_script)
    @processed_script_for_deployed_cell ||= Set.new
    return if @processed_script_for_deployed_cell.include?(lock_script_or_type_script)

    @processed_script_for_deployed_cell << lock_script_or_type_script

    dep =
      case lock_script_or_type_script.hash_type
           when "data"
             by_data_hash[lock_script_or_type_script.code_hash]
           when "type"
             by_type_hash[lock_script_or_type_script.code_hash]
      end
    return unless dep

    unless dep[:contract_id] # we don't know the corresponding contract
      contract = Contract.find_or_initialize_by code_hash: lock_script_or_type_script.code_hash,
                                                hash_type: lock_script_or_type_script.hash_type

      if contract.id.blank? # newly created contract record
        contract.deployed_args = lock_script_or_type_script.args
        contract.role = lock_script_or_type_script.class.name
        contract.save!
      end
      dep[:contract_id] = contract.id

      deployed_cells_attrs << {
        contract_id: contract.id,
        cell_output_id: dep[:contract_cell_id]
      }
    end
  end

  def process_cell_deps
    sdk_tx.cell_deps.each_with_index do |cell_dep, _index|
      process_cell_dep cell_dep
    end
  end

  def process_cell_dep(cell_dep)
    cell_dep = cell_dep.to_h if cell_dep.is_a?(CKB::Types::CellDep)
    case cell_dep["dep_type"]
    when "code"
      parse_code_dep(cell_dep)
    when "dep_group"
      # when the type of cell_dep is "dep_group",
      # it means the cell specified by the `out_point` is a list of out points to the actual referred contract cells
      mid_cell = CellOutput.find_by_pointer cell_dep["out_point"]["tx_hash"], cell_dep["out_point"]["index"]
      cell_dependencies_attrs << {
        contract_cell_id: mid_cell.id,
        dep_type: cell_dep["dep_type"],
        ckb_transaction_id: ckb_transaction.id,
        contract_id: nil,
        implicit: false
      }
      binary_data = mid_cell.binary_data
      # binary_data = [hex_data[2..-1]].pack("H*")
      # parse the actual list of out points from the data field of the cell
      out_points_count = binary_data[0, 4].unpack("L<")

      # iterate over the out point list and append actual referred contract cells to cell dependencies_attrs
      0.upto(out_points_count[0] - 1) do |i|
        tx_hash, cell_index = binary_data[4 + i * 36, 36].unpack("H64L<")
        # contract_cell = CellOutput.find_by_pointer "0x#{tx_hash}", cell_index

        parse_code_dep(
          "out_point" => {
            "tx_hash" => "0x#{tx_hash}",
            "index" => cell_index
          },
          "dep_type" => "code",
          "implicit" => true # this is an implicit dependency
        )
      end
    end
  end

  def process_header_deps
    header_deps_attrs = []
    sdk_tx.header_deps.each_with_index do |header_dep, index|
      header_deps_attrs << {
        ckb_transaction_id: txid,
        index: index,
        header_hash: header_dep
      }
    end
    if header_deps_attrs.present?
      HeaderDependency.upsert_all(header_deps_attrs,
                                  unique_by: %i[ckb_transaction_id index])
    end
  end

  def process_witnesses
    witnesses_attrs = []
    sdk_tx.witnesses.each_with_index do |w, i|
      witnesses_attrs << {
        ckb_transaction_id: txid,
        index: i,
        data: w
      }
    end
    if witnesses_attrs.present?
      Witness.upsert_all(witnesses_attrs, unique_by: %i[ckb_transaction_id index])
    end
  end

  # calculate address and balance change for each cell output
  # @param cell_input [CellInput]
  def process_input(cell_input)
    cell_output = cell_input.previous_cell_output

    address_id = cell_output.address_id
    changes = address_changes[address_id] ||=
      {
        balance: 0,
        balance_occupied: 0
      }
    changes[:balance] -= cell_output.capacity
    changes[:balance_occupied] -= cell_output.occupied_capacity if cell_output.occupied_capacity
  end

  # # calculate address and balance change for each cell output
  # @param cell_output [CellOutput]
  def process_output(cell_output)
    address_id = cell_output.address_id
    changes = address_changes[address_id] ||=
      {
        balance: 0,
        balance_occupied: 0
      }
    changes[:balance] += cell_output.capacity
    changes[:balance_occupied] += cell_output.occupied_capacity
  end

  def save_changes
    if address_changes.present?
      attrs =
        address_changes.map do |address_id, c|
          {
            address_id: address_id,
            ckb_transaction_id: txid,
            changes: c
          }
        end
      TransactionAddressChange.upsert_all(
        attrs,
        unique_by: [:address_id, :ckb_transaction_id],
        on_duplicate: Arel.sql(
          "changes = transaction_address_changes.changes || excluded.changes"
        )
      )
      AccountBook.upsert_all address_changes.keys.map{|address_id| {ckb_transaction_id: tx.id, address_id:}}
    end
  end
end
