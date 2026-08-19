///|
/// Model-size limits for services that accept user-authored constraints.
pub struct ModelLimits {
  max_variables : Int
  max_constraints : Int
  max_domain_size : Int
}

///|
/// Construct model limits with positive defaults for invalid values.
pub fn model_limits(
  max_variables : Int,
  max_constraints : Int,
  max_domain_size : Int,
) -> ModelLimits {
  {
    max_variables: if max_variables < 1 {
      1
    } else {
      max_variables
    },
    max_constraints: if max_constraints < 1 {
      1
    } else {
      max_constraints
    },
    max_domain_size: if max_domain_size < 1 {
      1
    } else {
      max_domain_size
    },
  }
}

///|
/// Practical limits for an embedded library use case.
pub fn default_model_limits() -> ModelLimits {
  model_limits(10000, 50000, 100000)
}

///|
/// Check whether a model fits configured structural limits.
pub fn Solver::within_limits(self : Solver, limits : ModelLimits) -> Bool {
  if self.variables.length() > limits.max_variables ||
    self.constraints.length() > limits.max_constraints {
    return false
  }
  for variable in self.variables {
    if variable.domain.size() > limits.max_domain_size {
      return false
    }
  }
  true
}

///|
/// Return the first limit category exceeded by a model.
pub fn Solver::limit_violation(self : Solver, limits : ModelLimits) -> String? {
  if self.variables.length() > limits.max_variables {
    return Some("variables")
  }
  if self.constraints.length() > limits.max_constraints {
    return Some("constraints")
  }
  for variable in self.variables {
    if variable.domain.size() > limits.max_domain_size {
      return Some("domain_size")
    }
  }
  None
}

///|
/// Public status of a guarded solve.
pub enum SolveStatus {
  SolvedStatus
  UnsatisfiableStatus
  LimitRejectedStatus
  BudgetExceededStatus
} derive(Debug, Eq)

///|
/// Result of a solve subject to structural and search limits.
pub struct GuardedSolve {
  status : SolveStatus
  solution : Solution?
  stats : SearchStats
  reason : String?
}

///|
/// Return the solve status.
pub fn GuardedSolve::status(self : GuardedSolve) -> SolveStatus {
  self.status
}

///|
/// Return the optional solution.
pub fn GuardedSolve::solution(self : GuardedSolve) -> Solution? {
  self.solution
}

///|
/// Return solve counters.
pub fn GuardedSolve::stats(self : GuardedSolve) -> SearchStats {
  self.stats
}

///|
/// Return an optional rejection or budget reason.
pub fn GuardedSolve::reason(self : GuardedSolve) -> String? {
  self.reason
}

///|
/// Render a guarded solve result.
pub fn GuardedSolve::describe(self : GuardedSolve) -> String {
  let status = match self.status {
    SolvedStatus => "solved"
    UnsatisfiableStatus => "unsatisfiable"
    LimitRejectedStatus => "limit_rejected"
    BudgetExceededStatus => "budget_exceeded"
  }
  let has_solution = self.solution is Some(_)
  "status=\{status}, solution=\{has_solution}, reason=\{Repr(self.reason)}, \{self.stats.describe()}"
}

///|
/// Solve one model while enforcing both structural and node limits.
pub fn Solver::guarded_solve(
  self : Solver,
  limits : ModelLimits,
  node_budget : Int,
) -> GuardedSolve {
  match self.limit_violation(limits) {
    Some(reason) => {
      self.reset_stats()
      {
        status: LimitRejectedStatus,
        solution: None,
        stats: self.stats(),
        reason: Some(reason),
      }
    }
    None => {
      let config = default_search_config().node_budget(node_budget).limit(1)
      let solutions = self.solve_with(config)
      if solutions.length() > 0 {
        {
          status: SolvedStatus,
          solution: solutions.get(0),
          stats: self.stats(),
          reason: None,
        }
      } else if self.last_solve_truncated() {
        {
          status: BudgetExceededStatus,
          solution: None,
          stats: self.stats(),
          reason: Some("node_budget"),
        }
      } else {
        {
          status: UnsatisfiableStatus,
          solution: None,
          stats: self.stats(),
          reason: None,
        }
      }
    }
  }
}

///|
/// Return whether a guarded solve reached a valid solution.
pub fn GuardedSolve::is_success(self : GuardedSolve) -> Bool {
  self.status is SolvedStatus
}

///|
/// Return whether a guarded solve was rejected before search.
pub fn GuardedSolve::was_rejected(self : GuardedSolve) -> Bool {
  self.status is LimitRejectedStatus
}

///|
/// Return whether a guarded solve exhausted its node budget.
pub fn GuardedSolve::was_budget_limited(self : GuardedSolve) -> Bool {
  self.status is BudgetExceededStatus
}

///|
/// Validate a model and return a human-readable failure reason.
pub fn Solver::validation_error(self : Solver) -> String? {
  if !self.has_nonempty_domains() {
    return Some("empty_domain")
  }
  if !self.validate() {
    return Some("invalid_constraint_reference")
  }
  None
}

///|
/// Return whether a model is ready to enter search.
pub fn Solver::ready(self : Solver) -> Bool {
  self.validation_error() is None
}

///|
/// Return a defensive copy of a guarded result's solution values.
pub fn GuardedSolve::solution_values(self : GuardedSolve) -> Array[Int]? {
  match self.solution {
    Some(solution) => Some(solution.values())
    None => None
  }
}

///|
/// Render a model readiness check.
pub fn Solver::readiness_report(self : Solver, limits : ModelLimits) -> String {
  let metrics = self.metrics()
  let violation = self.limit_violation(limits)
  "ready=\{self.ready()}, violation=\{Repr(violation)}, \{metrics.describe()}"
}
