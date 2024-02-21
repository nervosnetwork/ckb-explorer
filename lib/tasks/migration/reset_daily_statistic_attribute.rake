namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake 'migration:reset_daily_statistic_attribute[ckb_hodl_wave]'"
  task :reset_daily_statistic_attribute, [:attribute] => :environment do |_, args|
    attribute = args[:attribute]
    DailyStatistic.where(attribute => nil).order("id asc").each do |ds|
      puts ds.created_at_unixtimestamp
      ds.reset_one!(attribute.to_sym)
    end
    puts "done"
  end
end
