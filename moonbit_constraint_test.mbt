///|
test "domain operations" {
  let values = domain(1, 4)
  debug_inspect(values.values(), content="[1, 2, 3, 4]")
  ignore(values.remove(2))
  debug_inspect(values.values(), content="[1, 3, 4]")
  inspect(values.size(), content="3")
}

///|
test "all different and mrv search" {
  let solver = new_solver()
  let a = solver.add_variable(variable("a", 1, 3))
  let b = solver.add_variable(variable("b", 1, 3))
  let c = solver.add_variable(variable("c", 1, 3))
  solver.add_constraint(all_different([a, b, c]))
  solver.limit(6)
  let solutions = solver.solve_all()
  debug_inspect(solutions.length(), content="6")
  debug_inspect(solutions[0].values, content="[1, 2, 3]")
}

///|
test "arithmetic and element constraints" {
  let solver = new_solver()
  let x = solver.add_variable(variable("x", 0, 4))
  let y = solver.add_variable(variable("y", 0, 4))
  let result = solver.add_variable(variable("result", 10, 20))
  solver.add_constraint(equal(x, y))
  solver.add_constraint(sum([x, y], 4))
  solver.add_constraint(element(x, [10, 11, 12, 13, 14], result))
  match solver.solve() {
    Some(solution) => {
      debug_inspect(solution.get(x), content="2")
      debug_inspect(solution.get(result), content="12")
    }
    None => fail("expected a solution")
  }
}

///|
test "unsatisfiable model" {
  let solver = new_solver()
  let x = solver.add_variable(variable("x", 1, 2))
  let y = solver.add_variable(variable("y", 1, 2))
  solver.add_constraint(equal(x, y))
  solver.add_constraint(not_equal(x, y))
  solver.add_constraint(greater_than(x, 0))
  debug_inspect(solver.solve(), content="None")
}
