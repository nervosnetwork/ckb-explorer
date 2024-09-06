namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_cell_output_script_id"
  task update_cell_output_script_id: :environment do
    ActiveRecord::Base.connection.execute("SET statement_timeout = 0")
    p "==============lock scripts"
    duplicate_script_hashes = LockScript.
      select(:script_hash).
      group(:script_hash).
      having("COUNT(*) > 1").
      pluck(:script_hash)
    duplicate_script_hashes.each do |hash|
      LockScript.where(script_hash: hash).each do |script|
        unless CellOutput.where(lock_script_id: script.id).exists?
          script.destroy
        end
      end
    end; nil

    duplicate_script_hashes.each_with_index do |lock_script_hash, index|
      p lock_script_hash
      p index
      lock_script_ids = LockScript.where(script_hash: lock_script_hash).order("id asc").pluck(:id)
      base_lock_script_id = lock_script_ids.delete_at(0)
      lock_script_ids.each do |id|
        CellOutput.where(lock_script_id: id).in_batches(of: 10000) do |batch|
          batch.update_all(lock_script_id: base_lock_script_id)
        end
      end
    end; nil

    duplicate_script_hashes = LockScript.
      select(:script_hash).
      group(:script_hash).
      having("COUNT(*) > 1").
      pluck(:script_hash)
    duplicate_script_hashes.each do |hash|
      LockScript.where(script_hash: hash).each do |script|
        unless CellOutput.where(lock_script_id: script.id).exists?
          script.destroy
        end
      end
    end; nil

    p "==============type scripts"
    duplicate_type_script_hashes = TypeScript.
      select(:script_hash).
      group(:script_hash).
      having("COUNT(*) > 1").
      pluck(:script_hash)

    duplicate_type_script_hashes.each do |hash|
      TypeScript.where(script_hash: hash).each do |script|
        unless CellOutput.where(type_script_id: script.id).exists?
          script.destroy
        end
      end
    end; nil

    duplicate_type_script_hashes.each_with_index do |type_script_hash, index|
      p type_script_hash
      p index
      type_script_ids = TypeScript.where(script_hash: type_script_hash).order("id asc").pluck(:id)
      base_type_script_id = type_script_ids.delete_at(0)
      type_script_ids.each do |id|
        CellOutput.where(type_script_id: id).in_batches(of: 10000) do |batch|
          batch.update_all(type_script_id: base_type_script_id)
        end
      end
    end; nil

    duplicate_type_script_hashes = TypeScript.
      select(:script_hash).
      group(:script_hash).
      having("COUNT(*) > 1").
      pluck(:script_hash)

    duplicate_type_script_hashes.each do |hash|
      TypeScript.where(script_hash: hash).each do |script|
        unless CellOutput.where(type_script_id: script.id).exists?
          script.destroy
        end
      end
    end; nil

    puts "done"
  end
end
