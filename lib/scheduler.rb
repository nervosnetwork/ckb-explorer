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

s.cron "5 0 * * *" do
  call_worker Charts::DailyStatistic
end

s.every "10m" do
  call_worker Charts::BlockStatistic
end

s.every "30m" do
  call_worker Charts::EpochStatistic
end

s.every "1h" do
  call_worker DaoContractUnclaimedCompensationGenerator
end

s.cron "0 */6 * * *" do
  call_worker AddressAverageDepositTimeGenerator
end

s.every "1h" do
  call_worker AverageBlockTimeGenerator
end

s.every "1h" do
  call_worker AddressUnclaimedCompensationGenerator
end

s.every "5m" do
  call_worker PoolTransactionCheckWorker
end

s.every "1h" do
  call_worker CleanUpWorker
end

s.join
