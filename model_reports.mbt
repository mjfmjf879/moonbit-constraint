///|
/// Structured model and solve reports for CLI and CI artifacts.
///
/// Reports keep metrics close to the model that produced them, making it
/// possible to compare revisions without scraping human-oriented logs.
pub struct ModelReport {
  name : String
  variables : Int
  constraints : Int
  solved : Bool
  solutions : Int
  nodes : Int
  propagations : Int
  checks : Int
  pruned : Int
  signature : Int
}

///|
/// Build a report from a solver.
pub fn model_report(
  name : String,
  solver : Solver,
  solved : Bool,
  solutions : Int,
) -> ModelReport {
  let stats = solver.stats()
  {
    name,
    variables: solver.variable_count(),
    constraints: solver.constraint_count(),
    solved,
    solutions,
    nodes: stats.node_count(),
    propagations: stats.propagation_count(),
    checks: stats.check_count(),
    pruned: stats.pruned_count(),
    signature: solver.variable_count() * 31 +
    solver.constraint_count() * 37 +
    stats.node_count() * 41,
  }
}

///|
/// Return whether solved.
pub fn ModelReport::solved(self : ModelReport) -> Bool {
  self.solved
}

///|
/// Return work score.
pub fn ModelReport::work(self : ModelReport) -> Int {
  self.nodes + self.propagations + self.checks + self.pruned
}

///|
/// Return variable count.
pub fn ModelReport::variables(self : ModelReport) -> Int {
  self.variables
}

///|
/// Return constraint count.
pub fn ModelReport::constraints(self : ModelReport) -> Int {
  self.constraints
}

///|
/// Return solution count.
pub fn ModelReport::solutions(self : ModelReport) -> Int {
  self.solutions
}

///|
/// Return a stable one-line report.
pub fn ModelReport::describe(self : ModelReport) -> String {
  "\{self.name}: solved=\{self.solved}, solutions=\{self.solutions}, variables=\{self.variables}, constraints=\{self.constraints}, nodes=\{self.nodes}, propagations=\{self.propagations}, checks=\{self.checks}, pruned=\{self.pruned}, work=\{self.work()}"
}

///|
/// Render a report as CSV.
pub fn ModelReport::csv(self : ModelReport) -> String {
  "\{self.name},\{self.solved},\{self.solutions},\{self.variables},\{self.constraints},\{self.nodes},\{self.propagations},\{self.checks},\{self.pruned},\{self.work()}"
}

///|
/// Return a markdown table header.
pub fn model_report_header() -> String {
  "name | solved | solutions | variables | constraints | nodes | propagations | checks | pruned | work\n--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:"
}

///|
/// Render reports as a markdown table.
pub fn render_model_reports(reports : Array[ModelReport]) -> String {
  let builder = StringBuilder()
  builder.write_string(model_report_header())
  for report in reports {
    builder.write_char('\n')
    builder.write_string(
      "\{report.name} | \{report.solved} | \{report.solutions} | \{report.variables} | \{report.constraints} | \{report.nodes} | \{report.propagations} | \{report.checks} | \{report.pruned} | \{report.work()}",
    )
  }
  builder.to_string()
}

///|
/// Aggregate reports.
pub fn aggregate_model_reports(
  name : String,
  reports : Array[ModelReport],
) -> ModelReport {
  let mut variables = 0
  let mut constraints = 0
  let mut solutions = 0
  let mut nodes = 0
  let mut propagations = 0
  let mut checks = 0
  let mut pruned = 0
  let mut solved = true
  let mut signature = 17
  for report in reports {
    variables += report.variables
    constraints += report.constraints
    solutions += report.solutions
    nodes += report.nodes
    propagations += report.propagations
    checks += report.checks
    pruned += report.pruned
    solved = solved && report.solved
    signature = signature * 31 + report.signature
  }
  {
    name,
    variables,
    constraints,
    solved,
    solutions,
    nodes,
    propagations,
    checks,
    pruned,
    signature,
  }
}

///|
/// Return a regression ratio in integer percentage points.
pub fn report_work_change_percent(
  baseline : ModelReport,
  candidate : ModelReport,
) -> Int? {
  if baseline.work() == 0 {
    return None
  }
  Some((candidate.work() - baseline.work()) * 100 / baseline.work())
}

///|
/// Return whether the candidate is within a work tolerance.
pub fn report_within_tolerance(
  baseline : ModelReport,
  candidate : ModelReport,
  tolerance_percent : Int,
) -> Bool {
  !regressed(baseline.work(), candidate.work(), tolerance_percent)
}

///|
/// Return the most expensive report.
pub fn most_expensive_report(reports : Array[ModelReport]) -> ModelReport? {
  if reports.length() == 0 {
    return None
  }
  let mut result = reports[0]
  for report in reports {
    if report.work() > result.work() {
      result = report
    }
  }
  Some(result)
}

///|
/// Return solved report count.
pub fn solved_report_count(reports : Array[ModelReport]) -> Int {
  let mut result = 0
  for report in reports {
    if report.solved {
      result += 1
    }
  }
  result
}

///|
/// Return a report signature.
pub fn model_reports_signature(reports : Array[ModelReport]) -> Int {
  let mut result = 23
  for report in reports {
    result = result * 37 + report.signature
  }
  result
}
