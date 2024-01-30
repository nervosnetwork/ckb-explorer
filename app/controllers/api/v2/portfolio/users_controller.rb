module Api
  module V2
    module Portfolio
      class UsersController < BaseController
        before_action :validate_jwt!

        def update
          Users::Update.run!({ user: current_user, name: params[:name] })

          head :no_content
        end
      end
    end
  end
end
