///|
/// A worker/day/shift roster template built on the generic solver.
pub struct RosterModel {
  solver : Solver
  assignments : Array[Array[Int]]
  workers : Int
  days : Int
  shifts : Int
}

///|
/// Build an unconstrained roster with one shift variable per worker/day.
pub fn roster_model(workers : Int, days : Int, shifts : Int) -> RosterModel? {
  if workers < 1 || days < 1 || shifts < 1 {
    return None
  }
  let solver = new_solver()
  let assignments : Array[Array[Int]] = []
  for worker in 0..<workers {
    let row : Array[Int] = []
    for day in 0..<days {
      row.push(
        solver.add_variable(
          variable("worker_\{worker}_day_\{day}", 0, shifts - 1),
        ),
      )
    }
    assignments.push(row)
  }
  Some({ solver, assignments, workers, days, shifts })
}

///|
/// Return the worker count.
pub fn RosterModel::worker_count(self : RosterModel) -> Int {
  self.workers
}

///|
/// Return the day count.
pub fn RosterModel::day_count(self : RosterModel) -> Int {
  self.days
}

///|
/// Return the number of shifts.
pub fn RosterModel::shift_count(self : RosterModel) -> Int {
  self.shifts
}

///|
/// Return a worker/day variable id.
pub fn RosterModel::variable(
  self : RosterModel,
  worker : Int,
  day : Int,
) -> Int {
  if worker < 0 || worker >= self.workers || day < 0 || day >= self.days {
    abort("roster coordinate is outside the model")
  }
  self.assignments[worker][day]
}

///|
/// Return all variables for a worker.
pub fn RosterModel::worker_variables(
  self : RosterModel,
  worker : Int,
) -> Array[Int] {
  if worker < 0 || worker >= self.workers {
    abort("roster worker is outside the model")
  }
  self.assignments[worker].copy()
}

///|
/// Return all variables for a day.
pub fn RosterModel::day_variables(self : RosterModel, day : Int) -> Array[Int] {
  if day < 0 || day >= self.days {
    abort("roster day is outside the model")
  }
  self.assignments.map(row => row[day])
}

///|
/// Require exact worker coverage for each day and shift.
pub fn RosterModel::post_daily_cover(
  self : RosterModel,
  required : Array[Array[Int]],
) -> Unit {
  if required.length() != self.days {
    abort("roster coverage day count does not match model")
  }
  for day, row in required {
    if row.length() != self.shifts {
      abort("roster coverage shift count does not match model")
    }
    for shift, count in row {
      self.solver.add_constraint(
        count_value(self.day_variables(day), shift, count),
      )
    }
  }
}

///|
/// Bound how often a worker may receive a shift type.
pub fn RosterModel::post_worker_shift_bounds(
  self : RosterModel,
  worker : Int,
  shift : Int,
  minimum : Int,
  maximum : Int,
) -> Unit {
  if shift < 0 || shift >= self.shifts || minimum > maximum {
    abort("roster shift bounds are invalid")
  }
  let values = self.worker_variables(worker)
  self.solver.add_constraint(at_least_value(values, shift, minimum))
  self.solver.add_constraint(at_most_value(values, shift, maximum))
}

///|
/// Require adjacent assignments for one worker to use different shifts.
pub fn RosterModel::post_no_consecutive_shift(
  self : RosterModel,
  worker : Int,
) -> Unit {
  let values = self.worker_variables(worker)
  if values.length() < 2 {
    return
  }
  for day in 0..<(self.days - 1) {
    self.solver.add_constraint(not_equal(values[day], values[day + 1]))
  }
}

///|
/// Require different shifts within a worker's rolling window.
pub fn RosterModel::post_worker_window_different(
  self : RosterModel,
  worker : Int,
  width : Int,
) -> Unit {
  if width < 1 || width > self.days {
    abort("roster worker window is invalid")
  }
  let values = self.worker_variables(worker)
  for start in 0..<(self.days - width + 1) {
    self.solver.add_constraint(
      all_different(roster_window(values, start, width)),
    )
  }
}

