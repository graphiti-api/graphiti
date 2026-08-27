# performance_history.tsv stores the id, so it must never change. The description is only displayed.
#
# latency is what every adapter call waits, standing in for a database. Only
# scenarios whose sideloads can overlap carry it, since a wait is the only thing
# the thread pool has to overlap. The rest measure graphiti's own work.
module Scenarios
  # Measured once: the pool breaks even around a millisecond a query and saves a third by five.
  QUERY_LATENCY = 0.005

  ALL = {
    "flat_10" => {
      description: "page[size]=10",
      seed: {employees: 10},
      params: {page: {size: 10}}
    },
    "flat_100" => {
      description: "page[size]=100",
      seed: {employees: 100},
      params: {page: {size: 100}}
    },
    "sparse_100" => {
      description: "page[size]=100&fields[employees]=first_name",
      seed: {employees: 100},
      params: {page: {size: 100}, fields: {employees: "first_name"}}
    },
    "include_1" => {
      description: "page[size]=50&include=positions",
      seed: {employees: 50, positions_per_employee: 4, departments: 5},
      params: {page: {size: 50}, include: "positions"}
    },
    "include_2" => {
      description: "page[size]=50&include=positions.department",
      seed: {employees: 50, positions_per_employee: 4, departments: 5},
      params: {page: {size: 50}, include: "positions.department"}
    },
    "include_3" => {
      description: "page[size]=50&include=positions.department.positions",
      seed: {employees: 50, positions_per_employee: 4, departments: 5},
      params: {page: {size: 50}, include: "positions.department.positions"}
    },
    "siblings_50" => {
      description: "page[size]=50&include=positions,credit_cards",
      seed: {employees: 50, positions_per_employee: 4, departments: 5, credit_cards_per_employee: 2},
      params: {page: {size: 50}, include: "positions,credit_cards"},
      latency: QUERY_LATENCY
    },
    "chain_and_sibling_50" => {
      description: "page[size]=50&include=positions.department,credit_cards",
      seed: {employees: 50, positions_per_employee: 4, departments: 5, credit_cards_per_employee: 2},
      params: {page: {size: 50}, include: "positions.department,credit_cards"},
      latency: QUERY_LATENCY
    },
    "deep_and_sibling_50" => {
      description: "page[size]=50&include=positions.department.positions,credit_cards",
      seed: {employees: 50, positions_per_employee: 4, departments: 5, credit_cards_per_employee: 2},
      params: {page: {size: 50}, include: "positions.department.positions,credit_cards"},
      latency: QUERY_LATENCY
    },
    "stats_100" => {
      description: "page[size]=100&stats[total]=count",
      seed: {employees: 100},
      params: {page: {size: 100}, stats: {total: "count"}}
    }
  }.freeze

  PHASES = %w[resolve render].freeze

  module_function

  def describe(id)
    ALL.dig(id, :description) || id
  end

  def descriptions
    ALL.transform_values { |scenario| scenario[:description] }
  end

  def latency(id)
    ALL.dig(id, :latency).to_f
  end

  def waiting
    ALL.select { |_, scenario| scenario[:latency].to_f.positive? }.keys
  end
end
