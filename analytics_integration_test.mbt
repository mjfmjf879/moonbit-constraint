///|
test "assignment and sequence analytics expose stable operational summaries" {
  let assignments = [0, 0, 1, 2, 2, 1]
  assert_eq(assignment_counts(assignments, 3), [2, 2, 2])
  assert_eq(assignment_transitions(assignments), 3)
  assert_eq(assignment_changes([0, 1, 1], [0, 2, 1]), 1)
  assert_eq(assignment_imbalance(assignments, 3), 0)
  let metrics = assignment_metrics(assignments, 3, [0, 1, 1, 2, 2, 1])
  assert_eq(metrics.count(), 6)
  assert_eq(metrics.categories(), 3)
  assert_eq(metrics.changes(), 1)
  assert_eq(longest_assignment_run(assignments), 2)
  assert_eq(missing_assignment_categories([0, 2], 4), [1, 3])

  assert_eq(sequence_run_lengths(assignments), [2, 1, 2, 1])
  assert_eq(sequence_cumulative([2, -1, 3]), [2, 1, 4])
  assert_eq(sequence_delta([2, 5, 1]), [0, 3, -4])
  assert_eq(sequence_lcs_length([1, 2, 3], [1, 3]), 2)
  assert_eq(sequence_edit_distance([1, 2, 3], [1, 4, 3]), 1)
  assert_true(sequence_contains([1, 2, 3, 4], [2, 3]))
  assert_true(sequence_report(assignments).describe().length() > 0)
}

///|
test "calendar windows merge, clip, and expose capacity gaps" {
  let windows = [
    calendar_window(1, 4),
    calendar_window(3, 6),
    calendar_window(8, 10),
  ]
  assert_eq(calendar_covered_duration(windows), 7)
  assert_eq(calendar_gap_duration(windows), 2)
  assert_eq(calendar_peak_concurrency(windows), 2)
  assert_true(!calendar_non_overlapping(windows))
  assert_eq(merge_calendar_windows(windows).length(), 2)
  assert_eq(calendar_clip(windows, 2, 9).length(), 3)
  assert_eq(calendar_first_free(windows, 0, 2), 6)
  assert_eq(free_slot_duration(windows, calendar_slots(0, 10, 1)), 3)
  assert_true(calendar_summary(windows).length() > 0)
}

///|
test "sets, relations, and domain catalogs support finite-model preprocessing" {
  let left = integer_set([3, 1, 1, 2])
  let right = integer_set([2, 3, 4])
  assert_eq(left.values(), [1, 2, 3])
  assert_eq(left.intersection(right).values(), [2, 3])
  assert_eq(left.union(right).values(), [1, 2, 3, 4])
  assert_eq(left.difference(right).values(), [1])
  assert_true(left.contiguous())

  let relation = finite_relation(3, 3)
  assert_true(relation.add(0, 1))
  assert_true(relation.add(1, 2))
  assert_true(!relation.add(3, 0))
  assert_eq(relation.image(0).values(), [1])
  assert_eq(relation.inverse().image(2).values(), [1])
  assert_true(!relation.total())

  let catalog = domain_catalog()
  assert_eq(catalog.add("worker", domain(1, 3), "resource"), Some(0))
  assert_eq(catalog.add("shift", domain_from_values([1, 3]), "time"), Some(1))
  assert_eq(catalog.add("worker", domain(0, 1), "duplicate"), None)
  assert_eq(catalog.names(), ["worker", "shift"])
  assert_eq(catalog.sizes(), [3, 2])
  assert_eq(catalog.cartesian_size(100), 6)
  assert_eq(catalog.with_tag("resource").length(), 1)
  assert_true(catalog.consistent())
}

///|
test "service and benchmark evidence detects late work and regressions" {
  let observations = [
    service_observation(0, 10, 8, 5, 3),
    service_observation(1, 10, 12, 4, 3),
    service_observation(2, 12, 12, 2, 3),
  ]
  let metrics = service_metrics(observations)
  assert_eq(metrics.on_time_percent(), 66)
  assert_eq(metrics.late_percent(), 33)
  assert_eq(metrics.average_lateness(), 0)
  assert_eq(late_observations(observations), [1])
  assert_true(!metrics.meets_target(90))

  let baseline = benchmark_artifact_suite("baseline")
  assert_true(baseline.add(artifact_benchmark("routing", 100, true, 11)))
  assert_true(baseline.add(artifact_benchmark("schedule", 80, true, 12)))
  let candidate = benchmark_artifact_suite("candidate")
  assert_true(candidate.add(artifact_benchmark("routing", 130, true, 21)))
  assert_true(candidate.add(artifact_benchmark("schedule", 75, true, 22)))
  assert_true(!candidate.add(artifact_benchmark("schedule", 75, true, 22)))
  assert_eq(candidate.total_work(), 205)
  assert_true(candidate.all_solved())
  assert_true(candidate.unique_signatures())
  assert_eq(benchmark_regressions(baseline, candidate, 20), ["routing"])
  assert_true(candidate.markdown().length() > 0)
}

