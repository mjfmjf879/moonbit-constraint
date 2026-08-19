///|
/// A finite-horizon interval scheduling model.
pub struct IntervalTask {
  name : String
  start : Int
  duration : Int
  demand : Int
  latest_start : Int
}

///|
/// A resource-constrained schedule with optional capacity checks.
pub struct ResourceSchedule {
  solver : Solver
  tasks : Array[IntervalTask]
  horizon : Int
  capacity : Int
}

///|
/// Create an empty resource schedule.
pub fn resource_schedule(horizon : Int, capacity : Int) -> ResourceSchedule? {
  if horizon < 1 || capacity < 1 {
    return None
  }
  Some({ solver: new_solver(), tasks: [], horizon, capacity })
}

///|
/// Add an interval task and return its index.
pub fn ResourceSchedule::add_task(
  self : ResourceSchedule,
  name : String,
  duration : Int,
  demand : Int,
  latest_start : Int,
) -> Int? {
  if duration < 1 ||
    demand < 1 ||
    demand > self.capacity ||
    latest_start < 0 ||
    latest_start + duration > self.horizon {
    return None
  }
  let start = self.solver.add_variable(
    variable("start_\{name}_\{self.tasks.length()}", 0, latest_start),
  )
  let task = { name, start, duration, demand, latest_start }
  self.tasks.push(task)
  self.refresh_constraints()
  Some(self.tasks.length() - 1)
}

///|
/// Add an interval with a full-horizon start window.
pub fn ResourceSchedule::add_flexible_task(
  self : ResourceSchedule,
  name : String,
  duration : Int,
  demand : Int,
) -> Int? {
  self.add_task(name, duration, demand, self.horizon - duration)
}

///|
/// Set an exact task start.
pub fn ResourceSchedule::fix_start(
  self : ResourceSchedule,
  task : Int,
  start : Int,
) -> Bool {
  match self.tasks.get(task) {
    Some(value) => self.solver.assign(value.start, start)
    None => false
  }
}

///|
/// Return the start variable for a task.
pub fn ResourceSchedule::start_variable(
  self : ResourceSchedule,
  task : Int,
) -> Int {
  match self.tasks.get(task) {
    Some(value) => value.start
    None => abort("interval task index is outside the schedule")
  }
}

///|
/// Return task duration.
pub fn ResourceSchedule::duration(self : ResourceSchedule, task : Int) -> Int {
  match self.tasks.get(task) {
    Some(value) => value.duration
    None => abort("interval task index is outside the schedule")
  }
}

///|
/// Return task name.
pub fn ResourceSchedule::task_name(
  self : ResourceSchedule,
  task : Int,
) -> String {
  match self.tasks.get(task) {
    Some(value) => value.name
    None => abort("interval task index is outside the schedule")
  }
}

///|
/// Add a precedence relation by tightening the successor start domain.
pub fn ResourceSchedule::precede(
  self : ResourceSchedule,
  first : Int,
  second : Int,
) -> Bool {
  let left = match self.tasks.get(first) {
    Some(value) => value
    None => return false
  }
  let right = match self.tasks.get(second) {
    Some(value) => value
    None => return false
  }
  if first == second {
    return false
  }
  self.solver.add_constraint(greater_equal(right.start, left.start))
  self.solver.add_constraint(
    no_overlap([(left.start, left.duration), (right.start, right.duration)]),
  )
  true
}

///|
/// Re-post all global resource constraints after a task is added.
fn ResourceSchedule::refresh_constraints(self : ResourceSchedule) -> Unit {
  let intervals : Array[(Int, Int)] = []
  let demands : Array[(Int, Int, Int)] = []
  for task in self.tasks {
    intervals.push((task.start, task.duration))
    demands.push((task.start, task.duration, task.demand))
  }
  if intervals.length() > 1 {
    self.solver.add_constraint(no_overlap(intervals))
  }
  if demands.length() > 0 {
    self.solver.add_constraint(cumulative(demands, self.capacity))
  }
}

