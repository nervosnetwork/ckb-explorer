namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_ckb_transactions_count_to_dao_contract"
  task fill_ckb_transactions_count_to_dao_contract: :environment do
    dao_transactions_count = CkbTransaction.where("tags @> array[?]::varchar[]", ["dao"]).count
    DaoContract.default_contract.update(ckb_transactions_count: dao_transactions_count)

    puts "done"
  end
end
