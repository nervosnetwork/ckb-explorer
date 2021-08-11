class RemoveUselessScripts
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake 'migration:remove_useless_scripts[nil]'"
      task :remove_useless_scripts, [:dry_run,:skip_lock,:skip_type] => :environment do |_, args|
        dry_run = args[:dry_run] == "true" ? true : false
        puts "before lock_script_count: #{LockScript.count}"
        puts "before type_script_count: #{TypeScript.count}"
        remove_lock_scripts(dry_run) if args[:skip_lock].blank?
        remove_type_scripts(dry_run) if args[:skip_type].blank?
        puts "after lock_script_count: #{LockScript.count}"
        puts "after type_script_count: #{TypeScript.count}"
      end
    end
  end

  private

  def remove_lock_scripts(dry_run)
    progress_bar = ProgressBar.create({ total: Address.count, format: "%e %B %p%% %c/%C" })
    Address.select(:id, :address_hash, :created_at).find_each do |addr|
      ApplicationRecord.transaction do
        addresses_attrs = []
        puts "address_id: #{addr.id}"
        first_lock_id = nil
        s = CKB::AddressParser.new(addr.address_hash).parse.script
        LockScript.where(code_hash: s.code_hash, hash_type: s.hash_type, args: s.args).find_in_batches do |locks|
          lock_ids = []
          locks.each do |lock|
            puts "address_id: #{addr.id}, lock_id: #{lock.id}"
            if first_lock_id.nil?
              first_lock_id = lock.id
            else
              lock_ids << lock.id
            end
          end
          if dry_run
            puts "removed lock ids count: #{lock_ids.count}"
          else
            puts "removed lock ids count: #{lock_ids.count}"
            LockScript.where(id: lock_ids).delete_all if lock_ids.present?
          end
        end
        addresses_attrs << { id: addr.id, lock_script_id: first_lock_id, created_at: addr.created_at, updated_at: Time.current } if first_lock_id.present?
        if dry_run
          puts "update address: #{addresses_attrs}"
        else
          puts "update address: #{addresses_attrs}"
          Address.upsert_all(addresses_attrs) if addresses_attrs.present?
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
        puts "begin to remove type script..."
        puts "type_hash: #{type_hash}, cell_output_ids_count: #{cell_output_ids.size}"
        if cell_output_ids.size > 10000
          cell_output_ids.each_slice(1000) do |ids|
            puts "updated cell_output_ids: #{ids}"
            CellOutput.where(id: ids).update_all(type_script_id: type_scripts.first.id)
          end
        else
          CellOutput.where(id: cell_output_ids).update_all(type_script_id: type_scripts.first.id)
        end
        TypeScript.where(id: type_scripts[1..-1].pluck(:id)).delete_all
        puts "removed type script ids count: #{type_scripts[1..-1].count}"
      end
    end

    puts "remove_type_scripts has been completed"
  end
end

RemoveUselessScripts.new