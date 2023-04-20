class ApplicationJob < ActiveJob::Base
  def benchmark(method_name = nil, *args)
    ApplicationRecord.benchmark method_name do
      send(method_name, *args)
    end
  end
end
