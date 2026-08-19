///|
test "routing validates a generated plan and boundary inputs" {
  assert_true(routing_instance([], 0, [5]) is None)
  let points = [
    routing_point(0, 0, 0, 0),
    routing_point(1, 2, 0, 2),
    routing_point(2, 2, 2, 3),
  ]
  let instance = routing_instance(points, 0, [8]).unwrap()
  let plan = nearest_neighbor_plan(instance)
  assert_eq(validate_plan(instance, plan), [])
  assert_eq(unserved_count(instance, plan), 0)
  assert_true(route_load(instance, plan.route(0)) <= instance.capacity(0))
  assert_true(plan_distance(instance, plan) >= 0)
}

///|
test "graph shortest path topology and maximum flow" {
  let graph = weighted_graph_from_edges(4, true, [
    graph_edge(0, 1, 2),
    graph_edge(1, 2, 1),
    graph_edge(0, 2, 8),
    graph_edge(2, 3, 2),
  ]).unwrap()
  assert_true(graph.has_edge(0, 1))
  assert_eq(graph.shortest_path(0, 3), Some([0, 1, 2, 3]))
  assert_true(graph.topological_order() is Some(_))
  assert_true(!graph.has_directed_cycle())
  assert_eq(graph.maximum_flow(0, 3), 2)
  assert_eq(graph.shortest_path(-1, 3), None)
}

///|
test "project planning exposes critical path and cycle boundaries" {
  let tasks = [
    planning_task(0, "prepare", 2, 0, 1),
    planning_task(1, "build", 3, 0, 1),
  ]
  let plan = project_plan(tasks, 10, [1]).unwrap()
  assert_true(plan.add_dependency(0, 1, 0))
  assert_true(!plan.has_cycle())
  assert_eq(plan.earliest_starts(), [0, 2])
  assert_eq(plan.critical_path_length(), 5)
  assert_true(plan.add_dependency(1, 0, 0))
  assert_true(plan.has_cycle())
  assert_true(plan.topological_order() is None)
}

///|
test "allocation respects capacity and group limits" {
  let instance = allocation_instance(
    [
      allocation_item(0, 2, 10, 1),
      allocation_item(1, 3, 5, 2),
      allocation_item(2, 1, 8, 1),
    ],
    [5, 5],
  ).unwrap()
  assert_true(instance.add_group_limit(0, 1, 1, 1))
  let plan = allocation_plan(instance)
  assert_true(plan.assign(0, 0))
  assert_true(plan.assign(1, 0))
  assert_true(plan.assign(2, 1))
  assert_eq(validate_allocation(instance, plan), [])
  assert_eq(allocation_loads(instance, plan), [5, 1])
  assert_eq(total_allocated_value(instance, plan), 23)
  assert_true(allocation_feasible(instance, plan))
}

///|
test "timeline uses half-open intervals and reports overloads" {
  let timeline = resource_timeline(10, [2]).unwrap()
  assert_true(timeline.add(timeline_interval(0, 0, 0, 3, 1, "first")))
  assert_true(timeline.add(timeline_interval(1, 0, 3, 5, 1, "touching")))
  assert_eq(timeline.load_at(0, 3), 1)
  assert_true(timeline.feasible())
  assert_true(timeline.add(timeline_interval(2, 0, 2, 4, 2, "overlap")))
  assert_true(!timeline.feasible())
  assert_true(
    timeline_overlap(
      timeline_interval(0, 0, 0, 3, 1, ""),
      timeline_interval(1, 0, 3, 5, 1, ""),
    ) ==
    false,
  )
  assert_true(timeline.find_slot(0, 2) is Some(_))
}

///|
test "matrix and integer statistics cover empty and shaped data" {
  assert_eq(int_matrix(0, 2).row_count(), 0)
  let matrix = int_matrix_from_values(2, 2, [1, 2, 3, 4]).unwrap()
  assert_eq(matrix.transpose().row(0), [1, 3])
  assert_eq(matrix.trace(), Some(5))
  assert_eq(matrix.multiply(identity_matrix(2)).unwrap().values(), [1, 2, 3, 4])
  assert_eq(parse_int_matrix("1,2\n3,4").unwrap().column_sums(), [4, 6])
  let summary = integer_summary([4, 1, 3, 2])
  assert_eq(summary.minimum(), 1)
  assert_eq(summary.maximum(), 4)
  assert_eq(summary.median(), 3)
  assert_eq(integer_mean([]), 0)
  assert_eq(integer_percentile([1, 2, 3, 4], 50), Some(2))
}

///|
test "puzzle models reject invalid cells and solve cyclic latin squares" {
  assert_true(nonogram_line(2, [3]) is Some(_))
  let line = nonogram_line(5, [2]).unwrap()
  assert_true(line.matches([0, 1, 1, 0, 0]))
  assert_true(!line.matches([0, 1, 0, 1, 0]))
  assert_eq(line.patterns().length(), 4)
  let column = nonogram_line(1, [1]).unwrap()
  let puzzle = nonogram_puzzle([line], [column, column, column, column, column]).unwrap()
  assert_true(puzzle.fix(0, 0, 1))
  assert_true(!puzzle.fix(0, 0, 0))
  assert_true(!puzzle.fix(-1, 0, 1))
  let latin = cyclic_latin_puzzle(3).unwrap()
  assert_true(latin.solved())
  assert_true(!latin.set(0, 0, 2))
}

