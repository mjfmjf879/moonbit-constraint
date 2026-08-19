///|
test "linear propagation prunes exact sums" {
  let solver = new_solver()
  let left = solver.add_variable(variable("left", 0, 9))
  let right = solver.add_variable(variable("right", 0, 9))
  solver.add_constraint(linear([(left, 2), (right, 1)], 10))
  solver.limit(20)
  let solutions = solver.solve_all()
  assert_eq(solutions.length(), 5)
  assert_true(solver.stats().pruned_count() > 0)
  for solution in solutions {
    assert_true(solver.is_valid_solution(solution))
  }
}

///|
test "linear inequalities and counts handle partial assignments" {
  let solver = new_solver()
  let a = solver.add_variable(variable("a", 0, 5))
  let b = solver.add_variable(variable("b", 0, 5))
  let c = solver.add_variable(variable("c", 0, 5))
  solver.add_constraint(linear_less_equal([(a, 2), (b, 1)], 5))
  solver.add_constraint(linear_greater_equal([(b, 1), (c, 1)], 6))
  solver.add_constraint(count_value([a, b, c], 3, 1))
  match solver.solve() {
    Some(solution) => {
      assert_true(solver.is_valid_solution(solution))
      assert_eq(solution.get(a) * 2 + solution.get(b) <= 5, true)
      assert_eq(solution.get(b) + solution.get(c) >= 6, true)
    }
    None => fail("expected a feasible inequality model")
  }
}

///|
test "table propagation removes unsupported tuples" {
  let solver = new_solver()
  let a = solver.add_variable(variable("a", 0, 2))
  let b = solver.add_variable(variable("b", 0, 2))
  let c = solver.add_variable(variable("c", 0, 4))
  solver.add_constraint(
    table([a, b, c], [[0, 0, 0], [0, 1, 1], [1, 1, 2], [2, 2, 4]]),
  )
  assert_true(solver.assign(a, 2))
  assert_true(solver.assign(b, 2))
  match solver.solve() {
    Some(solution) => assert_eq(solution.get(c), 4)
    None => fail("expected the supported table row")
  }
}

///|
test "distance and negated distance are directional-safe" {
  let solver = new_solver()
  let left = solver.add_variable(variable("left", 0, 4))
  let right = solver.add_variable(variable("right", 0, 4))
  solver.add_constraint(distance(left, right, 2))
  assert_true(solver.assign(left, 1))
  solver.limit(10)
  let solutions = solver.solve_all()
  assert_eq(solutions.length(), 1)
  for solution in solutions {
    assert_true(solver.is_valid_solution(solution))
  }
  let forbidden = new_solver()
  let x = forbidden.add_variable(variable("x", 0, 0))
  let y = forbidden.add_variable(variable("y", 0, 0))
  forbidden.add_constraint(not_distance(x, y, 0))
  assert_eq(forbidden.solve(), None)
}

///|
test "all-different, absolute and min max constraints" {
  let solver = new_solver()
  let a = solver.add_variable(variable("a", -3, 3))
  let b = solver.add_variable(variable("b", -3, 3))
  let minimum_id = solver.add_variable(variable("minimum", -3, 3))
  let maximum_id = solver.add_variable(variable("maximum", 0, 3))
  let absolute_id = solver.add_variable(variable("absolute", 0, 3))
  solver.add_constraint(all_different([a, b]))
  solver.add_constraint(minimum([a, b], minimum_id))
  solver.add_constraint(maximum([a, b], maximum_id))
  solver.add_constraint(absolute(a, absolute_id))
  match solver.solve() {
    Some(solution) => {
      assert_true(solver.is_valid_solution(solution))
      assert_eq(
        solution.get(absolute_id),
        if solution.get(a) < 0 {
          -solution.get(a)
        } else {
          solution.get(a)
        },
      )
    }
    None => fail("expected a min/max assignment")
  }
}

///|
test "no-overlap and cumulative reject invalid fixed schedules" {
  let overlap = new_solver()
  let first = overlap.add_variable(variable("first", 0, 0))
  let second = overlap.add_variable(variable("second", 0, 0))
  overlap.add_constraint(no_overlap([(first, 2), (second, 1)]))
  assert_eq(overlap.solve(), None)
  let capacity = new_solver()
  let a = capacity.add_variable(variable("a", 0, 0))
  let b = capacity.add_variable(variable("b", 0, 0))
  capacity.add_constraint(cumulative([(a, 2, 2), (b, 2, 1)], 2))
  assert_eq(capacity.solve(), None)
}

///|
test "model builder names and diagnostics remain stable" {
  let model = new_model()
  let left = model.int("left", 1, 3)
  let right = model.int("right", 1, 3)
  model.post_equal("left", "right")
  model.post(linear([(left, 1), (right, 1)], 4))
  assert_eq(model.find("left"), Some(left))
  assert_eq(model.find("missing"), None)
  match model.solve() {
    Some(solution) => {
      assert_eq(model.named_solution(solution)["left"], 2)
      assert_true(model.solver().ready())
      assert_true(model.solver().diagnostic_report().length() > 0)
    }
    None => fail("expected named model solution")
  }
}

///|
test "guarded solve distinguishes budgets and structural limits" {
  let solver = new_solver()
  let a = solver.add_variable(variable("a", 0, 20))
  let b = solver.add_variable(variable("b", 0, 20))
  solver.add_constraint(not_equal(a, b))
  let limited = solver.guarded_solve(model_limits(1, 20, 100), 10)
  assert_true(limited.was_rejected())
  let budgeted = solver.guarded_solve(default_model_limits(), 1)
  assert_true(budgeted.was_budget_limited() || budgeted.is_success())
  assert_true(budgeted.describe().length() > 0)
}

///|
test "optimization returns the best enumerated objective" {
  let solver = new_solver()
  let x = solver.add_variable(variable("x", 0, 4))
  let y = solver.add_variable(variable("y", 0, 4))
  solver.add_constraint(sum([x, y], 4))
  match solver.optimize(x, maximize()) {
    Some(result) => assert_eq(result.objective(), 4)
    None => fail("expected an optimization result")
  }
}
