///|
/// Variable selection strategy used by the depth-first search engine.
pub enum VariableHeuristic {
  MinimumRemainingValues
  FirstUnassigned
  MaximumDegree
  DomOverDegree
} derive(Debug, Eq)

///|
/// Value ordering strategy used when branching on a variable.
pub enum ValueHeuristic {
  AscendingValues
  DescendingValues
  MedianFirst
} derive(Debug, Eq)

///|
/// Search behavior that is stable across all supported backends.
pub struct SearchConfig {
  mut max_solutions : Int
  mut variable_heuristic : VariableHeuristic
  mut value_heuristic : ValueHeuristic
  mut propagation_rounds : Int
  mut enable_learning : Bool
  mut node_limit : Int
} derive(Debug)

///|
/// Construct the default deterministic configuration.
pub fn default_search_config() -> SearchConfig {
  {
    max_solutions: 1,
    variable_heuristic: MinimumRemainingValues,
    value_heuristic: AscendingValues,
    propagation_rounds: 10000,
    enable_learning: true,
    node_limit: 2147483647,
  }
}

///|
/// Construct a configuration suitable for exhaustive enumeration.
pub fn exhaustive_search_config(max_solutions : Int) -> SearchConfig {
  let config = default_search_config()
  config.max_solutions = if max_solutions < 1 { 1 } else { max_solutions }
  config
}

///|
/// Configuration using first-unassigned branching.
pub fn first_unassigned_config() -> SearchConfig {
  let config = default_search_config()
  config.variable_heuristic = FirstUnassigned
  config
}

///|
/// Configuration favoring highly constrained variables.
pub fn maximum_degree_config() -> SearchConfig {
  let config = default_search_config()
  config.variable_heuristic = MaximumDegree
  config
}

///|
/// Configuration using domain-over-degree branching.
pub fn domain_over_degree_config() -> SearchConfig {
  let config = default_search_config()
  config.variable_heuristic = DomOverDegree
  config
}

///|
/// Configuration that tries large values first.
pub fn descending_value_config() -> SearchConfig {
  let config = default_search_config()
  config.value_heuristic = DescendingValues
  config
}

///|
/// Configuration that tries the middle of a domain first.
pub fn median_value_config() -> SearchConfig {
  let config = default_search_config()
  config.value_heuristic = MedianFirst
  config
}

///|
/// Set the solution limit.
pub fn SearchConfig::limit(self : SearchConfig, count : Int) -> SearchConfig {
  self.max_solutions = if count < 1 { 1 } else { count }
  self
}

///|
/// Select a variable heuristic.
pub fn SearchConfig::choose_variables(
  self : SearchConfig,
  heuristic : VariableHeuristic,
) -> SearchConfig {
  self.variable_heuristic = heuristic
  self
}

///|
/// Select a value ordering heuristic.
pub fn SearchConfig::choose_values(
  self : SearchConfig,
  heuristic : ValueHeuristic,
) -> SearchConfig {
  self.value_heuristic = heuristic
  self
}

///|
/// Set the maximum number of propagation rounds at one search node.
pub fn SearchConfig::round_limit(
  self : SearchConfig,
  rounds : Int,
) -> SearchConfig {
  self.propagation_rounds = if rounds < 1 { 1 } else { rounds }
  self
}

///|
/// Enable or disable lightweight conflict learning.
pub fn SearchConfig::learning(
  self : SearchConfig,
  enabled : Bool,
) -> SearchConfig {
  self.enable_learning = enabled
  self
}

///|
/// Cap visited search nodes for interactive or service workloads.
pub fn SearchConfig::node_budget(
  self : SearchConfig,
  nodes : Int,
) -> SearchConfig {
  self.node_limit = if nodes < 1 { 1 } else { nodes }
  self
}

///|
/// Counters collected by the solver during the most recent run.
pub struct SearchStats {
  mut nodes : Int
  mut failures : Int
  mut propagations : Int
  mut constraint_checks : Int
  mut pruned_values : Int
  mut solutions : Int
  mut maximum_depth : Int
  mut restarts : Int
  mut learned_conflicts : Int
  mut truncated : Bool
} derive(Debug)

///|
/// Empty search statistics.
pub fn empty_search_stats() -> SearchStats {
  {
    nodes: 0,
    failures: 0,
    propagations: 0,
    constraint_checks: 0,
    pruned_values: 0,
    solutions: 0,
    maximum_depth: 0,
    restarts: 0,
    learned_conflicts: 0,
    truncated: false,
  }
}

///|
/// Number of visited search nodes.
pub fn SearchStats::node_count(self : SearchStats) -> Int {
  self.nodes
}

///|
/// Number of rejected branches.
pub fn SearchStats::failure_count(self : SearchStats) -> Int {
  self.failures
}

///|
/// Number of domain propagation passes.
pub fn SearchStats::propagation_count(self : SearchStats) -> Int {
  self.propagations
}

///|
/// Number of individual constraint evaluations.
pub fn SearchStats::check_count(self : SearchStats) -> Int {
  self.constraint_checks
}

///|
/// Number of values removed by propagation.
pub fn SearchStats::pruned_count(self : SearchStats) -> Int {
  self.pruned_values
}

///|
/// Number of solutions found.
pub fn SearchStats::solution_count(self : SearchStats) -> Int {
  self.solutions
}

///|
/// Maximum recursion depth reached.
pub fn SearchStats::depth(self : SearchStats) -> Int {
  self.maximum_depth
}

///|
/// Whether a node or propagation budget stopped the search.
pub fn SearchStats::is_truncated(self : SearchStats) -> Bool {
  self.truncated
}

///|
/// Render statistics as stable key-value output for CI and benchmarks.
pub fn SearchStats::describe(self : SearchStats) -> String {
  "nodes=\{self.nodes}, failures=\{self.failures}, propagations=\{self.propagations}, checks=\{self.constraint_checks}, pruned=\{self.pruned_values}, solutions=\{self.solutions}, depth=\{self.maximum_depth}, restarts=\{self.restarts}, learned=\{self.learned_conflicts}, truncated=\{self.truncated}"
}

///|
/// Direction used by optimization helpers.
pub enum OptimizationDirection {
  MinimizeValue
  MaximizeValue
} derive(Debug, Eq)

///|
/// Select minimization without constructing the enum directly.
pub fn minimize() -> OptimizationDirection {
  MinimizeValue
}

///|
/// Select maximization without constructing the enum directly.
pub fn maximize() -> OptimizationDirection {
  MaximizeValue
}

///|
/// A result that includes both a solution and its measured objective value.
pub struct OptimizationResult {
  solution : Solution
  objective : Int
} derive(Debug)

///|
/// Return the optimized solution.
pub fn OptimizationResult::solution(self : OptimizationResult) -> Solution {
  self.solution
}

///|
/// Return the objective value.
pub fn OptimizationResult::objective(self : OptimizationResult) -> Int {
  self.objective
}
