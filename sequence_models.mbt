///|
/// A reusable finite-domain sequence model. It is useful for quotas,
/// transition planning, configuration strings and small scheduling horizons.
pub struct SequenceModel {
  solver : Solver
  values : Array[Int]
  length : Int
  lower : Int
  upper : Int
}

///|
/// Build a sequence of `length` variables in the inclusive value interval.
pub fn sequence_model(length : Int, lower : Int, upper : Int) -> SequenceModel? {
  if length < 1 || lower > upper {
    return None
  }
  let solver = new_solver()
  let values : Array[Int] = []
  for index in 0..<length {
    values.push(
      solver.add_variable(variable("sequence_\{index}", lower, upper)),
    )
  }
  Some({ solver, values, length, lower, upper })
}

///|
/// Return the number of positions.
pub fn SequenceModel::length(self : SequenceModel) -> Int {
  self.length
}

///|
/// Return the value lower bound.
pub fn SequenceModel::lower_bound(self : SequenceModel) -> Int {
  self.lower
}

///|
/// Return the value upper bound.
pub fn SequenceModel::upper_bound(self : SequenceModel) -> Int {
  self.upper
}

///|
/// Return a copy of sequence variable identifiers.
pub fn SequenceModel::variables(self : SequenceModel) -> Array[Int] {
  self.values.copy()
}

///|
/// Validate a sequence position.
fn SequenceModel::validate_position(
  self : SequenceModel,
  position : Int,
) -> Unit {
  if position < 0 || position >= self.length {
    abort("sequence position is outside the model")
  }
}

///|
/// Validate a window length and return its start positions.
fn SequenceModel::window_starts(
  self : SequenceModel,
  width : Int,
) -> Array[Int] {
  if width < 1 || width > self.length {
    abort("sequence window has an invalid width")
  }
  let starts : Array[Int] = []
  for start in 0..<(self.length - width + 1) {
    starts.push(start)
  }
  starts
}

///|
/// Copy one half-open sequence window.
fn sequence_window(values : Array[Int], start : Int, width : Int) -> Array[Int] {
  let result : Array[Int] = []
  for index in start..<(start + width) {
    result.push(values[index])
  }
  result
}

///|
/// Post an exact weighted sum over all sequence values.
pub fn SequenceModel::post_sum(self : SequenceModel, target : Int) -> Unit {
  self.solver.add_constraint(sum(self.values, target))
}

///|
/// Restrict the total sequence sum to an inclusive interval.
pub fn SequenceModel::post_sum_between(
  self : SequenceModel,
  minimum : Int,
  maximum : Int,
) -> Unit {
  if minimum > maximum {
    abort("sequence sum interval is inverted")
  }
  let terms = self.values.map(id => (id, 1))
  self.solver.add_constraint(linear_greater_equal(terms, minimum))
  self.solver.add_constraint(linear_less_equal(terms, maximum))
}

///|
/// Require exactly `count` positions to contain `value`.
pub fn SequenceModel::post_exact_count(
  self : SequenceModel,
  value : Int,
  count : Int,
) -> Unit {
  self.solver.add_constraint(count_value(self.values, value, count))
}

///|
/// Require at most `count` positions to contain `value`.
pub fn SequenceModel::post_at_most_count(
  self : SequenceModel,
  value : Int,
  count : Int,
) -> Unit {
  self.solver.add_constraint(at_most_value(self.values, value, count))
}

///|
/// Require at least `count` positions to contain `value`.
pub fn SequenceModel::post_at_least_count(
  self : SequenceModel,
  value : Int,
  count : Int,
) -> Unit {
  self.solver.add_constraint(at_least_value(self.values, value, count))
}

///|
/// Restrict every sequence position to an explicit finite set.
pub fn SequenceModel::post_allowed_values(
  self : SequenceModel,
  allowed : Array[Int],
) -> Unit {
  for id in self.values {
    self.solver.add_constraint(allowed_values(id, allowed))
  }
}

///|
/// Require consecutive positions to differ.
pub fn SequenceModel::post_no_adjacent_equal(self : SequenceModel) -> Unit {
  if self.length < 2 {
    return
  }
  for index in 0..<(self.length - 1) {
    self.solver.add_constraint(
      not_equal(self.values[index], self.values[index + 1]),
    )
  }
}

///|
/// Require a strictly increasing sequence.
pub fn SequenceModel::post_strictly_increasing(self : SequenceModel) -> Unit {
  if self.length < 2 {
    return
  }
  for index in 0..<(self.length - 1) {
    self.solver.add_constraint(
      less_than(self.values[index], self.values[index + 1]),
    )
  }
}

