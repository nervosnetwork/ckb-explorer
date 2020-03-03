class UdtSerializer
  include FastJsonapi::ObjectSerializer

  attributes :symbol, :full_name, :total_amount, :addresses_count, :decimal
end
