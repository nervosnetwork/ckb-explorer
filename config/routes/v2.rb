namespace :api do
  namespace :v2 do
    namespace :nft do
      resources :collections do
        resources :transfers, only: :index
        resources :items do 
          resources :transfers, only: :index
        end
      end
      resources :items, only: :index
      resources :transfers, only: :show
    end
  end
end
