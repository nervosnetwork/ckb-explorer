namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fix_missing_script"
  task fix_missing_script: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")

    puts "===============lock_script"
    output_ids = CellOutput.left_outer_joins(:lock_script).where(lock_script: { id: nil }).select(:lock_script_id).distinct
    output_ids.each do |output|
      p output.lock_script_id
      co = CellOutput.where(lock_script_id: output.lock_script_id).first
      if co
        rpc_tx = CkbSync::Api.instance.get_transaction(co.tx_hash)
        lock = rpc_tx.transaction.outputs[co.cell_index].lock
        local_lock = LockScript.find_by(script_hash: lock.compute_hash)
        if local_lock
          if output.lock_script_id < local_lock.id
            ApplicationRecord.transaction do
              CellOutput.where(lock_script_id: local_lock.id).in_batches(of: 10000) do |batch|
                batch.update_all(lock_script_id: output.lock_script_id)
              end
              local_lock.update(id: output.lock_script_id)
            end
          else
            CellOutput.where(lock_script_id: output.lock_script_id).in_batches(of: 10000) do |batch|
              batch.update_all(lock_script_id: local_lock.id)
            end
          end
        else
          LockScript.create(id: output.lock_script_id, code_hash: lock.code_hash, hash_type: lock.hash_type, args: lock.args, script_hash: lock.compute_hash)
        end
      end
    end; nil

    puts "=============type script"
    output_ids = CellOutput.left_outer_joins(:type_script).where.not(type_script_id: nil).where(type_script: { id: nil }).select(:type_script_id).distinct
    output_ids.each do |output|
      p output.type_script_id
      co = CellOutput.where(type_script_id: output.type_script_id).first
      if co
        rpc_tx = CkbSync::Api.instance.get_transaction(co.tx_hash)
        type = rpc_tx.transaction.outputs[co.cell_index].type
        local_type = TypeScript.find_by(script_hash: type.compute_hash)
        if local_type
          if output.type_script_id < local_type.id
            ApplicationRecord.transaction do
              CellOutput.where(type_script_id: local_type.id).in_batches(of: 10000) do |batch|
                batch.update_all(type_script_id: output.type_script_id)
              end
              local_type.update(id: output.type_script_id)
            end
          else
            CellOutput.where(type_script_id: output.type_script_id).in_batches(of: 10000) do |batch|
              batch.update_all(type_script_id: local_type.id)
            end
          end
        else
          TypeScript.create(id: output.type_script_id, code_hash: type.code_hash, hash_type: type.hash_type, args: type.args, script_hash: type.compute_hash)
        end
      end
    end; nil
    puts "done"
  end
end
