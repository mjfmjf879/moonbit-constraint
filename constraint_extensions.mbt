///|
/// Higher-level constraint model builders.
///
/// The builder layer packages recurring finite-domain patterns—grids,
/// cardinality rules, automaton-like transitions, and resource windows—into
/// small APIs that remain inspectable through the underlying Solver.
pub struct ConstraintBuilder {
  solver : Solver
  variables : Array[Int]
}

///|
/// Create an empty builder.
pub fn constraint_builder() -> ConstraintBuilder {
  { solver: new_solver(), variables: [] }
}

///|
/// Add a bounded integer variable.
pub fn ConstraintBuilder::add_int(
  self : ConstraintBuilder,
  name : String,
  lower : Int,
  upper : Int,
) -> Int {
  let id = self.solver.add_variable(variable(name, lower, upper))
  self.variables.push(id)
  id
}

///|
/// Add a Boolean variable.
pub fn ConstraintBuilder::add_bool(
  self : ConstraintBuilder,
  name : String,
) -> Int {
  self.add_int(name, 0, 1)
}

///|
/// Return the underlying solver.
pub fn ConstraintBuilder::solver(self : ConstraintBuilder) -> Solver {
  self.solver
}

///|
/// Return all variable ids.
pub fn ConstraintBuilder::variables(self : ConstraintBuilder) -> Array[Int] {
  self.variables.copy()
}

///|
/// Add all-different constraints for a variable list.
pub fn ConstraintBuilder::all_different(
  self : ConstraintBuilder,
  variables : Array[Int],
) -> Bool {
  if variables.length() < 2 {
    return true
  }
  self.solver.add_constraint(all_different(variables))
  true
}

///|
/// Add a row-major integer grid with one variable per cell.
pub fn ConstraintBuilder::grid(
  self : ConstraintBuilder,
  name : String,
  rows : Int,
  columns : Int,
  lower : Int,
  upper : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  if rows <= 0 || columns <= 0 {
    return result
  }
  for row in 0..<rows {
    for column in 0..<columns {
      result.push(self.add_int("\{name}_\{row}_\{column}", lower, upper))
    }
  }
  result
}

///|
/// Add all-different rules to each grid row.
pub fn ConstraintBuilder::grid_rows(
  self : ConstraintBuilder,
  grid : Array[Int],
  rows : Int,
  columns : Int,
) -> Bool {
  if rows < 0 || columns < 0 || grid.length() != rows * columns {
    return false
  }
  for row in 0..<rows {
    let values : Array[Int] = []
    for column in 0..<columns {
      values.push(grid[row * columns + column])
    }
    ignore(self.all_different(values))
  }
  true
}

///|
/// Add all-different rules to each grid column.
pub fn ConstraintBuilder::grid_columns(
  self : ConstraintBuilder,
  grid : Array[Int],
  rows : Int,
  columns : Int,
) -> Bool {
  if rows < 0 || columns < 0 || grid.length() != rows * columns {
    return false
  }
  for column in 0..<columns {
    let values : Array[Int] = []
    for row in 0..<rows {
      values.push(grid[row * columns + column])
    }
    ignore(self.all_different(values))
  }
  true
}

///|
/// Add a fixed target sum.
pub fn ConstraintBuilder::exact_sum(
  self : ConstraintBuilder,
  variables : Array[Int],
  target : Int,
) -> Bool {
  if variables.length() == 0 {
    return target == 0
  }
  self.solver.add_constraint(sum(variables, target))
  true
}

///|
/// Add a weighted sum bound.
pub fn ConstraintBuilder::weighted_at_most(
  self : ConstraintBuilder,
  terms : Array[(Int, Int)],
  target : Int,
) -> Bool {
  self.solver.add_constraint(linear_less_equal(terms, target))
  true
}

///|
/// Add a weighted lower bound.
pub fn ConstraintBuilder::weighted_at_least(
  self : ConstraintBuilder,
  terms : Array[(Int, Int)],
  target : Int,
) -> Bool {
  self.solver.add_constraint(linear_greater_equal(terms, target))
  true
}

