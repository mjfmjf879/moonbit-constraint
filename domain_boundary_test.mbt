///|
test "domain handles negative ranges and holes" {
  let values = domain(-3, 3)
  assert_true(values.contains(-3))
  assert_true(values.contains(3))
  assert_true(values.remove(-3))
  assert_true(values.remove(0))
  assert_true(values.remove(3))
  assert_true(values.next(-10) is Some(-2))
  assert_true(values.previous(10) is Some(2))
  debug_inspect(
    values.intervals(),
    content="[{ lower: -2, upper: -1 }, { lower: 1, upper: 2 }]",
  )
  assert_eq(values.rank(1), Some(2))
  assert_eq(values.nth(3), Some(2))
  assert_eq(values.nth(4), None)
}

///|
test "domain assignment and exhaustion" {
  let values = domain_from_values([5, 2, 5, 9])
  assert_eq(values.values(), [2, 5, 9])
  assert_true(values.assign(5))
  assert_true(values.is_singleton())
  assert_eq(values.singleton(), Some(5))
  assert_true(values.remove(5))
  assert_true(values.is_empty())
  assert_true(values.remove_below(5) == false)
  assert_true(values.remove_above(5) == false)
}

///|
test "domain set arithmetic preserves finite values" {
  let left = domain_from_values([1, 2, 4])
  let right = domain_from_values([2, 3, 4])
  assert_eq(domain_intersection(left, right).unwrap().values(), [2, 4])
  assert_eq(domain_union(left, right).values(), [1, 2, 3, 4])
  assert_eq(domain_difference(left, right).unwrap().values(), [1])
  assert_eq(domain_add(left, right).unwrap().values(), [3, 4, 5, 6, 7, 8])
  assert_eq(domain_subtract(left, right).unwrap().values(), [
    -3, -2, -1, 0, 1, 2,
  ])
}

///|
test "domain range intersections and profiles" {
  let values = domain(0, 10)
  assert_true(values.intersect_range(3, 7))
  assert_eq(values.values(), [3, 4, 5, 6, 7])
  assert_true(values.intersect_values([3, 5, 7]))
  assert_eq(values.compact(), "{3, 5, 7}")
  let profile = values.profile()
  assert_eq(profile.size(), 3)
  assert_eq(profile.interval_count(), 3)
  assert_true(values.contains_all(domain_from_values([3, 7])))
}

///|
test "domain parser accepts signed lists" {
  assert_eq(parse_integer_list("-2, 0, 4"), Some([-2, 0, 4]))
  assert_eq(parse_integer_list("1,,x"), None)
  assert_eq(parse_domain("2,4,6").unwrap().compact(), "{2, 4, 6}")
}

///|
test "interval helpers cover touching and disjoint segments" {
  let left = domain_interval(1, 3)
  let touching = domain_interval(4, 6)
  let disjoint = domain_interval(8, 9)
  assert_true(left.touches(touching))
  assert_true(!left.touches(disjoint))
  assert_eq(left.intersect(touching), None)
  assert_eq(left.intersect(domain_interval(2, 5)).unwrap().describe(), "2..3")
}
