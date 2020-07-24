namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_address_ids_tags_and_udt_ids_to_ckb_transaction"
  task fill_address_ids_tags_and_udt_ids_to_ckb_transaction: :environment do
    progress_bar = ProgressBar.create(total: CkbTransaction.count, format: "%e %B %p%% %c/%C")
    CkbTransaction.order(:id).find_in_batches do |txs|
      values = txs.map do |tx|
        if tx.outputs.udt.present?
          tx.tags << "udt"
          type_hashes = tx.outputs.udt.pluck(:type_hash).uniq
          tx.contained_udt_ids += Udt.where(type_hash: type_hashes).pluck(:id)
        end

        if tx.outputs.where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).present?
          tx.tags << "dao"
        end

        if tx.inputs.udt.present?
          tx.tags << "udt"
          type_hashes = tx.outputs.udt.pluck(:type_hash).uniq
          tx.contained_udt_ids += Udt.where(type_hash: type_hashes).pluck(:id)
        end

        if tx.inputs.nervos_dao_withdrawing.present?
          tx.tags << "dao"
        end
        progress_bar.increment

        { id: tx.id, contained_address_ids: tx.addresses.pluck(:id).uniq, tags: tx.tags.uniq, contained_udt_ids: tx.contained_udt_ids.uniq, created_at: tx.created_at, updated_at: Time.current }
      end

      CkbTransaction.upsert_all(values) if values.present?
    end

    puts "done"
  end
end
