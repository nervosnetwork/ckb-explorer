json.data do
  json.(@channel, :channel_id, :state_name, :state_flags, :shutdown_at, :created_at, :updated_at, :local_balance, :offered_tlc_balance, :remote_balance, :received_tlc_balance)
end
