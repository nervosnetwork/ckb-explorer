namespace :api do
  namespace :v2 do
    namespace :nft do
      resources :collections do
        resources :holders, only: :index
        resources :transfers, only: :index
        resources :items do
          resources :transfers, only: [:index, :show]
        end
      end
      resources :items, only: :index
      resources :transfers, only: [:index, :show]
    end
  end
end
