require_relative "../config/environment"

Rails.cache.delete("current_inauthentic_sync_round")

def generate_sync_log(latest_from, latest_to)
  return if latest_from >= latest_to
  sync_infos =
    (latest_from..latest_to).map do |number|
      SyncInfo.new(name: "inauthentic_tip_block_number", value: number, status: "syncing")
    end

  SyncInfo.import sync_infos, batch_size: 1500, on_duplicate_key_ignore: true
end

inauthentic_sync_numbers = Concurrent::Set.new

loop do
  local_tip_block_number = SyncInfo.local_inauthentic_tip_block_number
  node_tip_block_number = CkbSync::Api.instance.get_tip_block_number.to_i
  from = local_tip_block_number + 1
  to = node_tip_block_number + 1
  current_sync_round_numbers = Concurrent::Set.new

  generate_sync_log(from, to)

  return if Sidekiq::Queue.new("inauthentic_sync").size > 1000

  sync_info_values = SyncInfo.inauthentic_syncing.recent.limit(1000).pluck(:value)
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

  sleep(ENV["INAUTHENTICSYNC_LOOP_INTERVAL"].to_i)
end