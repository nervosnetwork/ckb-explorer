# refresh materialized views periodically
class AverageBlockTimeGenerator
  include Sidekiq::Worker

  def perform
    AverageBlockTimeByHour.refresh
    RollingAvgBlockTime.refresh
    generate_cache
  end

  def generate_cache
    content = {
            data: {
              id: Time.current.to_i,
              type: "distribution_data",
              attributes: {
                average_block_time: RollingAvgBlockTime.all
              }
            }
          }.to_json
    path = Rails.root.join("public/api/v1/distribution_data")
    FileUtils.mkdir_p path
    filename = File.join(path, 'average_block_time')
    IO.write filename, content, mode: 'w'
  end
end
