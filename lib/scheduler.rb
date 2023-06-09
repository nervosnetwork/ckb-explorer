root = __dir__
root = File.dirname(root) until File.exist?(File.join(root, "config"))
Dir.chdir(root)
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "rubygems"
require "bundler/setup"

ENV["RAILS_ENV"] ||= "development"
require File.join(root, "config", "environment")

require "rufus-scheduler"
s = Rufus::Scheduler.singleton

def s.around_trigger(job)
  t = Time.now
  puts "Starting job #{job.id} at #{Time.now}"
  yield
  puts "job #{job.id} finished in #{Time.now - t} seconds."
end

def call_worker(clz)
  clz = clz.constantize if clz.is_a?(String)

  puts "invoking #{clz.name}"
  clz.new.perform
  puts "fininsh #{clz.name}"
end

# Vacuum database periodically for better performance
s.cron "0 2 * * 1" do
  ApplicationRecord.connection.execute "vacuum (verbose, analyze)"
end

s.cron "5 0 * * *" do
  call_worker Charts::DailyStatistic
end

s.every "10m", overlap: false do
  call_worker Charts::BlockStatistic
end

s.every "30m", overlap: false do
  call_worker Charts::EpochStatistic
end

s.every "1h", overlap: false do
  call_worker DaoContractUnclaimedCompensationGenerator
end

s.cron "0 */6 * * *" do
  call_worker AddressAverageDepositTimeGenerator
end

s.every "1h", overlap: false do
  call_worker AverageBlockTimeGenerator
end

s.every "1h", overlap: false do
  call_worker AddressUnclaimedCompensationGenerator
end

s.every "5m", overlap: false do
  call_worker PoolTransactionCheckWorker
end

s.every "1h", overlap: false do
  call_worker CleanUpWorker
end

s.interval "10s", overlap: false do
  puts "reset transactions_count_per_minute, average_block_time, transaction_fee_rates"
  StatisticInfo.default.reset! :transactions_count_per_minute,
                               :average_block_time,
                               :transaction_fee_rates
end

s.interval "30s", overlap: false do
  puts "reset pending_transaction_fee_rates"
  StatisticInfo.default.reset! :pending_transaction_fee_rates
end

s.interval "1m" do
  puts "reset transactions_last_24hrs"
  StatisticInfo.default.reset! :transactions_last_24hrs
end

s.every "1h", overlap: false do
  puts "reset hash_rate"
  StatisticInfo.default.reset! :hash_rate, :blockchain_info
end

s.every "4h", overlap: false do
  puts "reset address_balance_ranking, miner_ranking, last_n_days_transaction_fee_rates"
  StatisticInfo.default.reset! :address_balance_ranking, :miner_ranking, :last_n_days_transaction_fee_rates
end

s.every "1h", overlap: false do
  puts "update h24 transaction count"
  call_worker UpdateH24CkbTransactionsCountOnUdtsWorker
end

s.every "1h", overlap: false do
  CkbTransaction.clean_pending
end

s.join
