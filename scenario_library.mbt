///|
/// A named reusable model scenario for demos and acceptance smoke tests.
pub struct Scenario {
  name : String
  solver : Solver
  expected_solutions : Int
}

///|
/// Construct a scenario record.
pub fn scenario(
  name : String,
  solver : Solver,
  expected_solutions : Int,
) -> Scenario {
  { name, solver, expected_solutions }
}

///|
/// Read a scenario name.
pub fn Scenario::name(self : Scenario) -> String {
  self.name
}

///|
/// Solve a scenario with a cap.
pub fn Scenario::solve(self : Scenario, limit : Int) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Read expected solution count.
pub fn Scenario::expected(self : Scenario) -> Int {
  self.expected_solutions
}

///|
/// Read scenario statistics.
pub fn Scenario::stats(self : Scenario) -> SearchStats {
  self.solver.stats()
}

///|
/// Return whether the observed count matches the expected count.
pub fn Scenario::matches(self : Scenario, solutions : Array[Solution]) -> Bool {
  solutions.length() == self.expected_solutions
}

///|
/// Return a tiny arithmetic scenario.
pub fn arithmetic_scenario() -> Scenario {
  let solver = new_solver()
  let a = solver.add_variable(variable("a", 0, 9))
  let b = solver.add_variable(variable("b", 0, 9))
  solver.add_constraint(sum([a, b], 9))
  solver.add_constraint(less_than(a, b))
  scenario("arithmetic", solver, 4)
}

///|
/// Return a finite table scenario.
pub fn table_scenario() -> Scenario {
  let solver = new_solver()
  let left = solver.add_variable(variable("left", 0, 2))
  let right = solver.add_variable(variable("right", 0, 2))
  let result = solver.add_variable(variable("result", 0, 4))
  solver.add_constraint(
    table([left, right, result], [
      [0, 0, 0],
      [0, 1, 1],
      [1, 0, 1],
      [1, 1, 2],
      [2, 2, 4],
    ]),
  )
  scenario("table", solver, 5)
}

///|
/// Return a Boolean circuit scenario.
pub fn boolean_scenario() -> Scenario {
  let circuit = boolean_circuit()
  let left = circuit.input("left")
  let right = circuit.input("right")
  let output = circuit.and_gate(left, right)
  circuit.solver.add_constraint(equal(output, 1))
  scenario("boolean", circuit.solver, 1)
}

///|
/// Return a graph-coloring scenario.
pub fn coloring_scenario() -> Scenario {
  match cycle_coloring(5, 3) {
    Some(problem) => scenario("cycle_coloring", problem.solver, 1)
    None => arithmetic_scenario()
  }
}

///|
/// Return a schedule scenario with rotation rules.
pub fn schedule_scenario() -> Scenario {
  match balanced_schedule(3, 3, 2) {
    Some(problem) => {
      ignore(problem.avoid_same_shift(0))
      scenario("balanced_schedule", problem.solver, 1)
    }
    None => arithmetic_scenario()
  }
}

///|
/// Return a small resource scheduling scenario.
pub fn resource_scenario() -> Scenario {
  match resource_schedule(6, 1) {
    None => arithmetic_scenario()
    Some(problem) => {
      ignore(problem.add_flexible_task("compile", 2, 1))
      ignore(problem.add_flexible_task("test", 2, 1))
      scenario("resource_schedule", problem.solver, 1)
    }
  }
}

///|
/// Return a canonical model scenario collection.
pub fn scenario_suite() -> Array[Scenario] {
  [
    arithmetic_scenario(),
    table_scenario(),
    boolean_scenario(),
    coloring_scenario(),
    schedule_scenario(),
    resource_scenario(),
  ]
}

///|
/// Run every smoke scenario and return a concise report.
pub fn scenario_report(limit : Int) -> String {
  let builder = StringBuilder()
  for index, scenario in scenario_suite() {
    if index > 0 {
      builder.write_char('\n')
    }
    let smoke_limit = if limit < scenario.expected() {
      limit
    } else {
      scenario.expected()
    }
    let solutions = scenario.solve(smoke_limit)
    builder.write_string(
      "\{scenario.name}: observed=\{solutions.length()}, expected=\{scenario.expected()}, ok=\{scenario.matches(solutions)}",
    )
  }
  builder.to_string()
}

///|
/// Return whether every smoke scenario meets its expected count.
pub fn scenarios_pass(limit : Int) -> Bool {
  for scenario in scenario_suite() {
    let smoke_limit = if limit < scenario.expected() {
      limit
    } else {
      scenario.expected()
    }
    if !scenario.matches(scenario.solve(smoke_limit)) {
      return false
    }
  }
  true
}

///|
/// Build a precedence-chain solver for workflow examples.
pub fn workflow_chain(task_count : Int) -> Solver? {
  if task_count < 1 {
    return None
  }
  let solver = new_solver()
  let tasks : Array[Int] = []
  for task in 0..<task_count {
    tasks.push(
      solver.add_variable(variable("workflow_\{task}", 0, task_count - 1)),
    )
  }
  solver.add_constraint(all_different(tasks))
  for task in 0..<(task_count - 1) {
    solver.add_constraint(less_than(tasks[task], tasks[task + 1]))
  }
  Some(solver)
}

///|
/// Build an exactly-one selection model for a menu or feature toggle list.
pub fn feature_selection(feature_count : Int, required : Int) -> Solver? {
  if feature_count < 1 || required < 0 || required > feature_count {
    return None
  }
  let solver = new_solver()
  let features : Array[Int] = []
  for feature in 0..<feature_count {
    features.push(solver.add_variable(variable("feature_\{feature}", 0, 1)))
  }
  solver.add_constraint(sum(features, required))
  Some(solver)
}