///|
/// Solve the resource schedule once.
pub fn ResourceSchedule::solve(self : ResourceSchedule) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate up to `limit` schedules.
pub fn ResourceSchedule::solve_all(
  self : ResourceSchedule,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return statistics for the most recent solve.
pub fn ResourceSchedule::stats(self : ResourceSchedule) -> SearchStats {
  self.solver.stats()
}

///|
/// Return the number of tasks.
pub fn ResourceSchedule::task_count(self : ResourceSchedule) -> Int {
  self.tasks.length()
}

///|
/// Return all task starts from a solution.
pub fn ResourceSchedule::starts(
  self : ResourceSchedule,
  solution : Solution,
) -> Array[Int] {
  self.tasks.map(task => solution.get(task.start))
}

///|
/// Return task end times from a solution.
pub fn ResourceSchedule::ends(
  self : ResourceSchedule,
  solution : Solution,
) -> Array[Int] {
  self.tasks.map(task => solution.get(task.start) + task.duration)
}

///|
/// Check every task and capacity slot in a complete schedule.
pub fn ResourceSchedule::is_valid(
  self : ResourceSchedule,
  solution : Solution,
) -> Bool {
  if !self.solver.is_valid_solution(solution) {
    return false
  }
  for time in 0..<self.horizon {
    let mut load = 0
    for task in self.tasks {
      let start = solution.get(task.start)
      if time >= start && time < start + task.duration {
        load += task.demand
      }
    }
    if load > self.capacity {
      return false
    }
  }
  true
}

///|
/// Render a Gantt-like one-line-per-task schedule.
pub fn ResourceSchedule::render(
  self : ResourceSchedule,
  solution : Solution,
) -> String {
  let builder = StringBuilder()
  for index, task in self.tasks {
    if index > 0 {
      builder.write_char('\n')
    }
    let start = solution.get(task.start)
    builder.write_string(task.name)
    builder.write_string(
      " [\{start}, \{start + task.duration}) demand=\{task.demand}",
    )
  }
  builder.to_string()
}

///|
/// Return a resource load profile.
pub fn ResourceSchedule::load_profile(
  self : ResourceSchedule,
  solution : Solution,
) -> Array[Int] {
  let loads = Array::make(self.horizon, 0)
  for task in self.tasks {
    let start = solution.get(task.start)
    for time in start..<(start + task.duration) {
      if time >= 0 && time < self.horizon {
        loads[time] += task.demand
      }
    }
  }
  loads
}

///|
/// Return a stable task list summary.
pub fn ResourceSchedule::summary(self : ResourceSchedule) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "horizon=\{self.horizon}, capacity=\{self.capacity}, tasks=\{self.tasks.length()}",
  )
  for index, task in self.tasks {
    builder.write_string(
      "\n  [\{index}] \{task.name}: duration=\{task.duration}, demand=\{task.demand}, latest=\{task.latest_start}",
    )
  }
  builder.to_string()
}

///|
/// Add an exclusive maintenance window to every task by fixing an allowed
/// start range that lies entirely before or after the window.
pub fn ResourceSchedule::avoid_window(
  self : ResourceSchedule,
  window_start : Int,
  window_end : Int,
) -> Bool {
  if window_start < 0 || window_end > self.horizon || window_start >= window_end {
    return false
  }
  for task in self.tasks {
    let latest_before = window_start - task.duration
    let earliest_after = window_end
    let allowed : Array[Int] = []
    for start in 0..<=task.latest_start {
      if start <= latest_before || start >= earliest_after {
        allowed.push(start)
      }
    }
    self.solver.add_constraint(allowed_values(task.start, allowed))
  }
  true
}

///|
/// Return a two-machine flow-shop example.
pub fn flow_shop(
  jobs : Array[(String, Int, Int)],
  horizon : Int,
) -> ResourceSchedule? {
  let schedule = match resource_schedule(horizon, 1) {
    Some(value) => value
    None => return None
  }
  for job in jobs {
    let (name, first_duration, second_duration) = job
    let first = match
      schedule.add_flexible_task("\{name}-m1", first_duration, 1) {
      Some(value) => value
      None => return None
    }
    let second = match
      schedule.add_flexible_task("\{name}-m2", second_duration, 1) {
      Some(value) => value
      None => return None
    }
    ignore(schedule.precede(first, second))
  }
  Some(schedule)
}
