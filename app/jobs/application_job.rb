class ApplicationJob < ActiveJob::Base
  def benchmark(method_name, *args)
    start_time = Time.now
    result = send(method_name, *args)
    end_time = Time.now
    puts "Method #{method_name} took #{(end_time - start_time) * 1000} milliseconds to complete."
    result
  end
end
