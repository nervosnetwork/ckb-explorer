class DeployedCell < ApplicationRecord

  belongs_to :contract
  belongs_to :cell_output

  # create initial data for this table
  # before running this method,
  # 1. run Script.create_initial_data
  # 2. stop `ruby lib/ckb_block_node_processor.rb`
  # 3. record the last ckb_transaction_id, eg 8888
  # 4. start  `ruby lib/ckb_block_node_processor.rb`
  # 5. call this method,please pass in (current) the last ckb_transaction_id
  #     e.g. DeployedCell.create_initial_data 8888
  def self.create_initial_data ckb_transaction_id = nil

    if ckb_transaction_id.blank?
      ckb_transaction_id = CkbTransaction.last.id
    end
    CkbTransaction.where("id <= ?", ckb_transaction_id).find_each do |ckb_transaction|
      DeployedCell.transaction do
        self.create_initial_data_for_ckb_transaction ckb_transaction
      end
    end
    Rails.logger.info "== done"
  end

  def self.create_initial_data_for_ckb_transaction ckb_transaction
    begin
      if ckb_transaction.cell_outputs.present?
        ckb_transaction.cell_outputs.each do |cell_output|
          self.create_initial_data_by_cell_output cell_output, ckb_transaction
        end
      end

      if ckb_transaction.cell_inputs.present?
        ckb_transaction.cell_inputs.each do |cell_input|
          cell_output = cell_input.previous_cell_output
          next if cell_output.blank?

          self.create_initial_data_by_cell_output cell_output, ckb_transaction
        end
      end
    rescue Exception => e
      Rails.logger.warn "If you have not finished creating Script table, just ignore this error message, #{e}"
      #Rails.logger.error e
      #Rails.logger.error e.backtrace.join("\n")
    end
  end

  def self.create_initial_data_by_cell_output cell_output, ckb_transaction
    lock_script = cell_output.lock_script
    if lock_script.present?
      self.create_deployed_cells lock_script_or_type_script: lock_script, ckb_transaction: ckb_transaction, contract_id: lock_script.script.contract_id
    end

    type_script = cell_output.type_script
    if type_script.present?
      self.create_deployed_cells lock_script_or_type_script: type_script, ckb_transaction: ckb_transaction, contract_id: type_script.script.contract_id
    end
  end

  def self.create_deployed_cells options
    lock_script_or_type_script = options[:lock_script_or_type_script]
    ckb_transaction = options[:ckb_transaction]
    contract_id = options[:contract_id]

    if lock_script_or_type_script.present? && lock_script_or_type_script.hash_type == 'type'
      ckb_transaction.cell_deps.each do |cell_dep|
        tx_hash = cell_dep['out_point']['tx_hash']
        point_index = cell_dep['out_point']['index']

        temp_ckb_transaction = CkbTransaction.find_by(tx_hash: tx_hash)
        cell_output = temp_ckb_transaction.cell_outputs[point_index]

        if lock_script_or_type_script.code_hash == cell_output.lock_script.code_hash
          DeployedCell.create! cell_output_id: cell_output.id, contract_id: contract_id
        end
      end
    end

    if lock_script_or_type_script.present? && lock_script_or_type_script.hash_type == 'data'
      ckb_transaction.cell_deps.each do |cell_dep|

        tx_hash = cell_dep['out_point']['tx_hash']
        point_index = cell_dep['out_point']['index']

        temp_ckb_transaction = CkbTransaction.find_by(tx_hash: tx_hash)
        cell_output = temp_ckb_transaction.cell_outputs[point_index]

        if lock_script_or_type_script.code_hash == CKB::Blake2b.hexdigest(cell_output.data)
          DeployedCell.create! cell_output_id: cell_output.id, contract_id: contract_id
        end
      end
    end
  end

end


# == Schema Information
#
# Table name: deployed_cells
#
#  id             :bigint           not null, primary key
#  cell_output_id :bigint
#  contract_id    :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
