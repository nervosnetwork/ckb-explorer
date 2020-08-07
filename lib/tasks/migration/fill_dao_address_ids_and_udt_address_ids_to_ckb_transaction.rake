namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_dao_address_ids_and_udt_address_ids_to_ckb_transaction"
  task fill_dao_address_ids_and_udt_address_ids_to_ckb_transaction: :environment do
    progress_bar = ProgressBar.create(total: CkbTransaction.where("tags @> array[?]::varchar[]", ["dao"]).count, format: "%e %B %p%% %c/%C")
    CkbTransaction.order(:id).where("tags @> array[?]::varchar[]", ["dao"]).find_in_batches do |txs|
      values = txs.map do |tx|
        if tx.outputs.where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).present?
          tx.dao_address_ids += tx.outputs.where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).pluck(:address_id).uniq
        end

        if tx.inputs.nervos_dao_withdrawing.present?
          tx.dao_address_ids += tx.inputs.nervos_dao_withdrawing.pluck(:address_id).uniq
        end
        progress_bar.increment

        { id: tx.id, dao_address_ids: tx.dao_address_ids.uniq, created_at: tx.created_at, updated_at: Time.current }
      end

      CkbTransaction.upsert_all(values) if values.present?
    end

    puts "dao_address_ids done"

    progress_bar = ProgressBar.create(total: CkbTransaction.where("tags @> array[?]::varchar[]", ["udt"]).count, format: "%e %B %p%% %c/%C")
    CkbTransaction.order(:id).where("tags @> array[?]::varchar[]", ["udt"]).find_in_batches do |txs|
      values = txs.map do |tx|
        if tx.outputs.udt.present?
          tx.udt_address_ids += tx.outputs.udt.pluck(:address_id).uniq
        end

        if tx.inputs.udt.present?
          tx.udt_address_ids += tx.inputs.udt.pluck(:address_id).uniq
        end

        progress_bar.increment

        { id: tx.id, udt_address_ids: tx.udt_address_ids.uniq, created_at: tx.created_at, updated_at: Time.current }
      end

      CkbTransaction.upsert_all(values) if values.present?
    end
    puts "udt_address_ids done"
  end
end
