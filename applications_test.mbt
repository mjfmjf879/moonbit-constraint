///|
test "classic Sudoku solves and renders a valid board" {
  let problem = classic_sudoku().unwrap()
  let solution = problem.solve().unwrap()
  assert_true(problem.is_valid(solution))
  assert_eq(problem.compact(solution), classic_solution_string())
  assert_true(problem.render(solution).contains("------+-------+------"))
}

///|
test "Sudoku parser rejects malformed and contradictory puzzles" {
  assert_true(sudoku("0") is None)
  assert_true(sudoku("x") is None)
  let builder = StringBuilder()
  builder.write_string("11")
  for _ in 0..<79 {
    builder.write_char('.')
  }
  let contradictory = builder.to_string()
  assert_true(sudoku(contradictory).unwrap().solve() is None)
}

///|
test "N queens and graph coloring provide real application models" {
  let queens = n_queens(4).unwrap()
  let queen_solution = queens.solve().unwrap()
  assert_true(queens.is_valid(queen_solution))
  assert_eq(queens.solve_all(10).length(), 2)
  let graph = complete_coloring(4).unwrap()
  let coloring = graph.solve().unwrap()
  assert_true(graph.is_valid(coloring))
  assert_eq(graph.colors(coloring).length(), 4)
}

///|
test "schedule model balances workers and renders assignments" {
  let problem = balanced_schedule(3, 3, 2).unwrap()
  ignore(problem.avoid_same_shift(0))
  let solution = problem.solve().unwrap()
  assert_true(problem.is_complete(solution))
  let rows = problem.assignments(solution)
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].length(), 2)
  assert_true(problem.render(solution).contains("day 0"))
}

///|
test "resource schedule enforces non-overlap" {
  let schedule = resource_schedule(6, 1).unwrap()
  let first = schedule.add_task("build", 2, 1, 4).unwrap()
  let second = schedule.add_task("test", 2, 1, 4).unwrap()
  ignore(schedule.fix_start(first, 0))
  ignore(schedule.fix_start(second, 2))
  let solution = schedule.solve().unwrap()
  assert_true(schedule.is_valid(solution))
  assert_eq(schedule.load_profile(solution), [1, 1, 1, 1, 0, 0])
  assert_true(schedule.render(solution).contains("build"))
}

///|
test "knapsack and assignment optimize real objectives" {
  let bag = knapsack(["a", "b", "c"], [2, 3, 4], [4, 5, 8], 5).unwrap()
  let bag_result = bag.solve().unwrap()
  assert_eq(bag_result.objective(), 9)
  assert_true(bag.is_valid(bag_result.solution()))
  let assignment = assignment_problem(2, 2, [[4, 1], [2, 3]]).unwrap()
  let assignment_result = assignment.solve().unwrap()
  assert_eq(assignment_result.objective(), 3)
  assert_true(assignment.is_valid(assignment_result.solution()))
}

///|
test "set covering and bin packing respect capacities" {
  let covering = set_covering(4, [[0, 1], [1, 2], [2, 3], [0, 3]], [2, 2, 2, 2]).unwrap()
  let cover_result = covering.solve().unwrap()
  assert_eq(cover_result.objective(), 4)
  let packing = bin_packing([2, 3, 2], 2, 5).unwrap()
  let packing_solution = packing.solve().unwrap()
  assert_true(packing.is_valid(packing_solution))
  assert_eq(packing.loads(packing_solution).length(), 2)
}

///|
test "Latin and magic square models have structural validity" {
  let latin = latin_square(3).unwrap()
  latin.fix_first_row()
  let latin_solution = latin.solve().unwrap()
  assert_true(latin.is_valid(latin_solution))
  let magic = magic_square(3).unwrap()
  let magic_solution = magic.solve().unwrap()
  assert_true(magic.is_valid(magic_solution))
  assert_eq(magic.target(), 15)
}

///|
test "Boolean circuit and finite arithmetic tables compose" {
  let circuit = boolean_circuit()
  let left = circuit.input("left")
  let right = circuit.input("right")
  let conjunction = circuit.and_gate(left, right)
  let one = circuit.constant("one", 1)
  circuit.solver.add_constraint(equal(conjunction, one))
  let solution = circuit.solve().unwrap()
  assert_eq(circuit.output_values(solution), [1])
  let solver = new_solver()
  let a = solver.add_variable(variable("a", 1, 2))
  let b = solver.add_variable(variable("b", 1, 2))
  let c = solver.add_variable(variable("c", 1, 4))
  post_addition(solver, a, b, c, domain(1, 2), domain(1, 2))
  assert_true(solver.solve() is Some(_))
}

///|
test "benchmark suite produces deterministic successful cases" {
  let results = benchmark_suite()
  assert_eq(results.length(), 6)
  assert_true(benchmarks_pass(results))
  assert_true(benchmark_work(results) > 0)
  assert_true(benchmark_report(results).contains("nqueens_8"))
  assert_true(benchmark_markdown(results).contains("| Case |"))
  assert_true(benchmark_fingerprint(results).length() > 10)
}
