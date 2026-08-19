///|
/// A named facade over `Solver` for applications that prefer model-building
/// APIs over manually managing integer identifiers.
pub struct ModelBuilder {
  solver : Solver
  names : Map[String, Int]
}

///|
/// Start a new named model.
pub fn new_model() -> ModelBuilder {
  { solver: new_solver(), names: {} }
}

///|
/// Add a bounded integer variable and return its identifier.
pub fn ModelBuilder::int(
  self : ModelBuilder,
  name : String,
  lower : Int,
  upper : Int,
) -> Int {
  if self.names.contains(name) {
    abort("model variable names must be unique")
  }
  let id = self.solver.add_variable(variable(name, lower, upper))
  self.names[name] = id
  id
}

///|
/// Add a named variable with an explicit finite domain.
pub fn ModelBuilder::finite(
  self : ModelBuilder,
  name : String,
  values : Array[Int],
) -> Int {
  if self.names.contains(name) {
    abort("model variable names must be unique")
  }
  let id = self.solver.add_variable(
    variable_with_domain(name, domain_from_values(values)),
  )
  self.names[name] = id
  id
}

///|
/// Resolve a variable name to an identifier.
pub fn ModelBuilder::find(self : ModelBuilder, name : String) -> Int? {
  self.names.get(name)
}

///|
/// Resolve a name or abort with a model-building error.
pub fn ModelBuilder::require(self : ModelBuilder, name : String) -> Int {
  match self.find(name) {
    Some(id) => id
    None => abort("model references an unknown variable name")
  }
}

///|
/// Post a constraint to the underlying solver.
pub fn ModelBuilder::post(self : ModelBuilder, constraint : Constraint) -> Unit {
  self.solver.add_constraint(constraint)
}

///|
/// Fix a named variable to one value.
pub fn ModelBuilder::fix(
  self : ModelBuilder,
  name : String,
  value : Int,
) -> Bool {
  self.solver.assign(self.require(name), value)
}

///|
/// Set the solution limit for the named model.
pub fn ModelBuilder::limit(self : ModelBuilder, count : Int) -> Unit {
  self.solver.limit(count)
}

///|
/// Configure the named model's search strategy.
pub fn ModelBuilder::configure(
  self : ModelBuilder,
  config : SearchConfig,
) -> Unit {
  self.solver.configure(config)
}

///|
/// Solve the named model once.
pub fn ModelBuilder::solve(self : ModelBuilder) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate solutions of the named model.
pub fn ModelBuilder::solve_all(self : ModelBuilder) -> Array[Solution] {
  self.solver.solve_all()
}

///|
/// Access the underlying solver for advanced constraints or diagnostics.
pub fn ModelBuilder::solver(self : ModelBuilder) -> Solver {
  self.solver
}

///|
/// Return the number of variables currently declared.
pub fn ModelBuilder::variable_count(self : ModelBuilder) -> Int {
  self.solver.variable_count()
}

///|
/// Return the number of constraints currently posted.
pub fn ModelBuilder::constraint_count(self : ModelBuilder) -> Int {
  self.solver.constraint_count()
}

///|
/// Return a summary that keeps names in insertion order.
pub fn ModelBuilder::summary(self : ModelBuilder) -> String {
  self.solver.summary()
}

///|
/// A small fluent builder for weighted linear constraints.
pub struct LinearBuilder {
  terms : Array[(Int, Int)]
  mut constant : Int
}

///|
/// Start an empty linear expression.
pub fn linear_builder() -> LinearBuilder {
  { terms: [], constant: 0 }
}

///|
/// Append `coefficient * variable` to an expression.
pub fn LinearBuilder::term(
  self : LinearBuilder,
  variable : Int,
  coefficient : Int,
) -> LinearBuilder {
  self.terms.push((variable, coefficient))
  self
}

///|
/// Add a constant offset to the expression.
pub fn LinearBuilder::offset(
  self : LinearBuilder,
  value : Int,
) -> LinearBuilder {
  self.constant += value
  self
}

