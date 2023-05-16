class DeployedCell < ApplicationRecord
  belongs_to :contract
  belongs_to :cell_output
  # one contract can has multiple deployed cells
  validates :cell_output, uniqueness: true

  # find the corresponding contract defined in the specified cell output via cache
  # @param cell_output_id [Integer] deployed cell output id
  def self.cell_output_id_to_contract_id(cell_output_id)
    Rails.cache.fetch(["cell_output_id_to_contract_id", cell_output_id], expires_in: 1.day) do
      DeployedCell.where(cell_output_id: cell_output_id).pick(:contract_id)
    end
  end

  # save the contract <-> deployed cell mapping to cache
  # @param cell_output_id [Integer] deployed cell output id
  # @param contract_id [Integer] contract id
  def self.write_cell_output_id_to_contract_id(cell_output_id, contract_id)
    Rails.cache.write(["cell_output_id_to_contract_id", cell_output_id], contract_id, expires_in: 1.day)
  end

  # create initial data for this table
  # before running this method,
  # 1. run Script.create_initial_data
  # 2. run this method: DeployedCell.create_initial_data
  def self.create_initial_data(ckb_transaction_id = 0)
    Rails.logger.info "=== ckb_transaction_id: #{ckb_transaction_id.inspect}"
    pool = Concurrent::FixedThreadPool.new(5, max_queue: 1000,
                                              fallback_policy: :caller_runs)
    CkbTransaction.tx_committed.where(is_cellbase: false).where("id >= ?", ckb_transaction_id).find_each do |ckb_transaction|
      Rails.logger.info "=== ckb_transaction: #{ckb_transaction.id}"
      # pool.post do
      Rails.application.executor.wrap do
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.cache do
            if ckb_transaction.cell_dependencies.empty?
              puts ckb_transaction.raw_hash["cell_deps"]
              DeployedCell.create_initial_data_for_ckb_transaction ckb_transaction, ckb_transaction.raw_hash["cell_deps"]
            end
          end
        end
      end
      # end
    end
    pool.shutdown
    pool.wait_for_termination
    Rails.logger.info "== done"
  end

  def self.create_initial_data_for_ckb_transaction(ckb_transaction, cell_deps)
    return if cell_deps.blank?

    deployed_cells = []
    cell_dependencies_attrs = []
    by_type_hash = {}
    by_data_hash = {}

    # intialize cell dependencies records
    # the `cell_deps` field in ckb transactions stores the contract cell (referred by out point,
    # which contains the compiled byte code of contract) the transaction should refer.
    # the submitter of the transaction is responsible for including all the contract cells
    # specified by all the `type_script` and `lock_script` of the cell inputs and cell outputs

    parse_code_dep =
      ->(cell_dep) do
        # this cell output is the contract cell, i.e. one of deployed cells of the contract
        cell_output = CellOutput.find_by_pointer cell_dep["out_point"]["tx_hash"], cell_dep["out_point"]["index"]

        attr = {
          contract_cell_id: cell_output.id,
          dep_type: cell_dep["dep_type"],
          ckb_transaction_id: ckb_transaction.id,
          contract_id: DeployedCell.cell_output_id_to_contract_id(cell_output.id), # check if we already known the relationship between the contract cell and contract
          implicit: cell_dep["implicit"] || false
        }

        # we don't know how the cells in transaction may refer to the contract cell
        # so we make index for both `data` and `type` of `hash_type`
        cell_output.data_hash ||= CKB::Blake2b.hexdigest(cell_output.binary_data)

        by_data_hash[cell_output.data_hash] = attr # data type refer by the hash value of data field of cell
        # `type` type refer by the hash value of type field of cell
        if cell_output.type_script_id
          cell_output.type_hash ||= cell_output.type_script.script_hash
          by_type_hash[cell_output.type_hash] = attr
        end
        cell_output.save if cell_output.changed? # save data_hash type_hash to cell_output
        cell_dependencies_attrs << attr
        cell_output
      end

    cell_deps.each do |cell_dep|
      if cell_dep.is_a?(CKB::Types::CellDep)
        cell_dep = cell_dep.to_h.with_indifferent_access
      end
      case cell_dep["dep_type"]
      when "code"
        parse_code_dep[cell_dep]
      when "dep_group"
        # when the type of cell_dep is "dep_group", it means the cell specified by the `out_point` is a list of out points to the actual referred contract cells
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
        out_points = []
        # iterate over the out point list and append actual referred contract cells to cell dependencies_attrs
        0.upto(out_points_count[0] - 1) do |i|
          tx_hash, cell_index = binary_data[4 + i * 36, 36].unpack("H64L<")
          # contract_cell = CellOutput.find_by_pointer "0x#{tx_hash}", cell_index

          co = parse_code_dep[{
            "out_point" => {
              "tx_hash" => "0x#{tx_hash}",
              "index" => cell_index
            },
            "dep_type" => "code",
            "implicit" => true # this is an implicit dependency
          }]
        end
      end
    end

    cells = ckb_transaction.cell_outputs.includes(:lock_script, :type_script).to_a +
      ckb_transaction.cell_inputs.includes(:previous_cell_output).map(&:previous_cell_output)
    scripts = cells.compact.inject([]) { |a, cell| a + [cell.lock_script, cell.type_script] }.compact.uniq
    deployed_cells_attrs = []

    scripts.each do |lock_script_or_type_script|
      dep =
        case lock_script_or_type_script.hash_type
             when "data"
               by_data_hash[lock_script_or_type_script.code_hash]
             when "type"
               by_type_hash[lock_script_or_type_script.code_hash]
        end
      next unless dep

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

    deployed_cells_attrs = deployed_cells_attrs.uniq { |a| a[:cell_output_id] }

    if cell_dependencies_attrs.present?
      CellDependency.upsert_all cell_dependencies_attrs.uniq { |a|
                                  a[:contract_cell_id]
                                }, unique_by: [:ckb_transaction_id, :contract_cell_id]
    end
    DeployedCell.upsert_all deployed_cells_attrs, unique_by: [:cell_output_id] if deployed_cells_attrs.present?
    deployed_cells_attrs.each do |deployed_cell_attr|
      DeployedCell.write_cell_output_id_to_contract_id(deployed_cell_attr[:cell_output_id],
                                                       deployed_cell_attr[:contract_id])
    end
  end
end

# == Schema Information
#
# Table name: deployed_cells
#
#  id             :bigint           not null, primary key
#  cell_output_id :bigint           not null
#  contract_id    :bigint           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_deployed_cells_on_cell_output_id                  (cell_output_id) UNIQUE
#  index_deployed_cells_on_contract_id_and_cell_output_id  (contract_id,cell_output_id) UNIQUE
#
