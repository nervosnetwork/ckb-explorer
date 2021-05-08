class RemoveUselessScripts
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake 'migration:remove_useless_scripts[nil]'"
      task :remove_useless_scripts, [:dry_run] => :environment do |_, args|
        dry_run = args[:dry_run] == "true" ? true : false
        puts "before lock_script_count: #{LockScript.count}"
        puts "before type_script_count: #{TypeScript.count}"
        remove_lock_scripts(dry_run)
        remove_type_scripts(dry_run)
        puts "after lock_script_count: #{LockScript.count}"
        puts "after type_script_count: #{TypeScript.count}"
      end
    end
  end

  private

  def remove_lock_scripts(dry_run)
    progress_bar = ProgressBar.create({ total: Address.count, format: "%e %B %p%% %c/%C" })
    Address.select(:id, :created_at).find_each do |addr|
      ApplicationRecord.transaction do
        puts "address_id: #{addr.id}"
        lock_ids = []
        addresses_attrs = []
        LockScript.where(address_id: addr.id).select(:id, :address_id).find_each do |lock|
          puts "lock_id: #{lock.id}"
          lock_ids.concat(lock.id)
        end
        addresses_attrs << { id: addr.id, lock_script_id: lock_ids.first, created_at: addr.created_at, updated_at: Time.current }
        if dry_run
          puts "update address count: #{addresses_attrs.count}"
          puts "removed lock ids count: #{lock_ids.count}"
        else
          Address.upsert_all(addresses_attrs) if addresses_attrs.present?
          LockScript.where(id: lock_ids[1..-1]).destroy_all if lock_ids.present?
        end
      end
      progress_bar.increment
    end
    puts "remove_lock_scripts has been completed"
  end

  def remove_type_scripts(dry_run)
    cell_output_groups = Hash.new
    CellOutput.where.not(type_script_id: nil).select(:id, :type_hash).find_each do |cell_output|
      puts "cell_output_id: #{cell_output.id}"
      if cell_output_groups[cell_output.type_hash].blank?
        cell_output_groups[cell_output.type_hash] = Set.new([cell_output.id])
      else
        cell_output_groups[cell_output.type_hash] << cell_output.id
      end
    end
    puts "type_script statistics has been completed. size: #{cell_output_groups.size}"

    cell_output_groups.each do |type_hash, cell_output_ids|
      type_scripts = TypeScript.where(script_hash: type_hash).select(:id)
      if dry_run
        puts "removed type script ids count: #{type_scripts[1..-1].count}"
      else
        puts "removed type script ids count: #{type_scripts[1..-1].count}"
        CellOutput.where(id: cell_output_ids).update_all(type_script_id: type_scripts.first.id)
        TypeScript.where(id: type_scripts[1..-1].pluck(:id)).destroy_all
      end
    end

    puts "remove_type_scripts has been completed"
  end
end

RemoveUselessScripts.new