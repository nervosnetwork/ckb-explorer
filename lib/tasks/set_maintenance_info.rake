desc "Usage: RAILS_ENV=production bundle exec rake 'set_maintenance_info[2020-06-09 00:00:00, nil]'"
task :set_maintenance_info, [:start_at, :end_at, :dry_run] => :environment do |_, args|
  raise "please input start at" if args[:start_at].blank?

  start_at = Time.parse(args[:start_at])
  dry_run = args[:dry_run] || "true"
  if args[:end_at] != "nil"
    end_at = Time.parse(args[:end_at])
  else
    end_at = start_at + 2.hours
  end
  if dry_run == "true"
    puts "start_at: #{start_at}"
    puts "end_at: #{end_at}"
  else
    info = { start_at: start_at, end_at: end_at }
    Rails.cache.write("maintenance_info", info)
  end
end
