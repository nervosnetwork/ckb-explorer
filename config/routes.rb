require "sidekiq/web"
require "sidekiq_unique_jobs/web"

Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use ActionDispatch::Session::CookieStore

Rails.application.routes.draw do
  resources :token_transfers
  resources :token_items
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web => "/sidekiq"

  root "application#homepage"
  namespace :api do
    namespace :v1 do
      namespace :external do
        resources :stats, only: :show
      end
      resources :blocks, only: %i(index show) do
        get :download_csv, on: :collection
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
      resources :udt_queries, only: :index
      resources :statistics, only: %i(index show)
      resources :statistics, only: %i(index show)
      resources :nets, only: %i(index show)
      resources :statistic_info_charts, only: :index
      resources :contract_transactions, only: :show do
        get :download_csv, on: :collection
      end
      resources :contracts, only: :show
      resources :dao_contract_transactions, only: :show
      resources :address_transactions, only: :show do
        get :download_csv, on: :collection
      end
      resources :dao_depositors, only: :index do
        get :download_csv, on: :collection
      end
      resources :daily_statistics, only: :show
      resources :block_statistics, only: :show ## TODO: unused route
      resources :epoch_statistics, only: :show
      resources :market_data, only: %i[index show]
      resources :udts, only: %i(index show update) do
        get :download_csv, on: :collection
        get :holder_allocation, on: :member
      end
      resources :xudts, only: %i(index show) do
        get :download_csv, on: :collection
        get :snapshot, on: :collection
      end
      resources :fungible_tokens, only: %i(index show) do
        get :download_csv, on: :collection
      end
      resources :omiga_inscriptions, only: %i(index show) do
        get :download_csv, on: :collection
      end
      resources :udt_transactions, only: :show
      resources :address_udt_transactions, only: :show
      resources :distribution_data, only: :show
      resources :monetary_data, only: :show
      resources :udt_verifications, only: :update
      resources :address_pending_transactions, only: :show
      resources :address_live_cells, only: :show
      resources :address_deployed_cells, only: :show
    end
  end
  draw "v2"
  match "/:anything" => "errors#routing_error", via: :all, constraints: { anything: /.*/ }
end
