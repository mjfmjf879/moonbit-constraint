///|
test "roster coverage and rotation are real reusable models" {
  let model = roster_model(2, 2, 2).unwrap()
  model.post_daily_cover([[1, 1], [1, 1]])
  model.post_no_consecutive_shift(0)
  model.post_no_consecutive_shift(1)
  let solution = model.solve().unwrap()
  assert_true(model.is_valid(solution))
  assert_eq(model.coverage(solution), [[1, 1], [1, 1]])
  assert_eq(model.worker_values(solution, 0).length(), 2)
  assert_eq(model.render(solution).contains("worker 0:"), true)
  assert_eq(model.score(solution).coverage_total(), 4)
  assert_eq(model.fingerprint(solution).contains(";"), true)
}

///|
test "roster bounds and pair constraints cover edge cases" {
  assert_true(roster_model(0, 2, 2) is None)
  assert_true(roster_model(2, 0, 2) is None)
  let model = two_shift_roster(4, 2, 2).unwrap()
  model.post_worker_shift_bounds(0, 0, 1, 2)
  model.post_worker_interval(1, 0, 0, 0, 2)
  model.post_pair_different(0, 1)
  let solution = model.solve().unwrap()
  assert_true(model.is_valid(solution))
  assert_eq(model.shift_count_for(solution, 0, 0), 2)
}

///|
test "rotating roster fixes deterministic assignments" {
  let model = rotating_roster(3, 3).unwrap()
  let solution = model.solve().unwrap()
  assert_eq(model.values(solution), [[0, 1, 2], [1, 2, 0], [2, 0, 1]])
  assert_eq(model.workload_spread(solution), 0)
}
