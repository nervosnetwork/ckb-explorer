FactoryBot.define do
  factory :deployed_cell do
    cell_id { 1 }
    contract_id { 1 }
    is_initialized { false }
  end
end
