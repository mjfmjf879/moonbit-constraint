///|
/// Reusable validation and diagnostics for application-facing APIs.
///
/// Validation results carry machine-readable codes and paths so command-line
/// clients can show actionable failures without parsing exception text. The
/// report is immutable from a caller's perspective but uses arrays internally
/// for low-allocation model construction.
pub enum ValidationSeverity {
  ValidationInfo
  ValidationWarning
  ValidationError
}

///|
/// One validation finding.
pub struct ValidationIssue {
  code : String
  path : String
  message : String
  severity : ValidationSeverity
}

///|
/// Construct an issue.
pub fn validation_issue(
  code : String,
  path : String,
  message : String,
  severity : ValidationSeverity,
) -> ValidationIssue {
  { code, path, message, severity }
}

///|
/// Read issue code.
pub fn ValidationIssue::code(self : ValidationIssue) -> String {
  self.code
}

///|
/// Read issue path.
pub fn ValidationIssue::path(self : ValidationIssue) -> String {
  self.path
}

///|
/// Read issue message.
pub fn ValidationIssue::message(self : ValidationIssue) -> String {
  self.message
}

///|
/// Return a stable severity label.
pub fn ValidationIssue::severity_name(self : ValidationIssue) -> String {
  match self.severity {
    ValidationInfo => "info"
    ValidationWarning => "warning"
    ValidationError => "error"
  }
}

///|
/// Render an issue for logs.
pub fn ValidationIssue::describe(self : ValidationIssue) -> String {
  "\{self.severity_name()}:\{self.code}:\{self.path}:\{self.message}"
}

///|
/// A collection of findings.
pub struct ValidationReport {
  issues : Array[ValidationIssue]
}

///|
/// Create an empty report.
pub fn validation_report() -> ValidationReport {
  { issues: [] }
}

///|
/// Add an issue.
pub fn ValidationReport::push(
  self : ValidationReport,
  issue : ValidationIssue,
) -> Unit {
  self.issues.push(issue)
}

///|
/// Add an error.
pub fn ValidationReport::error(
  self : ValidationReport,
  code : String,
  path : String,
  message : String,
) -> Unit {
  self.push(validation_issue(code, path, message, ValidationError))
}

///|
/// Add a warning.
pub fn ValidationReport::warning(
  self : ValidationReport,
  code : String,
  path : String,
  message : String,
) -> Unit {
  self.push(validation_issue(code, path, message, ValidationWarning))
}

///|
/// Add an informational note.
pub fn ValidationReport::info(
  self : ValidationReport,
  code : String,
  path : String,
  message : String,
) -> Unit {
  self.push(validation_issue(code, path, message, ValidationInfo))
}

///|
/// Return issue count.
pub fn ValidationReport::length(self : ValidationReport) -> Int {
  self.issues.length()
}

///|
/// Return whether no errors exist.
pub fn ValidationReport::valid(self : ValidationReport) -> Bool {
  self.error_count() == 0
}

///|
/// Count errors.
pub fn ValidationReport::error_count(self : ValidationReport) -> Int {
  let mut result = 0
  for issue in self.issues {
    if issue.severity is ValidationError {
      result += 1
    }
  }
  result
}

///|
/// Count warnings.
pub fn ValidationReport::warning_count(self : ValidationReport) -> Int {
  let mut result = 0
  for issue in self.issues {
    if issue.severity is ValidationWarning {
      result += 1
    }
  }
  result
}

///|
/// Return copied issues.
pub fn ValidationReport::issues(
  self : ValidationReport,
) -> Array[ValidationIssue] {
  self.issues.copy()
}

///|
/// Render all issues as newline-separated lines.
pub fn ValidationReport::describe(self : ValidationReport) -> String {
  let builder = StringBuilder()
  for index, issue in self.issues {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(issue.describe())
  }
  builder.to_string()
}

///|
/// Validate an inclusive integer range.
pub fn validate_range(
  report : ValidationReport,
  path : String,
  value : Int,
  lower : Int,
  upper : Int,
) -> Bool {
  if lower > upper {
    report.error("invalid-range", path, "lower bound exceeds upper bound")
    return false
  }
  if value < lower || value > upper {
    report.error("out-of-range", path, "value is outside the inclusive range")
    return false
  }
  true
}

///|
/// Validate a non-negative integer.
pub fn validate_nonnegative(
  report : ValidationReport,
  path : String,
  value : Int,
) -> Bool {
  if value < 0 {
    report.error("negative-value", path, "value must be non-negative")
    return false
  }
  true
}

///|
/// Validate an array's exact length.
pub fn validate_length(
  report : ValidationReport,
  path : String,
  values : Array[Int],
  expected : Int,
) -> Bool {
  if values.length() != expected {
    report.error(
      "length-mismatch", path, "array length does not match the schema",
    )
    return false
  }
  true
}

///|
/// Validate an array is nondecreasing.
pub fn validate_nondecreasing(
  report : ValidationReport,
  path : String,
  values : Array[Int],
) -> Bool {
  for index in 1..<values.length() {
    if values[index] < values[index - 1] {
      report.error(
        "not-nondecreasing",
        "\{path}[\{index}]",
        "sequence decreases",
      )
      return false
    }
  }
  true
}

///|
/// Validate an array is strictly increasing.
pub fn validate_increasing(
  report : ValidationReport,
  path : String,
  values : Array[Int],
) -> Bool {
  for index in 1..<values.length() {
    if values[index] <= values[index - 1] {
      report.error(
        "not-increasing",
        "\{path}[\{index}]",
        "sequence is not strictly increasing",
      )
      return false
    }
  }
  true
}

