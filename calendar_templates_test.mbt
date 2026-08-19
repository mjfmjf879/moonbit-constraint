///|
test "calendar tasks honor duration, precedence and deadlines" {
  let model = calendar_model(8, 1).unwrap()
  let first = model.add_task("build", 2, 0).unwrap()
  let second = model.add_task("test", 3, 0).unwrap()
  ignore(model.fix_start(first, 0))
  model.post_precedence(first, second, 1)
  model.post_deadline(second, 8)
  model.post_resource_non_overlap(0)
  let solution = model.solve().unwrap()
  assert_true(model.is_valid(solution))
  assert_eq(model.start_of(solution, first), 0)
  assert_eq(model.end_of(solution, first), 2)
  assert_true(model.start_of(solution, second) >= 3)
  assert_eq(
    model.end_of(solution, second),
    model.start_of(solution, second) + 3,
  )
  assert_eq(model.makespan(solution), model.end_of(solution, second))
  assert_true(model.render(solution).contains("build"))
}

///|
test "calendar resource capacities and windows are reusable" {
  let model = calendar_model(6, 2).unwrap()
  let first = model.add_task("a", 2, 0).unwrap()
  let second = model.add_task("b", 2, 0).unwrap()
  let third = model.add_task("c", 1, 1).unwrap()
  model.post_start_window(first, 0, 2)
  model.post_start_window(second, 2, 4)
  model.post_allowed_starts(third, [0, 1, 2])
  model.post_resource_capacity(0, 1)
  let solution = model.solve().unwrap()
  assert_true(model.is_valid(solution))
  assert_true(
    model.end_of(solution, first) <= model.start_of(solution, second) ||
    model.end_of(solution, second) <= model.start_of(solution, first),
  )
  assert_eq(model.summary(solution).tasks(), 3)
  assert_eq(model.summary(solution).occupied(), 5)
}

///|
test "calendar constructors reject impossible task shapes" {
  assert_true(calendar_model(0, 1) is None)
  assert_true(calendar_model(3, 0) is None)
  let model = calendar_model(3, 1).unwrap()
  assert_true(model.add_task("too_long", 4, 0) is None)
  assert_true(model.add_task("bad_resource", 1, 1) is None)
  assert_true(calendar_chain([], 4) is None)
  let chain = calendar_chain([1, 2, 1], 6).unwrap()
  let solution = chain.solve().unwrap()
  assert_true(chain.is_valid(solution))
  assert_eq(chain.summary(solution).tasks(), 3)
}
