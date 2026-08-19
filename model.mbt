///|
/// A named finite-domain variable.
pub struct Variable {
  name : String
  domain : Domain
} derive(Debug)

///|
/// Define a variable with an inclusive integer range.
pub fn variable(name : String, lower : Int, upper : Int) -> Variable {
  { name, domain: domain(lower, upper) }
}

///|
/// Define a variable from an explicit finite domain.
pub fn variable_with_domain(name : String, value_domain : Domain) -> Variable {
  { name, domain: value_domain }
}

///|
/// Return a variable's stable user-facing name.
pub fn Variable::name(self : Variable) -> String {
  self.name
}

///|
/// Return an independent copy of the variable and its domain.
pub fn Variable::clone(self : Variable) -> Variable {
  { name: self.name, domain: self.domain.clone() }
}

///|
/// Return the current domain of a variable.
pub fn Variable::domain(self : Variable) -> Domain {
  self.domain
}

///|
/// Return the number of candidate values for a variable.
pub fn Variable::size(self : Variable) -> Int {
  self.domain.size()
}

///|
/// Constraints supported by the first solver engine.
pub enum Constraint {
  Equal(Int, Int)
  NotEqual(Int, Int)
  LessThan(Int, Int)
  LessEqual(Int, Int)
  GreaterThan(Int, Int)
  GreaterEqual(Int, Int)
  AllDifferent(Array[Int])
  Sum(Array[Int], Int)
  Element(Int, Array[Int], Int)
  Linear(Array[(Int, Int)], Int)
  LinearLessEqual(Array[(Int, Int)], Int)
  LinearGreaterEqual(Array[(Int, Int)], Int)
  Between(Int, Int, Int)
  Member(Int, Array[Int])
  CountValue(Array[Int], Int, Int)
  AtMostValue(Array[Int], Int, Int)
  AtLeastValue(Array[Int], Int, Int)
  Minimum(Array[Int], Int)
  Maximum(Array[Int], Int)
  Absolute(Int, Int)
  Distance(Int, Int, Int)
  NotDistance(Int, Int, Int)
  Table(Array[Int], Array[Array[Int]])
  NoOverlap(Array[(Int, Int)])
  Cumulative(Array[(Int, Int, Int)], Int)
} derive(Debug)

///|
/// Shorthand constructors keep models readable at the call site.
pub fn equal(left : Int, right : Int) -> Constraint {
  Equal(left, right)
}

///|
/// Require two variables to take different values.
pub fn not_equal(left : Int, right : Int) -> Constraint {
  NotEqual(left, right)
}

///|
/// Require `left < right`.
pub fn less_than(left : Int, right : Int) -> Constraint {
  LessThan(left, right)
}

///|
/// Require `left <= right`.
pub fn less_equal(left : Int, right : Int) -> Constraint {
  LessEqual(left, right)
}

///|
/// Require `left >= right`.
pub fn greater_equal(left : Int, right : Int) -> Constraint {
  GreaterEqual(left, right)
}

///|
/// Require `left > right`.
pub fn greater_than(left : Int, right : Int) -> Constraint {
  GreaterThan(left, right)
}

///|
/// Require all listed variables to be pairwise different.
pub fn all_different(variables : Array[Int]) -> Constraint {
  AllDifferent(variables)
}

///|
/// Require the listed variables to add up to `target`.
pub fn sum(variables : Array[Int], target : Int) -> Constraint {
  Sum(variables, target)
}

///|
/// Constrain `result` to `table[index]`.
pub fn element(index : Int, table : Array[Int], result : Int) -> Constraint {
  Element(index, table, result)
}

///|
/// Require a weighted sum to equal `target`.
pub fn linear(terms : Array[(Int, Int)], target : Int) -> Constraint {
  Linear(terms, target)
}

///|
/// Require a weighted sum to be at most `target`.
pub fn linear_less_equal(terms : Array[(Int, Int)], target : Int) -> Constraint {
  LinearLessEqual(terms, target)
}

///|
/// Require a weighted sum to be at least `target`.
pub fn linear_greater_equal(
  terms : Array[(Int, Int)],
  target : Int,
) -> Constraint {
  LinearGreaterEqual(terms, target)
}

///|
/// Restrict a variable to an inclusive interval.
pub fn between(variable : Int, lower : Int, upper : Int) -> Constraint {
  Between(variable, lower, upper)
}

///|
/// Restrict a variable to an explicit finite set.
pub fn allowed_values(variable : Int, values : Array[Int]) -> Constraint {
  Member(variable, values)
}

///|
/// Require exactly `count` variables to take `value`.
pub fn count_value(
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Constraint {
  CountValue(variables, value, count)
}

///|
/// Require at most `count` variables to take `value`.
pub fn at_most_value(
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Constraint {
  AtMostValue(variables, value, count)
}

///|
/// Require at least `count` variables to take `value`.
pub fn at_least_value(
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Constraint {
  AtLeastValue(variables, value, count)
}

///|
/// Bind `result` to the minimum value in `variables`.
pub fn minimum(variables : Array[Int], result : Int) -> Constraint {
  Minimum(variables, result)
}

///|
/// Bind `result` to the maximum value in `variables`.
pub fn maximum(variables : Array[Int], result : Int) -> Constraint {
  Maximum(variables, result)
}

///|
/// Bind `result` to the absolute value of `source`.
pub fn absolute(source : Int, result : Int) -> Constraint {
  Absolute(source, result)
}

///|
/// Require the absolute distance between two variables to equal `distance`.
pub fn distance(left : Int, right : Int, distance : Int) -> Constraint {
  Distance(left, right, distance)
}

///|
/// Require two variables not to be at an exact absolute distance.
pub fn not_distance(left : Int, right : Int, distance : Int) -> Constraint {
  NotDistance(left, right, distance)
}

///|
/// Restrict a tuple of variables to rows in an extensional table.
pub fn table(variables : Array[Int], rows : Array[Array[Int]]) -> Constraint {
  Table(variables, rows)
}

///|
/// Require intervals `(start variable, duration)` not to overlap.
pub fn no_overlap(tasks : Array[(Int, Int)]) -> Constraint {
  NoOverlap(tasks)
}

///|
/// Limit the sum of active demands for interval tasks.
pub fn cumulative(tasks : Array[(Int, Int, Int)], capacity : Int) -> Constraint {
  Cumulative(tasks, capacity)
}

///|
/// A complete assignment returned by the solver.
pub struct Solution {
  values : Array[Int]
} derive(Debug, Eq)

///|
/// Read a variable's assigned value from a solution.
pub fn Solution::get(self : Solution, variable : Int) -> Int {
  self.values[variable]
}

///|
/// Return all assigned values in variable-id order.
pub fn Solution::values(self : Solution) -> Array[Int] {
  self.values.copy()
}

///|
/// Format a solution as `name=value` pairs using a model's variable names.
pub fn Solution::describe(
  self : Solution,
  variables : Array[Variable],
) -> String {
  let builder = StringBuilder()
  for id, variable in variables {
    if id > 0 {
      builder.write_string(", ")
    }
    builder.write_string(variable.name)
    builder.write_char('=')
    builder.write_string("\{self.values[id]}")
  }
  builder.to_string()
}
