///|
/// Structural metrics for monitoring model growth and propagation quality.
pub struct SolverMetrics {
  variables : Int
  constraints : Int
  total_candidates : Int
  singleton_variables : Int
  empty_variables : Int
  global_constraints : Int
  arithmetic_constraints : Int
  scheduling_constraints : Int
}

///|
/// Calculate structural metrics before solving.
pub fn Solver::metrics(self : Solver) -> SolverMetrics {
  let mut total_candidates = 0
  let mut singleton_variables = 0
  let mut empty_variables = 0
  for variable in self.variables {
    let size = variable.domain.size()
    total_candidates += size
    if size == 1 {
      singleton_variables += 1
    }
    if size == 0 {
      empty_variables += 1
    }
  }
  let mut global_constraints = 0
  let mut arithmetic_constraints = 0
  let mut scheduling_constraints = 0
  for constraint in self.constraints {
    match constraint_kind(constraint) {
      GlobalConstraint => global_constraints += 1
      ArithmeticConstraint => arithmetic_constraints += 1
      SchedulingConstraint => scheduling_constraints += 1
      _ => ()
    }
  }
  {
    variables: self.variables.length(),
    constraints: self.constraints.length(),
    total_candidates,
    singleton_variables,
    empty_variables,
    global_constraints,
    arithmetic_constraints,
    scheduling_constraints,
  }
}

///|
/// Return average candidate count rounded down.
pub fn SolverMetrics::average_domain_size(self : SolverMetrics) -> Int {
  if self.variables == 0 {
    0
  } else {
    self.total_candidates / self.variables
  }
}

///|
/// Return the fraction of variables already fixed as a percentage.
pub fn SolverMetrics::fixed_percentage(self : SolverMetrics) -> Int {
  if self.variables == 0 {
    0
  } else {
    self.singleton_variables * 100 / self.variables
  }
}

///|
/// Return whether the model contains an empty domain.
pub fn SolverMetrics::has_empty_domain(self : SolverMetrics) -> Bool {
  self.empty_variables > 0
}

///|
/// Return a rough branching estimate.
pub fn SolverMetrics::branching_estimate(self : SolverMetrics) -> Int {
  if self.singleton_variables >= self.variables {
    1
  } else {
    let unassigned = self.variables - self.singleton_variables
    if unassigned == 0 {
      1
    } else {
      self.total_candidates / unassigned
    }
  }
}

///|
/// Return a stable metrics line.
pub fn SolverMetrics::describe(self : SolverMetrics) -> String {
  "variables=\{self.variables}, constraints=\{self.constraints}, candidates=\{self.total_candidates}, average_domain=\{self.average_domain_size()}, fixed=\{self.fixed_percentage()}%, branching=\{self.branching_estimate()}, global=\{self.global_constraints}, arithmetic=\{self.arithmetic_constraints}, scheduling=\{self.scheduling_constraints}"
}

///|
/// Calculate a simple model health score from 0 to 100.
pub fn SolverMetrics::health_score(self : SolverMetrics) -> Int {
  if self.has_empty_domain() {
    return 0
  }
  let mut score = 100
  if self.constraints == 0 && self.variables > 0 {
    score -= 20
  }
  if self.average_domain_size() > 1000 {
    score -= 10
  }
  if self.global_constraints == 0 &&
    self.arithmetic_constraints == 0 &&
    self.scheduling_constraints == 0 {
    score -= 10
  }
  if score < 0 {
    0
  } else {
    score
  }
}

///|
/// Render metrics and latest search statistics together.
pub fn Solver::performance_report(self : Solver) -> String {
  let metrics = self.metrics()
  "\{metrics.describe()}\nsearch=\{self.stats().describe()}\nhealth=\{metrics.health_score()}"
}

///|
/// Return a two-column map that can be emitted by a metrics adapter.
pub fn Solver::metrics_map(self : Solver) -> Map[String, Int] {
  let metrics = self.metrics()
  {
    "variables": metrics.variables,
    "constraints": metrics.constraints,
    "candidates": metrics.total_candidates,
    "fixed": metrics.singleton_variables,
    "global": metrics.global_constraints,
    "arithmetic": metrics.arithmetic_constraints,
    "scheduling": metrics.scheduling_constraints,
    "health": metrics.health_score(),
  }
}

///|
/// Return the number of candidate values removed by the last solve.
pub fn Solver::last_pruned_values(self : Solver) -> Int {
  self.last_stats.pruned_count()
}

///|
/// Return whether the last solve reached a budget limit.
pub fn Solver::last_solve_truncated(self : Solver) -> Bool {
  self.last_stats.is_truncated()
}
