desc "Usage: RAILS_ENV=production bundle exec rake 'set_flush_cache_info[liquidity deposit_compensation, true]'"
task :set_flush_cache_info, [:indicators, :dry_run] => :environment do |_, args|
  raise "please input indicators" if args[:indicators].blank?
  indicators = args[:indicators].split(" ")
  dry_run = args[:dry_run] || "true"
  if dry_run == "true"
    puts "indicators: #{indicators.join(", ")}"
  else
    Rails.cache.write("flush_cache_info", indicators, expires_in: 1.day)
    puts "done"
  end
end
