web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml -e production
blocksyncer: bundle exec ruby lib/ckb_block_node_processor.rb
scheduler: bundle exec ruby lib/scheduler.rb
poolsyncer: bundle exec ruby lib/websocket.rb
