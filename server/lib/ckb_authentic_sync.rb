require_relative "../config/environment"

Rails.cache.delete("current_authentic_sync_round")

def generate_sync_log(latest_from, latest_to)
  sync_infos =
    (latest_from..latest_to).map do |number|
      SyncInfo.new(name: "authentic_tip_block_number", value: number, status: "syncing")
    end

  SyncInfo.import sync_infos, batch_size: 1500, on_duplicate_key_ignore: true
end

inauthentic_sync_numbers = Concurrent::Set.new

loop do
  authentic_tip_block_number = SyncInfo.local_authentic_tip_block_number
  inauthentic_tip_block_number = SyncInfo.local_inauthentic_tip_block_number
  from = authentic_tip_block_number + 1
  to = inauthentic_tip_block_number - ENV["BLOCK_SAFETY_INTERVAL"].to_i
  current_sync_round_numbers = Concurrent::Set.new

  generate_sync_log(from, to)

  return if Sidekiq::Queue.new("authentic_sync").size > 4000

  sync_info_values = SyncInfo.authentic_syncing.recent.limit(1000).pluck(:value)

  sync_info_values.each do |number|
    current_sync_round_numbers << number
  end

  if inauthentic_sync_numbers.empty?
    sync_info_values.each do |number|
      inauthentic_sync_numbers << number
    end

    CkbSync::InauthenticSync.sync_node_data(inauthentic_sync_numbers)
  else
    sync_numbers = current_sync_round_numbers - inauthentic_sync_numbers
    if sync_numbers.present?
      sync_numbers.each do |number|
        inauthentic_sync_numbers << number
      end
      CkbSync::InauthenticSync.sync_node_data(sync_numbers)
    end
  end

  sleep(ENV["AUTHENTICSYNC_LOOP_INTERVAL"].to_i)
end