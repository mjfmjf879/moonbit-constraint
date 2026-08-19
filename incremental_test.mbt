///|
test "assumption sets reject duplicate variables and describe decisions" {
  let set = assumptions()
  assert_true(set.add_value(0, 2))
  assert_true(!set.add_value(0, 3))
  assert_eq(set.length(), 1)
  assert_true(set.contains(0, 2))
  assert_eq(set.get(1), None)
  assert_eq(set.describe(), "[v0=2]")
}

///|
test "incremental probes restore model domains" {
  let solver = new_solver()
  let left = solver.add_variable(variable("left", 1, 3))
  let right = solver.add_variable(variable("right", 1, 3))
  solver.add_constraint(sum([left, right], 4))
  let before = solver.snapshot()
  let set = assumptions()
  ignore(set.add_value(left, 1))
  let result = solver.solve_with_assumptions(set)
  assert_true(result.satisfiable())
  assert_eq(result.solution().unwrap().values(), [1, 3])
  assert_true(snapshots_equal(before, solver.snapshot()))
  assert_eq(solver.domain_of(left).values(), [1, 2, 3])
}

///|
test "inconsistent assumptions produce a minimal conflict core" {
  let solver = new_solver()
  let value = solver.add_variable(variable("value", 0, 1))
  solver.add_constraint(between(value, 1, 1))
  let set = assumptions()
  ignore(set.add_value(value, 0))
  let report = solver.explain_assumptions(set)
  assert_true(report.satisfiable() == false)
  assert_eq(report.core().length(), 1)
  let invalid = assumptions()
  ignore(invalid.add_value(value, 2))
  let invalid_report = solver.explain_assumptions(invalid)
  assert_true(!invalid_report.satisfiable())
  assert_eq(invalid_report.core().length(), 1)
}

///|
test "snapshot assumptions and domain deltas are reversible" {
  let solver = new_solver()
  let first = solver.add_variable(variable("first", 0, 2))
  let second = solver.add_variable(variable("second", 0, 2))
  ignore(solver.assign(first, 1))
  let snapshot = solver.snapshot()
  assert_eq(snapshot_assumptions(snapshot).length(), 1)
  let set = assumptions()
  ignore(set.add_value(second, 2))
  let narrowed = snapshot_assume(snapshot, set).unwrap()
  let deltas = snapshot_deltas(snapshot, narrowed)
  assert_eq(deltas.length(), 1)
  assert_eq(deltas[0].variable(), second)
  assert_eq(deltas[0].after().values(), [2])
}

///|
test "decision traces and probe batches aggregate stable counters" {
  let trace = decision_trace()
  trace.record(decision_step(0, 1, true, 0))
  trace.record(decision_step(1, 2, false, 1))
  assert_eq(trace.length(), 2)
  assert_eq(trace.accepted_count(), 1)
  assert_eq(trace.rejected_count(), 1)
  assert_eq(trace.maximum_depth(), 1)
  let solver = new_solver()
  let variable_id = solver.add_variable(variable("x", 0, 1))
  let batch = probe_batch()
  let sat = assumptions()
  ignore(sat.add_value(variable_id, 1))
  let unsat = assumptions()
  ignore(unsat.add_value(variable_id, 2))
  ignore(solver.probe(batch, sat))
  ignore(solver.probe(batch, unsat))
  assert_eq(batch.length(), 2)
  assert_eq(batch.satisfiable_count(), 1)
  assert_eq(batch.unsatisfiable_count(), 1)
}
