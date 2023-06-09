namespace :api do
  namespace :v2 do
    post "/das_accounts" => "das_accounts#query", as: :das_accounts
    resources :transactions, only: [:index, :show] do
      member do
        get :details
        get :raw
      end
    end
    resources :pending_transactions, only: [:index] do
      collection do
        get :count
      end
    end
    namespace :monitors do
      resources :daily_statistics, only: :index
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
      resources :transfers, only: [:index, :show] do
        collection do
          get :download_csv
        end
      end

    end

    resources :dao_events, only: [:index]
    resources :scripts, only: [] do
      collection do
        get :ckb_transactions
        get :deployed_cells
        get :general_info
        get :referring_cells
      end
    end

    resources :blocks, only: [] do
      collection do
        get :ckb_node_versions
      end
    end

    resources :statistics, only: [] do
      collection do
        get :transaction_fees
      end
    end
  end
end