///|
/// Require a nondecreasing sequence.
pub fn SequenceModel::post_nondecreasing(self : SequenceModel) -> Unit {
  if self.length < 2 {
    return
  }
  for index in 0..<(self.length - 1) {
    self.solver.add_constraint(
      less_equal(self.values[index], self.values[index + 1]),
    )
  }
}

///|
/// Require every adjacent difference to equal `distance`.
pub fn SequenceModel::post_constant_step(
  self : SequenceModel,
  distance_value : Int,
) -> Unit {
  if self.length < 2 {
    return
  }
  for index in 0..<(self.length - 1) {
    let difference = self.solver.add_variable(
      variable("step_{index}", distance_value, distance_value),
    )
    self.solver.add_constraint(
      distance(self.values[index], self.values[index + 1], difference),
    )
  }
}

///|
/// Allow only the supplied adjacent transition pairs.
pub fn SequenceModel::post_transitions(
  self : SequenceModel,
  transitions : Array[Array[Int]],
) -> Unit {
  if transitions.length() == 0 {
    abort("transition table cannot be empty")
  }
  for transition in transitions {
    if transition.length() != 2 {
      abort("transition rows must have two values")
    }
  }
  for index in 0..<(self.length - 1) {
    self.solver.add_constraint(
      table([self.values[index], self.values[index + 1]], transitions),
    )
  }
}

///|
/// Allow a different transition table at each edge.
pub fn SequenceModel::post_edge_transitions(
  self : SequenceModel,
  tables : Array[Array[Array[Int]]],
) -> Unit {
  if tables.length() != self.length - 1 {
    abort("edge transition table count does not match sequence length")
  }
  for index, transitions in tables {
    if transitions.length() == 0 {
      abort("edge transition table cannot be empty")
    }
    self.solver.add_constraint(
      table([self.values[index], self.values[index + 1]], transitions),
    )
  }
}

///|
/// Require a window to have an exact sum at every start position.
pub fn SequenceModel::post_window_sum(
  self : SequenceModel,
  width : Int,
  target : Int,
) -> Unit {
  for start in self.window_starts(width) {
    let window = sequence_window(self.values, start, width)
    self.solver.add_constraint(sum(window, target))
  }
}

///|
/// Require a window to contain exactly `count` occurrences of `value`.
pub fn SequenceModel::post_window_count(
  self : SequenceModel,
  width : Int,
  value : Int,
  count : Int,
) -> Unit {
  for start in self.window_starts(width) {
    let window = sequence_window(self.values, start, width)
    self.solver.add_constraint(count_value(window, value, count))
  }
}

///|
/// Bound the length of every same-value run.
pub fn SequenceModel::post_run_limit(
  self : SequenceModel,
  maximum_run : Int,
) -> Unit {
  if maximum_run < 1 {
    abort("maximum run must be positive")
  }
  let width = maximum_run + 1
  if width > self.length {
    return
  }
  for value in self.lower..<=self.upper {
    for start in self.window_starts(width) {
      let window = sequence_window(self.values, start, width)
      self.solver.add_constraint(at_most_value(window, value, maximum_run))
    }
  }
}

///|
/// Post a table relation over one or more consecutive windows.
pub fn SequenceModel::post_window_table(
  self : SequenceModel,
  width : Int,
  rows : Array[Array[Int]],
) -> Unit {
  if width < 1 {
    abort("window table width must be positive")
  }
  for row in rows {
    if row.length() != width {
      abort("window table row has the wrong width")
    }
  }
  for start in self.window_starts(width) {
    self.solver.add_constraint(
      table(sequence_window(self.values, start, width), rows),
    )
  }
}

///|
/// Bind a position to a constant value.
pub fn SequenceModel::fix(
  self : SequenceModel,
  position : Int,
  value : Int,
) -> Bool {
  self.validate_position(position)
  self.solver.assign(self.values[position], value)
}

///|
/// Return the current domain of a sequence position.
pub fn SequenceModel::domain_of(self : SequenceModel, position : Int) -> Domain {
  self.validate_position(position)
  self.solver.domain_of(self.values[position])
}

///|
/// Set the search configuration.
pub fn SequenceModel::configure(
  self : SequenceModel,
  config : SearchConfig,
) -> Unit {
  self.solver.configure(config)
}

