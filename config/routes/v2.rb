namespace :api do
  namespace :v2 do
    post "/das_accounts" => "das_accounts#query", as: :das_accounts
    post "/bitcoin_transactions" => "bitcoin_transactions#query", as: :bitcoin_transactions
    post "/bitcoin_vouts/verify" => "bitcoin_vouts#verify", as: :bitcoin_vouts
    resources :ckb_transactions, only: %i[index show] do
      member do
        get :details
        get :display_inputs
        get :display_outputs
        get :rgb_digest
      end
    end
    resources :transactions do
      member do
        get :raw
        get :details
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
          resources :transfers, only: %i[index show]
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
      resources :transfers, only: %i[index show] do
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
        get :referring_cells
        get :general_info
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
        get :contract_resource_distributed
      end
    end

    namespace :portfolio do
      resources :sessions, only: :create
      resource :user, only: :update
      resources :statistics, only: :index
      resources :addresses, only: :create
      resources :udt_accounts, only: :index
      resources :ckb_transactions, only: :index do
        collection do
          get :download_csv
        end
      end
    end

    resources :rgb_transactions, only: :index
    resources :bitcoin_statistics, only: :index
    resources :bitcoin_addresses, only: :show do
      get :rgb_cells, on: :member
      get :udt_accounts, on: :member
    end
    resources :rgb_live_cells, only: :index
    namespace :fiber do
      resources :peers, param: :peer_id, only: %i[index show create]
      resources :channels, param: :channel_id, only: :show
      resources :graph_nodes, param: :node_id, only: %i[index show]
      resources :graph_channels, only: :index
    end
    resources :udt_hourly_statistics, only: :show
    resources :rgbpp_assets_statistics, only: :index
  end
end
