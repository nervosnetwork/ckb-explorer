Rails.application.routes.draw do
  resources :token_transfers
  resources :token_items
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  require "sidekiq/web"
  require "sidekiq_unique_jobs/web"

  mount Sidekiq::Web => "/sidekiq"

  root "application#homepage"
  namespace :api do
    namespace :v1 do
      namespace :external do
        resources :stats, only: :show
      end
      resources :blocks, only: %i(index show) do
        collection do
          get :download_csv
        end
      end
      resources :address_dao_transactions, only: :show
      resources :block_transactions, only: :show
      resources :addresses, only: :show
      get "/transactions/:id", to: "ckb_transactions#show", as: "ckb_transaction"
      get "/transactions", to: "ckb_transactions#index", as: "ckb_transactions"
      post "/transactions/query", to: "ckb_transactions#query", as: "query_ckb_transactions"
      resources :cell_input_lock_scripts, only: :show
      resources :cell_input_type_scripts, only: :show
      resources :cell_input_data, only: :show
      resources :cell_output_lock_scripts, only: :show
      resources :cell_output_type_scripts, only: :show
      resources :cell_output_data, only: :show
      resources :suggest_queries, only: :index
      resources :statistics, only: %i(index show)
      resources :nets, only: %i(index show)
      resources :statistic_info_charts, only: :index
      resources :contract_transactions, only: :show
      resources :contracts, only: :show
      resources :dao_contract_transactions, only: :show
      resources :address_transactions, only: :show do
        collection do
          get :download_csv
        end
      end
      resources :dao_depositors, only: :index
      resources :daily_statistics, only: :show
      resources :block_statistics, only: :show
      resources :epoch_statistics, only: :show
      resources :market_data, only: :show
      resources :udts, only: %i(index show) do
        collection do
          get :download_csv
        end
      end
      resources :udt_transactions, only: :show
      resources :address_udt_transactions, only: :show
      resources :distribution_data, only: :show
      resources :monetary_data, only: :show
    end
  end
  draw "v2"
  match "/:anything" => "errors#routing_error", via: :all, constraints: { anything: /.*/ }
end
