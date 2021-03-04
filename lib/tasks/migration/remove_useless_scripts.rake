class RemoveUselessScripts
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake 'migration:remove_useless_scripts[nil]'"
      task :remove_useless_scripts, [:dry_run] => :environment do |_, args|
        dry_run = args[:dry_run] == "true" ? true : false
        remove_lock_scripts(dry_run)
        remove_type_scripts(dry_run)
      end
    end
  end

  private

  def remove_lock_scripts(dry_run)
    progress_bar = ProgressBar.create({ total: Address.count, format: "%e %B %p%% %c/%C" })
    Address.select(:id).find_in_batches(batch_size: 10) do |addr_ids|
      ApplicationRecord.transaction do
        removed_lock_ids = []
        addresses_attrs = []
        LockScript.where(address_id: addr_ids).group_by(&:address_id).each do |addr_id, locks|
          progress_bar.increment
          removed_lock_ids.concat(locks[1..-1].pluck(:id))
          addr = Address.find(addr_id)
          addresses_attrs << { id: addr.id, lock_script_id: locks.first.id, created_at: addr.created_at, updated_at: Time.current }
        end
        if dry_run
          puts "update address count: #{addresses_attrs.count}"
          puts "removed lock ids count: #{removed_lock_ids.count}"
        else
          Address.upsert_all(addresses_attrs) if addresses_attrs.present?
          LockScript.where(id: removed_lock_ids).destroy_all
        end
        removed_lock_ids = nil
        addresses_attrs = nil
      end
    end
    puts "remove_lock_scripts has been completed"
  end

  def remove_type_scripts(dry_run)
    ApplicationRecord.transaction do
      CellOutput.where.not(type_script_id: nil).select(:id, :type_hash).group_by(&:type_hash).each do |type_hash, cell_outputs|
        type_scripts = TypeScript.where(script_hash: type_hash).select(:id)
        if dry_run
          puts "removed type script ids count: #{type_scripts[1..-1].count}"
        else
          CellOutput.where(id: cell_outputs.pluck(:id)).update_all(type_script_id: type_scripts.first.id)
          TypeScript.where(id: type_scripts[1..-1].pluck(:id)).destroy_all
        end
      end
    end
    puts "remove_type_scripts has been completed"
  end
end

RemoveUselessScripts.new