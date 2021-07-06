namespace :migration do
  task update_m_nft_token_accounts: :environment do
    progress_bar = ProgressBar.create({
      total: DailyStatistic.count,
      format: "%e %B %p%% %c/%C"
    })
    account_ids = []
    UdtAccount.m_nft_token.includes(:address).find_each do |account|
      progress_bar.increment
      unless account.address.cell_outputs.live.m_nft_token.where(type_hash: account.type_hash).exists?
        account_ids << account.id
      end
    end
    UdtAccount.where(id: account_ids).destroy_all
  end
end
