///|
/// A reusable batch of constraints that can be assembled before posting.
pub struct ConstraintSet {
  constraints : Array[Constraint]
}

///|
/// Create an empty constraint set.
pub fn constraint_set() -> ConstraintSet {
  { constraints: [] }
}

///|
/// Append one constraint.
pub fn ConstraintSet::add(
  self : ConstraintSet,
  constraint : Constraint,
) -> ConstraintSet {
  self.constraints.push(constraint)
  self
}

///|
/// Append every constraint from another set.
pub fn ConstraintSet::append(
  self : ConstraintSet,
  other : ConstraintSet,
) -> ConstraintSet {
  for constraint in other.constraints {
    self.constraints.push(constraint)
  }
  self
}

///|
/// Number of constraints in the set.
pub fn ConstraintSet::length(self : ConstraintSet) -> Int {
  self.constraints.length()
}

///|
/// Return a defensive copy.
pub fn ConstraintSet::constraints(self : ConstraintSet) -> Array[Constraint] {
  self.constraints.copy()
}

///|
/// Post every constraint and return the posted count.
pub fn ConstraintSet::post(self : ConstraintSet, solver : Solver) -> Int {
  for constraint in self.constraints {
    solver.add_constraint(constraint)
  }
  self.constraints.length()
}

///|
/// Render labels for a constraint batch.
pub fn ConstraintSet::labels(self : ConstraintSet) -> Array[String] {
  self.constraints.map(constraint => constraint_label(constraint))
}

///|
/// Generate pairwise inequality constraints for a variable group.
pub fn all_different_pairs(variables : Array[Int]) -> ConstraintSet {
  let result = constraint_set()
  for left in 0..<variables.length() {
    for right in (left + 1)..<variables.length() {
      ignore(result.add(not_equal(variables[left], variables[right])))
    }
  }
  result
}

///|
/// Generate an all-different global constraint and a redundant pairwise set.
pub fn strong_all_different(variables : Array[Int]) -> ConstraintSet {
  constraint_set()
  .add(all_different(variables))
  .append(all_different_pairs(variables))
}

///|
/// Generate a chain of strict inequalities.
pub fn increasing_chain(variables : Array[Int]) -> ConstraintSet {
  let result = constraint_set()
  if variables.length() < 2 {
    return result
  }
  for index in 0..<(variables.length() - 1) {
    ignore(result.add(less_than(variables[index], variables[index + 1])))
  }
  result
}

///|
/// Generate a chain of non-strict inequalities.
pub fn nondecreasing_chain(variables : Array[Int]) -> ConstraintSet {
  let result = constraint_set()
  if variables.length() < 2 {
    return result
  }
  for index in 0..<(variables.length() - 1) {
    ignore(result.add(less_equal(variables[index], variables[index + 1])))
  }
  result
}

///|
/// Generate a cyclic adjacency rule for a sequence.
pub fn cyclic_different(variables : Array[Int]) -> ConstraintSet {
  if variables.length() < 2 {
    return constraint_set()
  }
  let result = all_different_pairs(variables)
  ignore(result.add(not_equal(variables[0], variables[variables.length() - 1])))
  result
}

///|
/// Generate lower and upper bound constraints for one variable group.
pub fn group_bounds(
  variables : Array[Int],
  lower : Int,
  upper : Int,
) -> ConstraintSet {
  let result = constraint_set()
  for variable in variables {
    ignore(result.add(between(variable, lower, upper)))
  }
  result
}

///|
/// Generate an exact count and its useful at-most/at-least decomposition.
pub fn count_bundle(
  variables : Array[Int],
  value : Int,
  count : Int,
) -> ConstraintSet {
  constraint_set()
  .add(count_value(variables, value, count))
  .add(at_most_value(variables, value, count))
  .add(at_least_value(variables, value, count))
}

///|
/// Generate a one-hot Boolean encoding.
pub fn one_hot(indicators : Array[Int]) -> ConstraintSet {
  constraint_set()
  .add(sum(indicators, 1))
  .add(at_least_value(indicators, 1, 1))
  .add(at_most_value(indicators, 1, 1))
}

///|
/// Generate an exact-k Boolean cardinality encoding.
pub fn exactly_k(indicators : Array[Int], count : Int) -> ConstraintSet {
  constraint_set().add(sum(indicators, count))
}

