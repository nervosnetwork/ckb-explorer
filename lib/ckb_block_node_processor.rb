require_relative "../config/environment"
require "new_relic/agent"
NewRelic::Agent.manual_start(sync_startup: true)

Rails.logger = Logger.new(STDERR)
Rails.logger.level = ENV.fetch("LOG_LEVEL") { "info" }
ActiveRecord::Base.logger = Rails.logger

# The CKB node can be briefly unreachable (restart, overload, network blip).
# These failures are expected to be transient, so retry in place instead of
# letting the process die and crash-looping the container on every RPC blip.
TRANSIENT_RPC_ERRORS = [
  Net::ReadTimeout,
  Net::OpenTimeout,
  Net::WriteTimeout,
  SocketError,
  Errno::ECONNREFUSED,
  Errno::ECONNRESET,
  Errno::ETIMEDOUT,
  Errno::EHOSTUNREACH,
  Errno::ENETUNREACH,
  HTTP::ConnectionError,
  HTTP::TimeoutError,
  Net::HTTP::Persistent::Error,
].freeze
MAX_RETRY_DELAY = 60
STARTUP_MAX_ATTEMPTS = 10

def retry_delay(attempt)
  [2**attempt, MAX_RETRY_DELAY].min
end

if Rails.env.production?
  startup_attempt = 0
  begin
    check_environments
  rescue *TRANSIENT_RPC_ERRORS => e
    startup_attempt += 1
    raise if startup_attempt >= STARTUP_MAX_ATTEMPTS

    delay = retry_delay(startup_attempt)
    Rails.logger.warn(
      "CKB node unreachable on startup (#{e.class}: #{e.message}), " \
      "retry #{startup_attempt}/#{STARTUP_MAX_ATTEMPTS - 1} in #{delay}s",
    )
    sleep delay
    retry
  end
end

at_exit do
  puts "exiting & clearing"
end

puts "start"
remain = 0
duration = 0
retry_attempt = 0
loop do
  ApplicationRecord.with_advisory_lock("CkbSyncer") do # use advisory lock to prevent two node processors
    start = Time.now.to_f
    block = CkbSync::NewNodeDataProcessor.new.call
    if block
      tip_block_number = CkbSync::Api.instance.get_tip_block_number
      remain = tip_block_number - block.number
      duration = Time.now.to_f - start
    else
      remain = 0
      duration = 0
    end
    retry_attempt = 0
  end
  sleep(1 - duration) if remain <= 0 && duration < 1 # only sleep when caught up with network
rescue *TRANSIENT_RPC_ERRORS => e
  delay = retry_delay(retry_attempt)
  retry_attempt += 1
  Rails.logger.warn("transient CKB RPC failure (#{e.class}: #{e.message}), retrying in #{delay}s")
  sleep delay
end
