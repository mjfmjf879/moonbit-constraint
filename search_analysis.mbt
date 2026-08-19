///|
/// A comparative result for one search configuration.
pub struct HeuristicResult {
  name : String
  solutions : Int
  stats : SearchStats
}

///|
/// Construct a heuristic result.
pub fn heuristic_result(
  name : String,
  solutions : Int,
  stats : SearchStats,
) -> HeuristicResult {
  { name, solutions, stats }
}

///|
/// Read the strategy name.
pub fn HeuristicResult::name(self : HeuristicResult) -> String {
  self.name
}

///|
/// Read solution count.
pub fn HeuristicResult::solutions(self : HeuristicResult) -> Int {
  self.solutions
}

///|
/// Read search statistics.
pub fn HeuristicResult::stats(self : HeuristicResult) -> SearchStats {
  self.stats
}

///|
/// Render a comparative result.
pub fn HeuristicResult::describe(self : HeuristicResult) -> String {
  "\{self.name}: solutions=\{self.solutions}, \{self.stats.describe()}"
}

///|
/// Compare the built-in variable heuristics on the same model.
pub fn Solver::compare_heuristics(
  self : Solver,
  solution_limit : Int,
) -> Array[HeuristicResult] {
  let limit = if solution_limit < 1 { 1 } else { solution_limit }
  let results : Array[HeuristicResult] = []
  let configs : Array[(String, SearchConfig)] = [
    ("mrv", default_search_config()),
    ("first_unassigned", first_unassigned_config()),
    ("maximum_degree", maximum_degree_config()),
    ("domain_over_degree", domain_over_degree_config()),
  ]
  for configuration in configs {
    let (name, config) = configuration
    let solutions = self.solve_with(config.limit(limit))
    results.push(heuristic_result(name, solutions.length(), self.stats()))
  }
  results
}

///|
/// Compare the built-in value ordering heuristics.
pub fn Solver::compare_value_orders(
  self : Solver,
  solution_limit : Int,
) -> Array[HeuristicResult] {
  let limit = if solution_limit < 1 { 1 } else { solution_limit }
  let results : Array[HeuristicResult] = []
  let configs : Array[(String, SearchConfig)] = [
    ("ascending", default_search_config()),
    ("descending", descending_value_config()),
    ("median", median_value_config()),
  ]
  for configuration in configs {
    let (name, config) = configuration
    let solutions = self.solve_with(config.limit(limit))
    results.push(heuristic_result(name, solutions.length(), self.stats()))
  }
  results
}

///|
/// Return the result with the lowest deterministic work score.
pub fn best_heuristic(results : Array[HeuristicResult]) -> HeuristicResult? {
  match results.get(0) {
    None => None
    Some(first) => {
      let mut best = first
      for result in results {
        if result.stats.nodes < best.stats.nodes ||
          (
            result.stats.nodes == best.stats.nodes &&
            result.stats.constraint_checks < best.stats.constraint_checks
          ) {
          best = result
        }
      }
      Some(best)
    }
  }
}

///|
/// Solve with a node budget and expose truncation explicitly through stats.
pub fn Solver::solve_with_budget(
  self : Solver,
  node_budget : Int,
  solution_limit : Int,
) -> Array[Solution] {
  let config = default_search_config()
    .node_budget(node_budget)
    .limit(solution_limit)
  self.solve_with(config)
}

///|
/// Count solutions up to a cap while avoiding a large result allocation.
pub fn Solver::count_solutions(self : Solver, cap : Int) -> Int {
  self.limit(if cap < 1 { 1 } else { cap })
  self.solve_all().length()
}

///|
/// Return whether at least one solution exists.
pub fn Solver::is_satisfiable(self : Solver) -> Bool {
  self.solve() is Some(_)
}

///|
/// Return whether the capped enumeration was complete.
pub fn Solver::enumeration_complete(self : Solver) -> Bool {
  !self.last_stats.is_truncated()
}

///|
/// A compact audit record for a solve operation.
pub struct SolveAudit {
  satisfiable : Bool
  solutions : Int
  stats : SearchStats
  complete : Bool
}

///|
/// Run a capped solve and return its audit record.
pub fn Solver::audit(self : Solver, solution_limit : Int) -> SolveAudit {
  let solutions = self.solve_with(default_search_config().limit(solution_limit))
  {
    satisfiable: solutions.length() > 0,
    solutions: solutions.length(),
    stats: self.stats(),
    complete: self.enumeration_complete(),
  }
}

///|
/// Return a stable audit summary.
pub fn SolveAudit::describe(self : SolveAudit) -> String {
  "satisfiable=\{self.satisfiable}, solutions=\{self.solutions}, complete=\{self.complete}, \{self.stats.describe()}"
}

///|
/// Return the number of solutions in an audit.
pub fn SolveAudit::solutions(self : SolveAudit) -> Int {
  self.solutions
}

///|
/// Return whether the capped search found at least one solution.
pub fn SolveAudit::satisfiable(self : SolveAudit) -> Bool {
  self.satisfiable
}

///|
/// Return whether the search was not truncated.
pub fn SolveAudit::complete(self : SolveAudit) -> Bool {
  self.complete
}

///|
/// Return search statistics from an audit.
pub fn SolveAudit::stats(self : SolveAudit) -> SearchStats {
  self.stats
}

///|
/// Produce Markdown for comparative search output.
pub fn heuristic_markdown(results : Array[HeuristicResult]) -> String {
  let builder = StringBuilder()
  builder.write_string("| Strategy | Solutions | Nodes | Checks | Pruned |\n")
  builder.write_string("| --- | ---: | ---: | ---: | ---: |\n")
  for result in results {
    builder.write_string(
      "| \{result.name} | \{result.solutions} | \{result.stats.nodes} | \{result.stats.constraint_checks} | \{result.stats.pruned_values} |\n",
    )
  }
  builder.to_string()
}

///|
/// Return the deterministic node count of the best configuration.
pub fn best_heuristic_nodes(results : Array[HeuristicResult]) -> Int? {
  match best_heuristic(results) {
    Some(result) => Some(result.stats.nodes)
    None => None
  }
}

///|
/// Return whether all compared strategies found the same number of solutions.
pub fn heuristics_agree(results : Array[HeuristicResult]) -> Bool {
  match results.get(0) {
    None => true
    Some(first) => {
      for result in results {
        if result.solutions != first.solutions {
          return false
        }
      }
      true
    }
  }
}
