module Api
  module V2
    class BaseController < ActionController::API
      include Pagy::Backend
    end
  end
end
