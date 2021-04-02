require_relative "../config/environment"

loop do
  Rails.logger.error "api object_id :#{CkbSync::Api.instance.object_id}"
  CkbSync::NewNodeDataProcessor.new.call
end
