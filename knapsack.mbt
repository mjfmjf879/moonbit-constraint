///|
/// A 0/1 knapsack model with a real weighted capacity constraint.
pub struct KnapsackItem {
  name : String
  weight : Int
  value : Int
  selected : Int
}

///|
/// A knapsack model and its objective variable.
pub struct Knapsack {
  solver : Solver
  items : Array[KnapsackItem]
  objective : Int
  capacity : Int
}

///|
/// Build a bounded 0/1 knapsack model.
pub fn knapsack(
  names : Array[String],
  weights : Array[Int],
  values : Array[Int],
  capacity : Int,
) -> Knapsack? {
  if names.length() == 0 ||
    names.length() != weights.length() ||
    names.length() != values.length() ||
    capacity < 0 {
    return None
  }
  let solver = new_solver()
  let items : Array[KnapsackItem] = []
  let weight_terms : Array[(Int, Int)] = []
  let value_terms : Array[(Int, Int)] = []
  let total_value = values.fold(init=0, (total, value) => total + value)
  for index in 0..<names.length() {
    if weights[index] < 0 {
      return None
    }
    let selected = solver.add_variable(variable("selected_\{index}", 0, 1))
    items.push({
      name: names[index],
      weight: weights[index],
      value: values[index],
      selected,
    })
    weight_terms.push((selected, weights[index]))
    value_terms.push((selected, values[index]))
  }
  solver.add_constraint(linear_less_equal(weight_terms, capacity))
  let objective = solver.add_variable(variable("total_value", 0, total_value))
  value_terms.push((objective, -1))
  solver.add_constraint(linear(value_terms, 0))
  Some({ solver, items, objective, capacity })
}

///|
/// Return the item selection variable.
pub fn Knapsack::selection_variable(self : Knapsack, item : Int) -> Int {
  match self.items.get(item) {
    Some(value) => value.selected
    None => abort("knapsack item index is outside the model")
  }
}

///|
/// Solve for a maximum-value selection.
pub fn Knapsack::solve(self : Knapsack) -> OptimizationResult? {
  self.solver.optimize(self.objective, maximize())
}

///|
/// Return the objective variable.
pub fn Knapsack::objective_variable(self : Knapsack) -> Int {
  self.objective
}

///|
/// Return all selected item names.
pub fn Knapsack::selected_names(
  self : Knapsack,
  solution : Solution,
) -> Array[String] {
  let result : Array[String] = []
  for item in self.items {
    if solution.get(item.selected) == 1 {
      result.push(item.name)
    }
  }
  result
}

///|
/// Return the total weight of a solution.
pub fn Knapsack::weight(self : Knapsack, solution : Solution) -> Int {
  let mut total = 0
  for item in self.items {
    if solution.get(item.selected) == 1 {
      total += item.weight
    }
  }
  total
}

///|
/// Return the total value of a solution.
pub fn Knapsack::value(self : Knapsack, solution : Solution) -> Int {
  solution.get(self.objective)
}

///|
/// Return whether a solution is capacity-feasible.
pub fn Knapsack::is_valid(self : Knapsack, solution : Solution) -> Bool {
  self.solver.is_valid_solution(solution) &&
  self.weight(solution) <= self.capacity
}

///|
/// Render a solution as a compact item list.
pub fn Knapsack::render(self : Knapsack, solution : Solution) -> String {
  let names = self.selected_names(solution)
  "items=\{Repr(names)}, weight=\{self.weight(solution)}, value=\{self.value(solution)}"
}

///|
/// Return solver statistics.
pub fn Knapsack::stats(self : Knapsack) -> SearchStats {
  self.solver.stats()
}

///|
/// Solve a subset-sum instance using Boolean selection variables.
pub fn subset_sum(values : Array[Int], target : Int) -> Knapsack? {
  let names = values.map(value => "value_\{value}")
  match knapsack(names, values, values, target) {
    None => None
    Some(problem) => {
      let terms : Array[(Int, Int)] = []
      for item in problem.items {
        terms.push((item.selected, item.value))
      }
      problem.solver.add_constraint(linear(terms, target))
      Some(problem)
    }
  }
}

///|
/// A small assignment problem with one worker per job and a cost objective.
pub struct AssignmentProblem {
  solver : Solver
  workers : Int
  jobs : Int
  assignments : Array[Int]
  costs : Array[Int]
  total_cost : Int
}

///|
/// Build a rectangular assignment model from a row-major cost matrix.
pub fn assignment_problem(
  jobs : Int,
  workers : Int,
  costs : Array[Array[Int]],
) -> AssignmentProblem? {
  if jobs < 1 || workers < jobs || costs.length() != jobs {
    return None
  }
  for row in costs {
    if row.length() != workers {
      return None
    }
    for value in row {
      if value < 0 {
        return None
      }
    }
  }
  let solver = new_solver()
  let assignments : Array[Int] = []
  let cost_variables : Array[Int] = []
  let linear_terms : Array[(Int, Int)] = []
  let maximum_cost = costs.fold(init=0, (total, row) => {
    total +
    row.fold(init=0, (maximum, value) => {
      if value > maximum {
        value
      } else {
        maximum
      }
    })
  })
  for job in 0..<jobs {
    let assignment = solver.add_variable(variable("job_\{job}", 0, workers - 1))
    assignments.push(assignment)
    let cost = solver.add_variable(variable("cost_\{job}", 0, maximum_cost))
    cost_variables.push(cost)
    solver.add_constraint(element(assignment, costs[job], cost))
    linear_terms.push((cost, 1))
  }
  solver.add_constraint(all_different(assignments))
  let total_cost = solver.add_variable(
    variable("total_cost", 0, maximum_cost * jobs),
  )
  linear_terms.push((total_cost, -1))
  solver.add_constraint(linear(linear_terms, 0))
  Some({ solver, workers, jobs, assignments, costs: cost_variables, total_cost })
}

///|
/// Solve for minimum total assignment cost.
pub fn AssignmentProblem::solve(
  self : AssignmentProblem,
) -> OptimizationResult? {
  self.solver.optimize(self.total_cost, minimize())
}

///|
/// Return assigned worker for a job.
pub fn AssignmentProblem::worker(
  self : AssignmentProblem,
  solution : Solution,
  job : Int,
) -> Int {
  solution.get(self.assignments[job])
}

///|
/// Return all job-to-worker assignments.
pub fn AssignmentProblem::assignments(
  self : AssignmentProblem,
  solution : Solution,
) -> Array[Int] {
  self.assignments.map(id => solution.get(id))
}

///|
/// Return the total assignment cost.
pub fn AssignmentProblem::cost(
  self : AssignmentProblem,
  solution : Solution,
) -> Int {
  solution.get(self.total_cost)
}

///|
/// Validate an assignment solution.
pub fn AssignmentProblem::is_valid(
  self : AssignmentProblem,
  solution : Solution,
) -> Bool {
  self.solver.is_valid_solution(solution)
}

///|
/// Return solver statistics.
pub fn AssignmentProblem::stats(self : AssignmentProblem) -> SearchStats {
  self.solver.stats()
}

///|
/// Return a compact assignment report.
pub fn AssignmentProblem::render(
  self : AssignmentProblem,
  solution : Solution,
) -> String {
  "workers=\{self.workers}, jobs=\{self.jobs}, assignments=\{Repr(self.assignments(solution))}, cost=\{self.cost(solution)}"
}