///|
/// Add an exact count of a value.
pub fn ConstraintBuilder::exact_count(
  self : ConstraintBuilder,
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Bool {
  if count < 0 || count > variables.length() {
    return false
  }
  self.solver.add_constraint(count_value(variables, value, count))
  true
}

///|
/// Add an upper count.
pub fn ConstraintBuilder::at_most_count(
  self : ConstraintBuilder,
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Bool {
  if count < 0 {
    return false
  }
  self.solver.add_constraint(at_most_value(variables, value, count))
  true
}

///|
/// Add a lower count.
pub fn ConstraintBuilder::at_least_count(
  self : ConstraintBuilder,
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Bool {
  if count < 0 || count > variables.length() {
    return false
  }
  self.solver.add_constraint(at_least_value(variables, value, count))
  true
}

///|
/// Add pairwise separation by a minimum absolute distance.
pub fn ConstraintBuilder::minimum_distance(
  self : ConstraintBuilder,
  variables : Array[Int],
  distance : Int,
) -> Bool {
  if distance < 0 {
    return false
  }
  for left in 0..<variables.length() {
    for right in (left + 1)..<variables.length() {
      self.solver.add_constraint(
        not_distance(variables[left], variables[right], distance - 1),
      )
    }
  }
  true
}

///|
/// Add a chain of strict ordering constraints.
pub fn ConstraintBuilder::strict_chain(
  self : ConstraintBuilder,
  variables : Array[Int],
) -> Bool {
  for index in 1..<variables.length() {
    self.solver.add_constraint(
      less_than(variables[index - 1], variables[index]),
    )
  }
  true
}

///|
/// Add a nondecreasing chain.
pub fn ConstraintBuilder::nondecreasing_chain(
  self : ConstraintBuilder,
  variables : Array[Int],
) -> Bool {
  for index in 1..<variables.length() {
    self.solver.add_constraint(
      less_equal(variables[index - 1], variables[index]),
    )
  }
  true
}

///|
/// Add adjacent inequality constraints.
pub fn ConstraintBuilder::adjacent_different(
  self : ConstraintBuilder,
  variables : Array[Int],
) -> Bool {
  for index in 1..<variables.length() {
    self.solver.add_constraint(
      not_equal(variables[index - 1], variables[index]),
    )
  }
  true
}

///|
/// Add a transition table to adjacent state variables.
pub fn ConstraintBuilder::transition_table(
  self : ConstraintBuilder,
  variables : Array[Int],
  transitions : Array[Array[Int]],
) -> Bool {
  if variables.length() < 2 {
    return true
  }
  for index in 1..<variables.length() {
    self.solver.add_constraint(
      table([variables[index - 1], variables[index]], transitions),
    )
  }
  true
}

///|
/// Add interval no-overlap constraints.
pub fn ConstraintBuilder::no_overlap(
  self : ConstraintBuilder,
  starts : Array[Int],
  durations : Array[Int],
) -> Bool {
  if starts.length() != durations.length() {
    return false
  }
  let intervals : Array[(Int, Int)] = []
  for index in 0..<starts.length() {
    if durations[index] < 0 {
      return false
    }
    intervals.push((starts[index], durations[index]))
  }
  if intervals.length() > 1 {
    self.solver.add_constraint(no_overlap(intervals))
  }
  true
}

///|
/// Add a cumulative capacity constraint.
pub fn ConstraintBuilder::cumulative(
  self : ConstraintBuilder,
  starts : Array[Int],
  durations : Array[Int],
  heights : Array[Int],
  capacity : Int,
) -> Bool {
  if starts.length() != durations.length() ||
    starts.length() != heights.length() ||
    capacity < 0 {
    return false
  }
  let intervals : Array[(Int, Int, Int)] = []
  for index in 0..<starts.length() {
    if durations[index] < 0 || heights[index] < 0 {
      return false
    }
    intervals.push((starts[index], durations[index], heights[index]))
  }
  self.solver.add_constraint(cumulative(intervals, capacity))
  true
}

///|
/// Fix a variable.
pub fn ConstraintBuilder::fix(
  self : ConstraintBuilder,
  variable_id : Int,
  value : Int,
) -> Bool {
  self.solver.assign(variable_id, value)
}

///|
/// Solve once.
pub fn ConstraintBuilder::solve(self : ConstraintBuilder) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate a bounded number of solutions.
pub fn ConstraintBuilder::solve_all(
  self : ConstraintBuilder,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return a builder summary.
pub fn ConstraintBuilder::describe(self : ConstraintBuilder) -> String {
  "variables=\{self.solver.variable_count()}, constraints=\{self.solver.constraint_count()}"
}

///|
/// Create a Boolean indicator for an exact value through a two-row table.
pub fn post_indicator(
  builder : ConstraintBuilder,
  source : Int,
  value : Int,
  indicator : Int,
) -> Bool {
  builder.solver.add_constraint(
    table([source, indicator], [[value, 1], [value + 1, 0], [value - 1, 0]]),
  )
  true
}

///|
/// Add a one-hot vector constraint.
pub fn post_one_hot(
  builder : ConstraintBuilder,
  indicators : Array[Int],
) -> Bool {
  builder.exact_sum(indicators, 1)
}

///|
/// Add a zero-or-one vector constraint.
pub fn post_binary_vector(
  builder : ConstraintBuilder,
  variables : Array[Int],
) -> Bool {
  for variable_id in variables {
    builder.solver.add_constraint(between(variable_id, 0, 1))
  }
  true
}

///|
/// Return a model fingerprint.
pub fn ConstraintBuilder::signature(self : ConstraintBuilder) -> Int {
  self.solver.variable_count() * 31 + self.solver.constraint_count() * 37
}