///|
test "scenario and risk analysis are deterministic" {
  let axes = [scenario_axis("workers", [1, 2]), scenario_axis("shift", [8, 10])]
  assert_eq(scenario_product_size(axes, 10), 4)
  let scenarios = scenario_product(axes, 3)
  assert_eq(scenarios.length(), 3)
  let changed = scenarios[0].delta("workers", 1)
  assert_true(changed.get("workers") is Some(_))
  let evaluations = [
    evaluate_scenario(scenarios[0], 10, true),
    evaluate_scenario(scenarios[1], 20, false),
    evaluate_scenario(scenarios[2], 15, true),
  ]
  assert_eq(feasible_scenario_count(evaluations), 2)
  assert_eq(best_scenario(evaluations, false).unwrap().score(), 15)
  let risk = risk_item(0, "latency", 80, 90, 50)
  assert_eq(risk.gross_score(), 72)
  assert_eq(risk.residual_score(), 36)
  assert_eq(risk_band_name(risk_band(risk.residual_score())), "medium")
  assert_true(risk_meets_target(risk, 40))
}

///|
test "flow and relation matching honor sparse compatibility" {
  let relation = finite_relation(3, 3)
  assert_true(relation.add(0, 0))
  assert_true(relation.add(1, 1))
  assert_true(relation.add(2, 1))
  assert_true(!relation.add(1, 1))
  let matching = bipartite_matching(3, 3, relation)
  assert_eq(matching.length(), 2)
  let network = capacity_network(4)
  assert_true(network.add_arc(0, 1, 3, 1))
  assert_true(network.add_arc(0, 2, 2, 1))
  assert_true(network.add_arc(1, 3, 2, 1))
  assert_true(network.add_arc(2, 3, 2, 1))
  assert_eq(network.max_flow(0, 3).0, 4)
  assert_true(!network.add_arc(4, 3, 1, 0))
}

///|
test "validation and quality reports aggregate boundary failures" {
  let report = validation_report()
  assert_true(validate_range(report, "score", 7, 0, 10))
  assert_true(!validate_range(report, "score", 11, 0, 10))
  assert_true(!report.valid())
  assert_eq(report.error_count(), 1)
  let review = quality_review()
  review.require("valid", true, "model is feasible")
  review.maximum("errors", report.error_count(), 0, "no errors expected")
  assert_true(!review.passed())
  assert_eq(review.failure_count(), 1)
  assert_true(review.status_line().length() > 0)
}

///|
test "operational ledger repairs records and computes health" {
  let ledger = operational_ledger()
  assert_true(
    ledger.append(
      operational_record("a", operational_succeeded(), 0, 10, 1, 4, 0),
    ),
  )
  assert_true(
    ledger.append(
      operational_record("b", operational_failed(), 10, 25, 2, 0, 503),
    ),
  )
  assert_true(
    ledger.append(
      operational_record("c", operational_queued(), 20, 20, 0, 0, 0),
    ),
  )
  assert_true(
    !ledger.append(
      operational_record("a", operational_succeeded(), 0, 1, 1, 1, 0),
    ),
  )
  assert_eq(ledger.count_success(), 1)
  assert_eq(ledger.count_failure(), 1)
  assert_eq(ledger.count_retryable(), 1)
  assert_eq(ledger.success_rate(), 50)
  assert_eq(ledger.output_sum(), 4)
  assert_true(ledger.validate())
  assert_true(operational_capacity_ok(ledger, 1))
  assert_eq(operational_backlog(ledger), 1)
  assert_true(operational_health_score(ledger) > 0)
  let summary = ledger.summary()
  assert_true(operational_summary_balance(summary))
  assert_true(operational_summary_report(summary).length() > 0)
  let repaired = operational_record_repair(
    operational_record("repair", operational_failed(), -1, -2, -1, -3, -4),
  )
  assert_true(operational_record_valid(repaired))
}

///|
test "result helpers preserve stable integer indicators" {
  assert_eq(count_true([true, false, true]), 2)
  assert_eq(count_false([true, false, true]), 1)
  assert_true(all_true([true, true]))
  assert_true(any_true([false, true]))
  assert_eq(boolean_indicators([true, false]), [1, 0])
  assert_eq(indicator_sum([1, 2, 1], 1), 2)
  assert_eq(range_completion([0, 1, 2, 8], 0, 2), 75)
  assert_eq(pairwise_distance_sum([0, 2, 5]), 10)
  assert_eq(operational_score(90, 2, 10), 89980)
  let counter = result_counter()
  ignore(counter.accept(true))
  ignore(counter.accept(false))
  assert_eq(counter.total(), 2)
  assert_eq(counter.success_rate(), 50)
  assert_true(!counter.passed())
}
