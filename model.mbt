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
/// A complete assignment returned by the solver.
pub struct Solution {
  values : Array[Int]
} derive(Debug)

///|
/// Read a variable's assigned value from a solution.
pub fn Solution::get(self : Solution, variable : Int) -> Int {
  self.values[variable]
}