///|
/// Return a defensive copy of expression terms.
pub fn LinearBuilder::terms(self : LinearBuilder) -> Array[(Int, Int)] {
  self.terms.copy()
}

///|
/// Return the constant offset.
pub fn LinearBuilder::constant(self : LinearBuilder) -> Int {
  self.constant
}

///|
/// Convert an expression equality into a solver constraint.
pub fn LinearBuilder::equals(self : LinearBuilder, target : Int) -> Constraint {
  linear(self.terms, target - self.constant)
}

///|
/// Add an expression equality to a named model.
pub fn LinearBuilder::post_equals(
  self : LinearBuilder,
  model : ModelBuilder,
  target : Int,
) -> Unit {
  model.post(self.equals(target))
}

///|
/// A readable, checked model construction helper for equality.
pub fn ModelBuilder::post_equal(
  self : ModelBuilder,
  left : String,
  right : String,
) -> Unit {
  self.post(equal(self.require(left), self.require(right)))
}

///|
/// A readable, checked model construction helper for inequality.
pub fn ModelBuilder::post_not_equal(
  self : ModelBuilder,
  left : String,
  right : String,
) -> Unit {
  self.post(not_equal(self.require(left), self.require(right)))
}

///|
/// A readable, checked model construction helper for ordering.
pub fn ModelBuilder::post_less_than(
  self : ModelBuilder,
  left : String,
  right : String,
) -> Unit {
  self.post(less_than(self.require(left), self.require(right)))
}

///|
/// Add an all-different constraint by variable names.
pub fn ModelBuilder::post_all_different(
  self : ModelBuilder,
  names : Array[String],
) -> Unit {
  self.post(all_different(names.map(name => self.require(name))))
}

///|
/// Add an exact count constraint by variable names.
pub fn ModelBuilder::post_count(
  self : ModelBuilder,
  names : Array[String],
  value : Int,
  count : Int,
) -> Unit {
  self.post(count_value(names.map(name => self.require(name)), value, count))
}

///|
/// Return a copy of the name-to-id map for diagnostics and adapters.
pub fn ModelBuilder::names(self : ModelBuilder) -> Map[String, Int] {
  self.names.copy()
}

///|
/// Bind a solution to a name/value map.
pub fn ModelBuilder::named_solution(
  self : ModelBuilder,
  solution : Solution,
) -> Map[String, Int] {
  let result : Map[String, Int] = Map([])
  for name, id in self.names {
    result[name] = solution.get(id)
  }
  result
}

///|
/// Format a solution using the model's declared variable order.
pub fn ModelBuilder::describe_solution(
  self : ModelBuilder,
  solution : Solution,
) -> String {
  solution.describe(self.solver.variables)
}

///|
/// A reusable collection of variable identifiers for application builders.
pub struct VariableGroup {
  ids : Array[Int]
}

///|
/// Create a group from identifiers.
pub fn variable_group(ids : Array[Int]) -> VariableGroup {
  { ids: ids.copy() }
}

///|
/// Number of variables in the group.
pub fn VariableGroup::length(self : VariableGroup) -> Int {
  self.ids.length()
}

///|
/// Return identifiers in group order.
pub fn VariableGroup::ids(self : VariableGroup) -> Array[Int] {
  self.ids.copy()
}

///|
/// Post AllDifferent for the group.
pub fn VariableGroup::all_different(
  self : VariableGroup,
  solver : Solver,
) -> Unit {
  solver.add_constraint(all_different(self.ids))
}

///|
/// Post a target sum for the group.
pub fn VariableGroup::sum(
  self : VariableGroup,
  solver : Solver,
  target : Int,
) -> Unit {
  solver.add_constraint(sum(self.ids, target))
}

///|
/// Post a count constraint for the group.
pub fn VariableGroup::count(
  self : VariableGroup,
  solver : Solver,
  value : Int,
  count : Int,
) -> Unit {
  solver.add_constraint(count_value(self.ids, value, count))
}
