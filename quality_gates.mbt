///|
/// Application quality gates for local acceptance and regression checks.
///
/// Gates turn model-level invariants into a compact report: feasibility,
/// coverage, deterministic signatures, and metric thresholds can be checked
/// together before a CLI or CI job declares a scenario ready.
pub enum QualityStatus {
  GatePassed
  GateWarning
  GateFailed
}

///|
/// One quality-gate result.
pub struct QualityGateResult {
  name : String
  status : QualityStatus
  observed : Int
  threshold : Int
  detail : String
}

///|
/// Construct a result.
pub fn quality_gate_result(
  name : String,
  status : QualityStatus,
  observed : Int,
  threshold : Int,
  detail : String,
) -> QualityGateResult {
  { name, status, observed, threshold, detail }
}

///|
/// Return a status label.
pub fn QualityGateResult::status_name(self : QualityGateResult) -> String {
  match self.status {
    GatePassed => "passed"
    GateWarning => "warning"
    GateFailed => "failed"
  }
}

///|
/// Return whether this gate passes.
pub fn QualityGateResult::passed(self : QualityGateResult) -> Bool {
  self.status is GatePassed
}

///|
/// Return a stable line.
pub fn QualityGateResult::describe(self : QualityGateResult) -> String {
  "\{self.status_name()}:\{self.name}: observed=\{self.observed}, threshold=\{self.threshold}, \{self.detail}"
}

///|
/// A collection of quality-gate results.
pub struct QualityReview {
  results : Array[QualityGateResult]
}

///|
/// Create an empty review.
pub fn quality_review() -> QualityReview {
  { results: [] }
}

///|
/// Add a gate.
pub fn QualityReview::add(
  self : QualityReview,
  result : QualityGateResult,
) -> Unit {
  self.results.push(result)
}

///|
/// Add a boolean gate.
pub fn QualityReview::require(
  self : QualityReview,
  name : String,
  condition : Bool,
  detail : String,
) -> Unit {
  self.add(
    quality_gate_result(
      name,
      if condition {
        GatePassed
      } else {
        GateFailed
      },
      if condition {
        1
      } else {
        0
      },
      1,
      detail,
    ),
  )
}

///|
/// Add a non-blocking informational warning.
pub fn QualityReview::note(
  self : QualityReview,
  name : String,
  detail : String,
) -> Unit {
  self.add(quality_gate_result(name, GateWarning, 0, 0, detail))
}

///|
/// Add a minimum threshold gate.
pub fn QualityReview::minimum(
  self : QualityReview,
  name : String,
  observed : Int,
  threshold : Int,
  detail : String,
) -> Unit {
  self.add(
    quality_gate_result(
      name,
      if observed >= threshold {
        GatePassed
      } else {
        GateFailed
      },
      observed,
      threshold,
      detail,
    ),
  )
}

///|
/// Add a maximum threshold gate.
pub fn QualityReview::maximum(
  self : QualityReview,
  name : String,
  observed : Int,
  threshold : Int,
  detail : String,
) -> Unit {
  self.add(
    quality_gate_result(
      name,
      if observed <= threshold {
        GatePassed
      } else {
        GateFailed
      },
      observed,
      threshold,
      detail,
    ),
  )
}

///|
/// Return gate count.
pub fn QualityReview::length(self : QualityReview) -> Int {
  self.results.length()
}

///|
/// Return failure count.
pub fn QualityReview::failure_count(self : QualityReview) -> Int {
  let mut result = 0
  for gate in self.results {
    if gate.status is GateFailed {
      result += 1
    }
  }
  result
}

///|
/// Return warning count.
pub fn QualityReview::warning_count(self : QualityReview) -> Int {
  let mut result = 0
  for gate in self.results {
    if gate.status is GateWarning {
      result += 1
    }
  }
  result
}

///|
/// Return whether the review passes.
pub fn QualityReview::passed(self : QualityReview) -> Bool {
  self.failure_count() == 0
}

///|
/// Return copied results.
pub fn QualityReview::results(self : QualityReview) -> Array[QualityGateResult] {
  self.results.copy()
}

///|
/// Render the review.
pub fn QualityReview::describe(self : QualityReview) -> String {
  let builder = StringBuilder()
  for index, result in self.results {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(result.describe())
  }
  builder.to_string()
}

///|
/// Check a solver model and optional solution.
pub fn review_solver(solver : Solver, solution : Solution?) -> QualityReview {
  let review = quality_review()
  let validation = solver_validation_report(solver, solution)
  review.require("model-valid", validation.valid(), "model validation report")
  review.minimum("variables", solver.variable_count(), 1, "model has variables")
  review.minimum(
    "constraints",
    solver.constraint_count(),
    1,
    "model has constraints",
  )
  review.maximum(
    "validation-errors",
    validation.error_count(),
    0,
    "validation errors",
  )
  review
}

///|
/// Check a route plan.
pub fn review_routing(
  instance : RoutingInstance,
  plan : RoutingPlan,
) -> QualityReview {
  let review = quality_review()
  let report = routing_report(instance, plan)
  review.require("routing-feasible", report.feasible(), report.describe())
  review.minimum(
    "routing-visits",
    report.visits(),
    instance.customers().length(),
    "customer coverage",
  )
  review.maximum(
    "routing-errors",
    report.errors.length(),
    0,
    "route validation",
  )
  review
}

///|
/// Check a project schedule.
pub fn review_project(
  project : ProjectPlan,
  starts : Array[Int],
) -> QualityReview {
  let review = quality_review()
  let errors = project.validate_schedule(starts)
  review.require(
    "schedule-valid",
    errors.length() == 0,
    "project schedule validation",
  )
  review.minimum(
    "scheduled-tasks",
    starts.length(),
    project.task_count(),
    "task coverage",
  )
  review.maximum(
    "schedule-errors",
    errors.length(),
    0,
    "precedence and capacity",
  )
  review
}

///|
/// Check a resource timeline.
pub fn review_timeline(timeline : ResourceTimeline) -> QualityReview {
  let review = quality_review()
  review.require(
    "timeline-feasible",
    timeline.feasible(),
    "capacity and interval checks",
  )
  review.maximum(
    "timeline-conflicts",
    timeline.conflicts().length(),
    0,
    "interval conflicts",
  )
  review.minimum("timeline-intervals", timeline.length(), 0, "interval input")
  review
}

///|
/// Return a combined score where failures dominate.
pub fn QualityReview::score(self : QualityReview) -> Int {
  self.failure_count() * 1000000 + self.warning_count() * 1000 + self.length()
}

///|
/// Return a stable review signature.
pub fn QualityReview::signature(self : QualityReview) -> Int {
  let mut result = 31
  for gate in self.results {
    for character in gate.name {
      result = result * 37 + character.to_int()
    }
    result = result * 41 + gate.observed + gate.threshold
  }
  result
}

///|
/// Return a concise review status.
pub fn QualityReview::status_line(self : QualityReview) -> String {
  if self.passed() {
    "passed"
  } else {
    "failed"
  }
}