///|
/// Solve for one sequence.
pub fn SequenceModel::solve(self : SequenceModel) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate up to `limit` sequences.
pub fn SequenceModel::solve_all(
  self : SequenceModel,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return the latest search statistics.
pub fn SequenceModel::stats(self : SequenceModel) -> SearchStats {
  self.solver.stats()
}

///|
/// Check a solution against the sequence model.
pub fn SequenceModel::is_valid(
  self : SequenceModel,
  solution : Solution,
) -> Bool {
  self.solver.is_valid_solution(solution)
}

///|
/// Extract sequence values from a solution.
pub fn SequenceModel::values_of(
  self : SequenceModel,
  solution : Solution,
) -> Array[Int] {
  self.values.map(id => solution.get(id))
}

///|
/// Render a sequence as a space-separated row.
pub fn SequenceModel::render(
  self : SequenceModel,
  solution : Solution,
) -> String {
  render_integer_sequence(self.values_of(solution))
}

///|
/// Summary statistics for a complete sequence.
pub struct SequenceSummary {
  values : Array[Int]
  total : Int
  minimum : Int
  maximum : Int
  changes : Int
  runs : Int
} derive(Debug, Eq)

///|
/// Compute summary statistics for an array of values.
pub fn sequence_summary(values : Array[Int]) -> SequenceSummary? {
  if values.length() == 0 {
    return None
  }
  let mut total = 0
  let mut minimum = values[0]
  let mut maximum = values[0]
  let mut changes = 0
  for index, value in values {
    total += value
    if value < minimum {
      minimum = value
    }
    if value > maximum {
      maximum = value
    }
    if index > 0 && value != values[index - 1] {
      changes += 1
    }
  }
  Some({
    values: values.copy(),
    total,
    minimum,
    maximum,
    changes,
    runs: changes + 1,
  })
}

///|
/// Return the values in a sequence summary.
pub fn SequenceSummary::values(self : SequenceSummary) -> Array[Int] {
  self.values.copy()
}

///|
/// Return the sum.
pub fn SequenceSummary::total(self : SequenceSummary) -> Int {
  self.total
}

///|
/// Return the minimum.
pub fn SequenceSummary::minimum(self : SequenceSummary) -> Int {
  self.minimum
}

///|
/// Return the maximum.
pub fn SequenceSummary::maximum(self : SequenceSummary) -> Int {
  self.maximum
}

///|
/// Return the number of adjacent changes.
pub fn SequenceSummary::changes(self : SequenceSummary) -> Int {
  self.changes
}

///|
/// Return the number of same-value runs.
pub fn SequenceSummary::runs(self : SequenceSummary) -> Int {
  self.runs
}

///|
/// Render a sequence summary.
pub fn SequenceSummary::describe(self : SequenceSummary) -> String {
  "values=\{render_integer_sequence(self.values)} total=\{self.total} min=\{self.minimum} max=\{self.maximum} changes=\{self.changes} runs=\{self.runs}"
}

///|
/// Render integer values with stable spacing.
pub fn render_integer_sequence(values : Array[Int]) -> String {
  let builder = StringBuilder()
  for index, value in values {
    if index > 0 {
      builder.write_char(' ')
    }
    builder.write_string("\{value}")
  }
  builder.to_string()
}

///|
/// Parse a whitespace-separated integer sequence.
pub fn parse_integer_sequence(input : String) -> Array[Int]? {
  parse_integer_list(input)
}

///|
/// Build a binary sequence with exactly `ones` true positions.
pub fn binary_sequence(length : Int, ones : Int) -> SequenceModel? {
  if length < 1 || ones < 0 || ones > length {
    return None
  }
  match sequence_model(length, 0, 1) {
    Some(model) => {
      model.post_exact_count(1, ones)
      Some(model)
    }
    None => None
  }
}

///|
/// Build a balanced binary sequence with no adjacent equal positions.
pub fn alternating_binary_sequence(length : Int) -> SequenceModel? {
  match binary_sequence(length, length / 2) {
    Some(model) => {
      model.post_no_adjacent_equal()
      Some(model)
    }
    None => None
  }
}

///|
/// Build a bounded sequence with a fixed total and no long runs.
pub fn quota_sequence(
  length : Int,
  lower : Int,
  upper : Int,
  total : Int,
  maximum_run : Int,
) -> SequenceModel? {
  match sequence_model(length, lower, upper) {
    Some(model) => {
      model.post_sum(total)
      model.post_run_limit(maximum_run)
      Some(model)
    }
    None => None
  }
}

///|
/// Return a canonical transition table for a binary automaton.
pub fn binary_transitions() -> Array[Array[Int]] {
  [[0, 0], [0, 1], [1, 0], [1, 1]]
}

///|
/// Return every value used by a complete solution.
pub fn SequenceModel::solution_summary(
  self : SequenceModel,
  solution : Solution,
) -> SequenceSummary? {
  sequence_summary(self.values_of(solution))
}

///|
/// Return a compact sequence fingerprint.
pub fn SequenceModel::fingerprint(
  self : SequenceModel,
  solution : Solution,
) -> String {
  self
  .values_of(solution)
  .fold(init="", (text, value) => {
    if text.length() == 0 {
      "\{value}"
    } else {
      "\{text},\{value}"
    }
  })
}