///|
/// Validate uniqueness.
pub fn validate_unique(
  report : ValidationReport,
  path : String,
  values : Array[Int],
) -> Bool {
  for left in 0..<values.length() {
    for right in 0..<left {
      if values[left] == values[right] {
        report.error(
          "duplicate-value",
          "\{path}[\{left}]",
          "value is duplicated",
        )
        return false
      }
    }
  }
  true
}

///|
/// Validate every value belongs to a finite set.
pub fn validate_membership(
  report : ValidationReport,
  path : String,
  values : Array[Int],
  allowed : Array[Int],
) -> Bool {
  let mut result = true
  for index, value in values {
    if !allowed.contains(value) {
      report.error(
        "invalid-member",
        "\{path}[\{index}]",
        "value is not in the allowed set",
      )
      result = false
    }
  }
  result
}

///|
/// Validate matrix shape.
pub fn validate_matrix_shape(
  report : ValidationReport,
  path : String,
  matrix : Array[Array[Int]],
  rows : Int,
  columns : Int,
) -> Bool {
  if matrix.length() != rows {
    report.error("row-count-mismatch", path, "matrix row count is invalid")
    return false
  }
  let mut result = true
  for index, row in matrix {
    if row.length() != columns {
      report.error(
        "column-count-mismatch",
        "\{path}[\{index}]",
        "matrix column count is invalid",
      )
      result = false
    }
  }
  result
}

///|
/// Validate all domains are non-empty.
pub fn validate_domains(
  report : ValidationReport,
  domains : Array[Domain],
) -> Bool {
  let mut result = true
  for index, value_domain in domains {
    if value_domain.is_empty() {
      report.error(
        "empty-domain",
        "domains[\{index}]",
        "domain contains no candidate",
      )
      result = false
    }
  }
  result
}

///|
/// Validate every assignment fits its variable domain.
pub fn validate_assignment_domains(
  report : ValidationReport,
  domains : Array[Domain],
  values : Array[Int],
) -> Bool {
  if domains.length() != values.length() {
    report.error(
      "assignment-length", "values", "assignment and domain lengths differ",
    )
    return false
  }
  let mut result = true
  for index in 0..<domains.length() {
    if !domains[index].contains(values[index]) {
      report.error(
        "assignment-outside-domain",
        "values[\{index}]",
        "assignment is not in the variable domain",
      )
      result = false
    }
  }
  result
}

///|
/// Validate a solver solution against its variable declarations.
pub fn validate_solution(
  report : ValidationReport,
  solver : Solver,
  solution : Solution,
) -> Bool {
  let variables = solver.variables()
  if variables.length() != solution.values.length() {
    report.error(
      "solution-length", "solution", "solution length differs from model",
    )
    return false
  }
  let mut result = true
  for index, variable in variables {
    if !variable.domain().contains(solution.values[index]) {
      report.error(
        "solution-domain",
        "solution[\{index}]",
        "solution value is outside its domain",
      )
      result = false
    }
  }
  result
}

///|
/// Validate a finite-domain model before solving.
pub fn validate_model(report : ValidationReport, solver : Solver) -> Bool {
  if solver.variable_count() == 0 {
    report.warning("empty-model", "solver", "model contains no variables")
  }
  if solver.constraint_count() == 0 {
    report.warning(
      "unconstrained-model", "solver", "model contains no constraints",
    )
  }
  true
}

///|
/// Validate a text field is not blank.
pub fn validate_text(
  report : ValidationReport,
  path : String,
  value : String,
) -> Bool {
  if value.trim() == "" {
    report.error("blank-text", path, "text must not be blank")
    return false
  }
  true
}

///|
/// Validate a set of names is unique and non-empty.
pub fn validate_names(
  report : ValidationReport,
  path : String,
  names : Array[String],
) -> Bool {
  let mut result = true
  for index, name in names {
    if name.trim() == "" {
      report.error("blank-name", "\{path}[\{index}]", "name must not be blank")
      result = false
    }
    for previous in 0..<index {
      if names[previous] == name {
        report.error(
          "duplicate-name",
          "\{path}[\{index}]",
          "name is duplicated",
        )
        result = false
      }
    }
  }
  result
}

///|
/// Validate a rectangular domain table.
pub fn validate_domain_table(
  report : ValidationReport,
  table : Array[Array[Int]],
) -> Bool {
  if table.length() == 0 {
    report.warning("empty-table", "table", "table has no rows")
    return true
  }
  let columns = table[0].length()
  let mut result = true
  for row in table {
    if row.length() != columns {
      report.error("ragged-table", "table", "rows have different lengths")
      result = false
    }
    for value in row {
      if value < 0 {
        report.warning(
          "negative-entry", "table", "table contains a negative entry",
        )
      }
    }
  }
  result
}

///|
/// Validate route errors into a structured report.
pub fn validate_routing_report(
  report : ValidationReport,
  routing : RoutingReport,
) -> Bool {
  if routing.errors.length() > 0 {
    for error in routing.errors {
      report.error("routing-\{error}", "routing", error)
    }
    return false
  }
  true
}

///|
/// Return a report from a solver solve attempt.
pub fn solver_validation_report(
  solver : Solver,
  solution : Solution?,
) -> ValidationReport {
  let report = validation_report()
  ignore(validate_model(report, solver))
  match solution {
    Some(value) => ignore(validate_solution(report, solver, value))
    None => report.error("unsatisfiable", "solver", "no solution was produced")
  }
  report
}

///|
/// Return a stable report fingerprint.
pub fn ValidationReport::signature(self : ValidationReport) -> Int {
  let mut result = 29
  for issue in self.issues {
    for character in issue.code {
      result = result * 31 + character.to_int()
    }
    for character in issue.path {
      result = result * 37 + character.to_int()
    }
  }
  result
}
