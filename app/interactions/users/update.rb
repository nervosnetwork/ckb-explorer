module Users
  class Update < ActiveInteraction::Base
    object :user
    string :name

    validates :name, presence: true

    def execute
      user.update(name:)
    end
  end
end