///|
test "event queues and scenario library remain deterministic at boundaries" {
  let queue = event_queue()
  assert_true(queue.push(simulation_event(5, 1, 0, 0, custom_event_kind(), 10)))
  assert_true(queue.push(simulation_event(2, 2, 1, 0, custom_event_kind(), 20)))
  assert_eq(queue.length(), 2)
  assert_eq(queue.peek().unwrap().kind_name(), "custom")
  assert_eq(queue.pop().unwrap().kind_name(), "custom")
  assert_eq(queue.length(), 1)
  queue.clear()
  assert_true(queue.pop() is None)

  assert_eq(scenario_suite().length(), 6)
  assert_true(scenarios_pass(10))
  assert_true(!scenarios_pass(1))
  assert_true(scenario_report(10).length() > 0)
  assert_true(workflow_chain(4) is Some(_))
  assert_true(feature_selection(5, 2) is Some(_))
  assert_true(feature_selection(2, 3) is None)
}

///|
test "constraint recipes build a solvable finite-domain workflow" {
  let builder = constraint_builder()
  let first = builder.add_int("first", 0, 3)
  let second = builder.add_int("second", 0, 3)
  let third = builder.add_int("third", 0, 3)
  let recipe = constraint_recipe(builder)
  assert_true(recipe.post_all_different([first, second, third]))
  assert_true(recipe.post_exact_sum([first, second, third], 6))
  assert_true(recipe.post_chain([first, second, third]))
  assert_true(recipe.post_fix(first, 1))
  assert_true(recipe.valid())
  let solution = recipe.solve().unwrap()
  assert_eq(solution.get(first), 1)
  assert_eq(solution.get(second), 2)
  assert_eq(solution.get(third), 3)
  assert_eq(recipe.result().posted(), 4)

  let set = strong_all_different([first, second, third])
  assert_eq(set.length(), 4)
  assert_true(set.report().describe().length() > 0)
}

///|
test "manufacturing dispatch produces a feasible shop-floor schedule" {
  let instance = manufacturing_instance(
    [machine_spec(0, "cut", 1), machine_spec(1, "assemble", 1)],
    [
      manufacturing_operation(0, 0, 0, 0, 1, 3, 0, 20),
      manufacturing_operation(1, 0, 1, 1, 1, 2, 1, 20),
      manufacturing_operation(2, 1, 0, 0, 0, 2, 0, 20),
    ],
    [[0, 1], [1, 0]],
  ).unwrap()
  let schedule = dispatch_schedule(instance)
  assert_true(manufacturing_feasible(instance, schedule))
  assert_eq(validate_manufacturing_schedule(instance, schedule), [])
  assert_eq(manufacturing_jobs(instance), [0, 1])
  assert_eq(instance.operation_count(), 3)
  assert_eq(instance.machine_count(), 2)
  assert_true(manufacturing_makespan(instance, schedule) > 0)
  assert_eq(machine_busy_time(instance, schedule, 0), 6)
  assert_true(machine_utilization(instance, schedule, 0) > 0)
  assert_true(manufacturing_render(instance, schedule).length() > 0)
}

///|
test "schema and text adapters validate external configuration data" {
  let schema = model_schema("dispatch")
  assert_true(schema.add(schema_field(0, "workers", 1, 5, 2)))
  assert_true(schema.add(schema_field(1, "shift", 0, 2, 1)))
  assert_true(!schema.add(schema_field(2, "shift", 0, 2, 1)))
  assert_eq(schema.defaults(), [2, 1])
  assert_eq(schema.names(), ["workers", "shift"])
  assert_true(schema.validate([4, 2]).valid())
  assert_true(!schema.validate([0, 2]).valid())
  assert_eq(schema.cartesian_size(100), 15)
  assert_true(schema.csv().length() > 0)

  let document = text_document("workers=4\n# ignored\nshift=2")
  assert_eq(document.line_count(), 3)
  assert_eq(document.without_comments("#").length(), 2)
  let pairs = parse_key_values("workers=4\nshift=2")
  assert_eq(key_value(pairs, "shift"), Some("2"))
  assert_eq(integer_tokens("4 2 -1"), [4, 2, -1])
  assert_eq(parse_csv("name,value\nworkers,4").length(), 2)
  assert_true(lines_within_width("small\nmodel", 5))
  assert_eq(longest_line("small\nmodel-data"), 10)
}

///|
test "optimization and resource metrics compare practical alternatives" {
  let items = [
    utility_item(0, 2, 8),
    utility_item(1, 3, 9),
    utility_item(2, 1, 3),
  ]
  let selected = greedy_utility_subset(items, 4)
  assert_true(validate_utility_subset(items, selected, 4))
  assert_true(utility_subset_weight(items, selected) <= 4)
  assert_true(utility_subset_value(items, selected) >= 11)
  let preferred = integer_objective([4, 10], [
    portfolio_direction(true),
    portfolio_direction(false),
  ])
  let other = integer_objective([5, 9], [
    portfolio_direction(true),
    portfolio_direction(false),
  ])
  assert_true(preferred.dominates(other))
  assert_eq(preferred.compare(other), -1)
  assert_eq(normalize_objective(5, 0, 10), 500)

  let metrics = [
    resource_metric(0, 4, [0, 2, 4, 3]),
    resource_metric(1, 2, [1, 3, 2, 0]),
  ]
  assert_eq(metrics[0].peak_percent(), 100)
  assert_true(metrics[1].overloaded())
  assert_eq(overloaded_resources(metrics), [1])
  assert_eq(bottleneck_order(metrics)[0], 1)
  assert_true(!within_resource_limit(metrics, 100))
  assert_true(resource_metrics_report(metrics).length() > 0)
}
