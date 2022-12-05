class SayHi
  include Sidekiq::Worker
  sidekiq_options queue: "critical"

  def perform
    `echo "hi #{Time.now}" >> hi.log `
  end
end