///|
/// Generate a table relation for an array of variables.
pub fn allowed_rows(
  variables : Array[Int],
  rows : Array[Array[Int]],
) -> ConstraintSet {
  constraint_set().add(table(variables, rows))
}

///|
/// Generate row and column constraints for a rectangular matrix.
pub fn matrix_all_different(
  matrix : Array[Array[Int]],
  rows : Int,
  columns : Int,
) -> ConstraintSet? {
  if rows < 1 || columns < 1 || matrix.length() != rows {
    return None
  }
  for row in matrix {
    if row.length() != columns {
      return None
    }
  }
  let result = constraint_set()
  for row in matrix {
    ignore(result.add(all_different(row)))
  }
  for column in 0..<columns {
    let ids : Array[Int] = []
    for row in 0..<rows {
      ids.push(matrix[row][column])
    }
    ignore(result.add(all_different(ids)))
  }
  Some(result)
}

///|
/// Generate a Latin-square line-sum system.
pub fn matrix_sum_constraints(
  matrix : Array[Array[Int]],
  rows : Int,
  columns : Int,
  row_target : Int,
  column_target : Int,
) -> ConstraintSet? {
  if rows < 1 || columns < 1 || matrix.length() != rows {
    return None
  }
  for row in matrix {
    if row.length() != columns {
      return None
    }
  }
  let result = constraint_set()
  for row in matrix {
    ignore(result.add(sum(row, row_target)))
  }
  for column in 0..<columns {
    let ids : Array[Int] = []
    for row in 0..<rows {
      ids.push(matrix[row][column])
    }
    ignore(result.add(sum(ids, column_target)))
  }
  Some(result)
}

///|
/// Generate non-attacking diagonal constraints for row-position variables.
pub fn non_attacking_diagonals(positions : Array[Int]) -> ConstraintSet {
  let result = constraint_set()
  for left in 0..<positions.length() {
    for right in (left + 1)..<positions.length() {
      ignore(
        result.add(
          not_distance(positions[left], positions[right], right - left),
        ),
      )
    }
  }
  result
}

///|
/// Generate interval non-overlap constraints.
pub fn non_overlapping_intervals(
  intervals : Array[(Int, Int)],
) -> ConstraintSet {
  constraint_set().add(no_overlap(intervals))
}

///|
/// Generate a cumulative capacity constraint.
pub fn capacity_constraint(
  tasks : Array[(Int, Int, Int)],
  capacity : Int,
) -> ConstraintSet {
  constraint_set().add(cumulative(tasks, capacity))
}

///|
/// Generate a weighted equality and both safe bound relaxations.
pub fn weighted_sum_bundle(
  terms : Array[(Int, Int)],
  target : Int,
) -> ConstraintSet {
  constraint_set()
  .add(linear(terms, target))
  .add(linear_less_equal(terms, target))
  .add(linear_greater_equal(terms, target))
}

///|
/// A small report about a posted constraint batch.
pub struct ConstraintSetReport {
  count : Int
  labels : Array[String]
  fingerprint : String
}

///|
/// Summarize a constraint set before posting.
pub fn ConstraintSet::report(self : ConstraintSet) -> ConstraintSetReport {
  let builder = StringBuilder()
  for constraint in self.constraints {
    builder.write_string("\{constraint_label(constraint)};")
  }
  {
    count: self.constraints.length(),
    labels: self.labels(),
    fingerprint: builder.to_string(),
  }
}

///|
/// Return the report's count.
pub fn ConstraintSetReport::count(self : ConstraintSetReport) -> Int {
  self.count
}

///|
/// Return report labels.
pub fn ConstraintSetReport::labels(self : ConstraintSetReport) -> Array[String] {
  self.labels.copy()
}

///|
/// Return a report fingerprint.
pub fn ConstraintSetReport::fingerprint(self : ConstraintSetReport) -> String {
  self.fingerprint
}

///|
/// Render a batch report.
pub fn ConstraintSetReport::describe(self : ConstraintSetReport) -> String {
  "count=\{self.count}, labels=\{Repr(self.labels)}, fingerprint=\{self.fingerprint}"
}
