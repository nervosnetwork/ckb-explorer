json.data do
  json.fiber_graph_transactions @transactions
end
json.meta do
  json.total @transactions.total_count
  json.page_size @transactions.current_per_page
end
