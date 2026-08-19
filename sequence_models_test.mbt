///|
test "sequence model supports sums, transitions and rendering" {
  let model = sequence_model(3, 0, 2).unwrap()
  model.post_sum(3)
  model.post_no_adjacent_equal()
  model.post_transitions([[0, 1], [1, 0], [1, 2], [2, 1]])
  ignore(model.fix(0, 0))
  let solution = model.solve().unwrap()
  assert_true(model.is_valid(solution))
  assert_eq(model.values_of(solution), [0, 1, 2])
  assert_eq(model.render(solution), "0 1 2")
  assert_eq(model.fingerprint(solution), "0,1,2")
}

///|
test "sequence windows and run limits prune boundary cases" {
  let model = sequence_model(4, 0, 1).unwrap()
  model.post_window_count(2, 1, 1)
  model.post_run_limit(1)
  assert_true(model.solve() is Some(_))
  let binary = binary_sequence(4, 2).unwrap()
  binary.post_no_adjacent_equal()
  assert_eq(binary.solve_all(10).length(), 2)
}

///|
test "sequence helpers reject invalid bounds and summarize values" {
  assert_true(sequence_model(0, 0, 1) is None)
  assert_true(sequence_model(2, 3, 1) is None)
  assert_true(quota_sequence(3, 0, 2, 20, 1).unwrap().solve() is None)
  assert_eq(parse_integer_sequence("-2 0 4"), Some([-2, 0, 4]))
  assert_eq(parse_integer_sequence("1 x"), None)
  let summary = sequence_summary([1, 1, 2, 0]).unwrap()
  assert_eq(summary.total(), 4)
  assert_eq(summary.minimum(), 0)
  assert_eq(summary.maximum(), 2)
  assert_eq(summary.changes(), 2)
  assert_eq(summary.runs(), 3)
  assert_eq(sequence_summary([]), None)
}

///|
test "alternating binary sequence and quota constraints are usable" {
  let alternating = alternating_binary_sequence(5).unwrap()
  let solution = alternating.solve().unwrap()
  let values = alternating.values_of(solution)
  assert_eq(values.length(), 5)
  assert_true(values[0] != values[1])
  assert_true(values[1] != values[2])
  let quota = quota_sequence(4, 0, 2, 4, 2).unwrap()
  quota.post_sum_between(3, 5)
  assert_true(quota.solve() is Some(_))
}