///|
/// Copy one worker/day window.
fn roster_window(values : Array[Int], start : Int, width : Int) -> Array[Int] {
  let result : Array[Int] = []
  for index in start..<(start + width) {
    result.push(values[index])
  }
  result
}

///|
/// Prevent the same pair of workers from sharing a shift on a day.
pub fn RosterModel::post_pair_different(
  self : RosterModel,
  first : Int,
  second : Int,
) -> Unit {
  if first < 0 || second < 0 || first >= self.workers || second >= self.workers {
    abort("roster worker pair is invalid")
  }
  if first == second {
    abort("roster worker pair must contain two workers")
  }
  for day in 0..<self.days {
    self.solver.add_constraint(
      not_equal(self.assignments[first][day], self.assignments[second][day]),
    )
  }
}

///|
/// Require every worker to have a different shift on a day.
pub fn RosterModel::post_daily_different(self : RosterModel, day : Int) -> Unit {
  self.solver.add_constraint(all_different(self.day_variables(day)))
}

///|
/// Fix one worker/day assignment.
pub fn RosterModel::fix(
  self : RosterModel,
  worker : Int,
  day : Int,
  shift : Int,
) -> Bool {
  if shift < 0 || shift >= self.shifts {
    return false
  }
  self.solver.assign(self.variable(worker, day), shift)
}

///|
/// Bound a worker's number of assignments in a shift interval.
pub fn RosterModel::post_worker_interval(
  self : RosterModel,
  worker : Int,
  lower_shift : Int,
  upper_shift : Int,
  minimum : Int,
  maximum : Int,
) -> Unit {
  if lower_shift > upper_shift || lower_shift < 0 || upper_shift >= self.shifts {
    abort("roster shift interval is invalid")
  }
  let values = self.worker_variables(worker)
  let allowed : Array[Int] = []
  for shift in lower_shift..<=upper_shift {
    allowed.push(shift)
  }
  let indicator : Array[Int] = []
  for index, value in values {
    let marker = self.solver.add_variable(
      variable("worker_\{worker}_interval_\{index}", 0, 1),
    )
    let rows : Array[Array[Int]] = []
    for candidate in 0..<self.shifts {
      let marker_value = if allowed.contains(candidate) { 1 } else { 0 }
      rows.push([candidate, marker_value])
    }
    self.solver.add_constraint(table([value, marker], rows))
    indicator.push(marker)
  }
  self.solver.add_constraint(
    linear_greater_equal(indicator.map(id => (id, 1)), minimum),
  )
  self.solver.add_constraint(
    linear_less_equal(indicator.map(id => (id, 1)), maximum),
  )
}

///|
/// Configure the underlying search engine.
pub fn RosterModel::configure(
  self : RosterModel,
  config : SearchConfig,
) -> Unit {
  self.solver.configure(config)
}

