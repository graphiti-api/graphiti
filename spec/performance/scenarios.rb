# performance_history.tsv stores the id, so it must never change. The description is only displayed.
module Scenarios
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
    "stats_100" => {
      description: "page[size]=100&stats[total]=count",
      seed: {employees: 100},
      params: {page: {size: 100}, stats: {total: "count"}}
    }
  }.freeze

  module_function

  def describe(id)
    ALL.dig(id, :description) || id
  end

  def descriptions
    ALL.transform_values { |scenario| scenario[:description] }
  end
end
