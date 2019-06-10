require "csv"

task export_miner_ranking_list: :environment do
  attributes = %w(address_hash lock_hash total_block_reward)
  CSV.open("#{Rails.root}/tmp/miner_ranking.csv", "wb") do |csv|
    csv << attributes
    MinerRanking.new.ranking(-1).each do |ranking|
      csv << attributes.map { |attr| ranking[attr.to_sym] }
    end
  end
end

