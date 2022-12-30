namespace :api do
  namespace :v2 do
    resources :transactions, only: [:index, :show] do
      member do
        get :raw
      end
    end
    namespace :nft do
      resources :collections do
        resources :holders, only: :index
        resources :transfers, only: :index
        resources :items do
          resources :transfers, only: [:index, :show]
        end
      end
      namespace :cota do
        resources :nft_classes, only: :index do
          resources :tokens, only: :index do
            member do
              get :claimed
              get :sender
            end
          end
        end
        resources :transactions, only: :index
        resources :issuers, only: :show do
          member do
            get :minted
          end
        end
      end
      resources :items, only: :index
      resources :transfers, only: [:index, :show]
    end

    resources :dao_events, only: [:index]
    resources :scripts, only: [] do
      collection do
        get :ckb_transactions
        get :deployed_cells
        get :referring_cells
      end
    end

    resources :blocks, only: [] do
      collection do
        get :ckb_node_versions
      end
    end
  end
end
