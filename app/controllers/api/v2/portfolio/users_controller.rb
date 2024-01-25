module Api
  module V2
    module Portfolio
      class UsersController < BaseController
        before_action :validate_jwt!

        def update
          current_user.update(name: params[:name])

          head :no_content
        end
      end
    end
  end
end
