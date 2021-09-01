namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_script_id_on_cell_outputs"
  task update_script_id_on_cell_outputs: :environment do
    api = CkbSync::Api.instance
    progress_bar = ProgressBar.create({ total: CellOutput.count, format: "%e %B %p%% %c/%C" })
    CellOutput.find_each do |cell_output|
      puts "cell_output_id: #{cell_output.id}"

      tx_hash = cell_output.ckb_transaction.tx_hash
      output = api.get_transaction(tx_hash).transaction.outputs[cell_output.cell_index]
      lock = LockScript.where(code_hash: output.lock.code_hash, hash_type: output.lock.hash_type, args: output.lock.args).first
      cell_output.lock_script_id = lock.id
      if output.type.present?
        type = TypeScript.where(code_hash: output.type.code_hash, hash_type: output.type.hash_type, args: output.type.args).first
        cell_output.type_script_id = type.id
      end
      cell_output.save!
      progress_bar.increment
    rescue => e
      puts e
      puts "failed cell output id: #{cell_output.id}"
    end
  end
end