///|
/// Solve one roster.
pub fn RosterModel::solve(self : RosterModel) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate rosters up to a limit.
pub fn RosterModel::solve_all(
  self : RosterModel,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return the latest search statistics.
pub fn RosterModel::stats(self : RosterModel) -> SearchStats {
  self.solver.stats()
}

///|
/// Check a solution against every roster constraint.
pub fn RosterModel::is_valid(self : RosterModel, solution : Solution) -> Bool {
  self.solver.is_valid_solution(solution)
}

///|
/// Read one worker's assignments.
pub fn RosterModel::worker_values(
  self : RosterModel,
  solution : Solution,
  worker : Int,
) -> Array[Int] {
  self.worker_variables(worker).map(id => solution.get(id))
}

///|
/// Read all assignments in worker-major order.
pub fn RosterModel::values(
  self : RosterModel,
  solution : Solution,
) -> Array[Array[Int]] {
  self.assignments.map(row => row.map(id => solution.get(id)))
}

///|
/// Count a shift for one worker.
pub fn RosterModel::shift_count_for(
  self : RosterModel,
  solution : Solution,
  worker : Int,
  shift : Int,
) -> Int {
  let mut count = 0
  for value in self.worker_values(solution, worker) {
    if value == shift {
      count += 1
    }
  }
  count
}

///|
/// Return a day/shift coverage matrix.
pub fn RosterModel::coverage(
  self : RosterModel,
  solution : Solution,
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for day in 0..<self.days {
    let row : Array[Int] = []
    let values = self.day_variables(day).map(id => solution.get(id))
    for shift in 0..<self.shifts {
      let mut count = 0
      for value in values {
        if value == shift {
          count += 1
        }
      }
      row.push(count)
    }
    result.push(row)
  }
  result
}

///|
/// Compute the largest worker workload difference across shifts.
pub fn RosterModel::workload_spread(
  self : RosterModel,
  solution : Solution,
) -> Int {
  let mut minimum = 2147483647
  let mut maximum = -2147483647
  for worker in 0..<self.workers {
    let workload = self.worker_values(solution, worker).length()
    if workload < minimum {
      minimum = workload
    }
    if workload > maximum {
      maximum = workload
    }
  }
  maximum - minimum
}

///|
/// Render the roster as a stable worker-major table.
pub fn RosterModel::render(self : RosterModel, solution : Solution) -> String {
  let builder = StringBuilder()
  for worker in 0..<self.workers {
    if worker > 0 {
      builder.write_char('\n')
    }
    builder.write_string("worker \{worker}:")
    for value in self.worker_values(solution, worker) {
      builder.write_string(" \{value}")
    }
  }
  builder.to_string()
}

///|
/// A compact roster quality score.
pub struct RosterScore {
  spread : Int
  violations : Int
  coverage_total : Int
}

///|
/// Score a valid or partial roster using observable structural counters.
pub fn RosterModel::score(
  self : RosterModel,
  solution : Solution,
) -> RosterScore {
  let coverage = self.coverage(solution)
  let mut total = 0
  for row in coverage {
    for count in row {
      total += count
    }
  }
  {
    spread: self.workload_spread(solution),
    violations: self.solver.violations(solution).length(),
    coverage_total: total,
  }
}

///|
/// Return the worker workload spread.
pub fn RosterScore::spread(self : RosterScore) -> Int {
  self.spread
}

///|
/// Return the number of detected violations.
pub fn RosterScore::violations(self : RosterScore) -> Int {
  self.violations
}

///|
/// Return the number of assigned worker/day cells represented by coverage.
pub fn RosterScore::coverage_total(self : RosterScore) -> Int {
  self.coverage_total
}

///|
/// Render a roster score.
pub fn RosterScore::describe(self : RosterScore) -> String {
  "spread=\{self.spread}, violations=\{self.violations}, coverage=\{self.coverage_total}"
}

///|
/// Build a small rotating-shift roster template.
pub fn rotating_roster(workers : Int, days : Int) -> RosterModel? {
  match roster_model(workers, days, workers) {
    Some(model) => {
      for day in 0..<days {
        for worker in 0..<workers {
          let shift = (worker + day) % workers
          ignore(model.fix(worker, day, shift))
        }
      }
      Some(model)
    }
    None => None
  }
}

///|
/// Build a two-shift roster with a minimum number of workers on each shift.
pub fn two_shift_roster(
  workers : Int,
  days : Int,
  minimum_per_shift : Int,
) -> RosterModel? {
  match roster_model(workers, days, 2) {
    Some(model) => {
      if minimum_per_shift < 0 || minimum_per_shift * 2 > workers {
        return None
      }
      for day in 0..<days {
        model.solver.add_constraint(
          at_least_value(model.day_variables(day), 0, minimum_per_shift),
        )
        model.solver.add_constraint(
          at_least_value(model.day_variables(day), 1, minimum_per_shift),
        )
      }
      Some(model)
    }
    None => None
  }
}

///|
/// Return a stable roster fingerprint.
pub fn RosterModel::fingerprint(
  self : RosterModel,
  solution : Solution,
) -> String {
  let builder = StringBuilder()
  for worker, row in self.values(solution) {
    if worker > 0 {
      builder.write_char(';')
    }
    for day, value in row {
      if day > 0 {
        builder.write_char(',')
      }
      builder.write_string("\{value}")
    }
  }
  builder.to_string()
}
