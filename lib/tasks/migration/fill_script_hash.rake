class FillScriptHash
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_script_hash"
      task fill_script_hash: :environment do
        fill_script_hash_to_lock_scripts
        fill_script_hash_to_type_scripts
      end
    end
  end

  private

  def fill_script_hash_to_lock_scripts
    progress_bar = ProgressBar.create({ total: LockScript.where(script_hash: nil).count, format: "%e %B %p%% %c/%C" })
    LockScript.where(script_hash: nil).select(:id, :args, :code_hash, :hash_type, :created_at).find_in_batches do |locks|
      lock_attributes = []
      locks.each do |lock_script|
        progress_bar.increment
        lock_attributes << { id: lock_script.id, script_hash: CKB::Types::Script.new(**lock_script.to_node_lock).compute_hash, created_at: lock_script.created_at, updated_at: Time.current }
      end

      LockScript.upsert_all(lock_attributes) if lock_attributes.present?
    end

    puts "lock script hash has been filled"
  end

  def fill_script_hash_to_type_scripts
    progress_bar = ProgressBar.create({ total: TypeScript.where(script_hash: nil).count, format: "%e %B %p%% %c/%C" })
    TypeScript.where(script_hash: nil).select(:id, :args, :code_hash, :hash_type, :created_at).find_in_batches do |types|
      type_attributes = []
      types.each do |type_script|
        progress_bar.increment
        type_attributes << { id: type_script.id, script_hash: CKB::Types::Script.new(**type_script.to_node_type).compute_hash, created_at: type_script.created_at, updated_at: Time.current }
      end

      TypeScript.upsert_all(type_attributes) if type_attributes.present?
    end

    puts "type script hash has been filled"
  end
end

FillScriptHash.new
