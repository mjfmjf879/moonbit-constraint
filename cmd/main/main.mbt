///|
fn main {
  let solver = @constraint.new_solver()
  let first = solver.add_variable(@constraint.variable("first", 1, 9))
  let second = solver.add_variable(@constraint.variable("second", 1, 9))
  solver.add_constraint(@constraint.sum([first, second], 10))
  match solver.solve() {
    Some(solution) => println("solution: \{Repr(solution.values)}")
    None => println("no solution")
  }
}
