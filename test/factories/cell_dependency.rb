FactoryBot.define do
  factory :cell_dependency do
    dep_type { :code }
    is_used { true }
  end
end
