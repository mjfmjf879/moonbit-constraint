///|
/// A calendar template for interval tasks with explicit end variables.
/// It provides a compact bridge between domain constraints and resource
/// planning applications.
pub struct CalendarTask {
  name : String
  start : Int
  end : Int
  duration : Int
  resource : Int
}

///|
/// A mutable interval calendar model.
pub struct CalendarModel {
  solver : Solver
  tasks : Array[CalendarTask]
  horizon : Int
  resources : Int
}

///|
/// Create an empty calendar.
pub fn calendar_model(horizon : Int, resources : Int) -> CalendarModel? {
  if horizon < 1 || resources < 1 {
    return None
  }
  Some({ solver: new_solver(), tasks: [], horizon, resources })
}

///|
/// Return the planning horizon.
pub fn CalendarModel::horizon(self : CalendarModel) -> Int {
  self.horizon
}

///|
/// Return the resource count.
pub fn CalendarModel::resource_count(self : CalendarModel) -> Int {
  self.resources
}

///|
/// Return the number of tasks.
pub fn CalendarModel::task_count(self : CalendarModel) -> Int {
  self.tasks.length()
}

///|
/// Add an interval task and return its task id.
pub fn CalendarModel::add_task(
  self : CalendarModel,
  name : String,
  duration : Int,
  resource : Int,
) -> Int? {
  if duration < 1 ||
    duration > self.horizon ||
    resource < 0 ||
    resource >= self.resources {
    return None
  }
  let task_id = self.tasks.length()
  let start = self.solver.add_variable(
    variable("calendar_{task_id}_start", 0, self.horizon - duration),
  )
  let end = self.solver.add_variable(
    variable("calendar_{task_id}_end", duration, self.horizon),
  )
  self.solver.add_constraint(linear([(start, 1), (end, -1)], -duration))
  self.tasks.push({ name, start, end, duration, resource })
  Some(task_id)
}

///|
/// Return a task or abort on an invalid id.
pub fn CalendarModel::task(self : CalendarModel, task_id : Int) -> CalendarTask {
  if task_id < 0 || task_id >= self.tasks.length() {
    abort("calendar task is outside the model")
  }
  self.tasks[task_id]
}

///|
/// Return all task metadata.
pub fn CalendarModel::tasks(self : CalendarModel) -> Array[CalendarTask] {
  self.tasks.copy()
}

///|
/// Return a task's start variable.
pub fn CalendarTask::start(self : CalendarTask) -> Int {
  self.start
}

///|
/// Return a task's end variable.
pub fn CalendarTask::end(self : CalendarTask) -> Int {
  self.end
}

///|
/// Return a task's duration.
pub fn CalendarTask::duration(self : CalendarTask) -> Int {
  self.duration
}

///|
/// Return a task's resource.
pub fn CalendarTask::resource(self : CalendarTask) -> Int {
  self.resource
}

///|
/// Return a task's name.
pub fn CalendarTask::name(self : CalendarTask) -> String {
  self.name
}

///|
/// Return whether a task can fit in a horizon.
pub fn CalendarTask::fits(self : CalendarTask, horizon : Int) -> Bool {
  self.duration > 0 && self.duration <= horizon
}

///|
/// Render task metadata without a solution.
pub fn CalendarTask::describe(self : CalendarTask) -> String {
  "\{self.name}: start=\{self.start}, end=\{self.end}, duration=\{self.duration}, resource=\{self.resource}"
}

///|
/// Fix a task at one start time.
pub fn CalendarModel::fix_start(
  self : CalendarModel,
  task_id : Int,
  start : Int,
) -> Bool {
  let item = self.task(task_id)
  if start < 0 || start + item.duration > self.horizon {
    return false
  }
  self.solver.assign(item.start, start)
}

///|
/// Restrict a task to a start-time window.
pub fn CalendarModel::post_start_window(
  self : CalendarModel,
  task_id : Int,
  lower : Int,
  upper : Int,
) -> Unit {
  let item = self.task(task_id)
  if lower > upper {
    abort("calendar start window is inverted")
  }
  self.solver.add_constraint(between(item.start, lower, upper))
}

///|
/// Require a task to finish no later than a deadline.
pub fn CalendarModel::post_deadline(
  self : CalendarModel,
  task_id : Int,
  deadline : Int,
) -> Unit {
  let item = self.task(task_id)
  self.solver.add_constraint(between(item.end, item.duration, deadline))
}

///|
/// Require the second task to begin after the first task ends.
pub fn CalendarModel::post_precedence(
  self : CalendarModel,
  first : Int,
  second : Int,
  gap : Int,
) -> Unit {
  if gap < 0 {
    abort("calendar precedence gap cannot be negative")
  }
  let left = self.task(first)
  let right = self.task(second)
  self.solver.add_constraint(
    linear_greater_equal([(right.start, 1), (left.end, -1)], gap),
  )
}

///|
/// Require tasks on one resource not to overlap.
pub fn CalendarModel::post_resource_non_overlap(
  self : CalendarModel,
  resource : Int,
) -> Unit {
  if resource < 0 || resource >= self.resources {
    abort("calendar resource is outside the model")
  }
  let intervals : Array[(Int, Int)] = []
  for item in self.tasks {
    if item.resource == resource {
      intervals.push((item.start, item.duration))
    }
  }
  self.solver.add_constraint(no_overlap(intervals))
}

///|
/// Require every resource to execute non-overlapping tasks.
pub fn CalendarModel::post_all_resources_non_overlap(
  self : CalendarModel,
) -> Unit {
  for resource in 0..<self.resources {
    self.post_resource_non_overlap(resource)
  }
}

///|
/// Limit simultaneous demand on one resource group.
pub fn CalendarModel::post_resource_capacity(
  self : CalendarModel,
  resource : Int,
  capacity : Int,
) -> Unit {
  if resource < 0 || resource >= self.resources || capacity < 1 {
    abort("calendar capacity is invalid")
  }
  let intervals : Array[(Int, Int, Int)] = []
  for item in self.tasks {
    if item.resource == resource {
      intervals.push((item.start, item.duration, 1))
    }
  }
  self.solver.add_constraint(cumulative(intervals, capacity))
}

///|
/// Restrict all task starts to one of a finite set of slots.
pub fn CalendarModel::post_allowed_starts(
  self : CalendarModel,
  task_id : Int,
  starts : Array[Int],
) -> Unit {
  let item = self.task(task_id)
  self.solver.add_constraint(allowed_values(item.start, starts))
}

///|
/// Configure search.
pub fn CalendarModel::configure(
  self : CalendarModel,
  config : SearchConfig,
) -> Unit {
  self.solver.configure(config)
}

///|
/// Solve the calendar.
pub fn CalendarModel::solve(self : CalendarModel) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate calendar solutions.
pub fn CalendarModel::solve_all(
  self : CalendarModel,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return the latest statistics.
pub fn CalendarModel::stats(self : CalendarModel) -> SearchStats {
  self.solver.stats()
}

///|
/// Validate a complete calendar solution.
pub fn CalendarModel::is_valid(
  self : CalendarModel,
  solution : Solution,
) -> Bool {
  self.solver.is_valid_solution(solution)
}

///|
/// Read a task's start in a solution.
pub fn CalendarModel::start_of(
  self : CalendarModel,
  solution : Solution,
  task_id : Int,
) -> Int {
  solution.get(self.task(task_id).start)
}

///|
/// Read a task's end in a solution.
pub fn CalendarModel::end_of(
  self : CalendarModel,
  solution : Solution,
  task_id : Int,
) -> Int {
  solution.get(self.task(task_id).end)
}

///|
/// Return the latest end time in a solution.
pub fn CalendarModel::makespan(
  self : CalendarModel,
  solution : Solution,
) -> Int {
  let mut result = 0
  for task_id in 0..<self.task_count() {
    let end = self.end_of(solution, task_id)
    if end > result {
      result = end
    }
  }
  result
}

///|
/// Return task intervals for a solution.
pub fn CalendarModel::intervals(
  self : CalendarModel,
  solution : Solution,
) -> Array[(String, Int, Int, Int)] {
  self.tasks.map(task => {
    (task.name, solution.get(task.start), solution.get(task.end), task.resource)
  })
}

///|
/// Return task names in insertion order.
pub fn CalendarModel::task_names(self : CalendarModel) -> Array[String] {
  self.tasks.map(task => task.name)
}

///|
/// Return ids assigned to one resource.
pub fn CalendarModel::task_ids_for_resource(
  self : CalendarModel,
  resource : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for id, task in self.tasks {
    if task.resource == resource {
      result.push(id)
    }
  }
  result
}

///|
/// Sum task durations assigned to one resource.
pub fn CalendarModel::resource_load(
  self : CalendarModel,
  resource : Int,
) -> Int {
  let mut total = 0
  for task in self.tasks {
    if task.resource == resource {
      total += task.duration
    }
  }
  total
}

///|
/// Return total duration across all tasks.
pub fn CalendarModel::total_duration(self : CalendarModel) -> Int {
  self.tasks.fold(init=0, (total, task) => total + task.duration)
}

///|
/// Return the number of tasks assigned to a resource.
pub fn CalendarModel::resource_task_count(
  self : CalendarModel,
  resource : Int,
) -> Int {
  self.task_ids_for_resource(resource).length()
}

///|
/// Return the earliest start time in a solution.
pub fn CalendarModel::earliest_start(
  self : CalendarModel,
  solution : Solution,
) -> Int {
  let mut result = self.horizon
  for task in self.tasks {
    let start = solution.get(task.start)
    if start < result {
      result = start
    }
  }
  result
}

///|
/// Return the latest end time in a solution.
pub fn CalendarModel::latest_end(
  self : CalendarModel,
  solution : Solution,
) -> Int {
  let mut result = 0
  for task in self.tasks {
    let end = solution.get(task.end)
    if end > result {
      result = end
    }
  }
  result
}

///|
/// Return idle horizon time after accounting for total task duration.
pub fn CalendarModel::idle_time(
  self : CalendarModel,
  solution : Solution,
) -> Int {
  self.latest_end(solution) -
  self.earliest_start(solution) -
  self.tasks.fold(init=0, (total, task) => total + task.duration)
}

///|
/// Return the current start domains for every task.
pub fn CalendarModel::start_domains(self : CalendarModel) -> Array[Domain] {
  self.tasks.map(task => self.solver.domain_of(task.start))
}

///|
/// Return the current end domains for every task.
pub fn CalendarModel::end_domains(self : CalendarModel) -> Array[Domain] {
  self.tasks.map(task => self.solver.domain_of(task.end))
}

///|
/// Check that every task metadata record fits the configured horizon.
pub fn CalendarModel::all_tasks_fit(self : CalendarModel) -> Bool {
  for task in self.tasks {
    if !task.fits(self.horizon) {
      return false
    }
  }
  true
}

///|
/// Return a stable schedule fingerprint.
pub fn CalendarModel::fingerprint(
  self : CalendarModel,
  solution : Solution,
) -> String {
  let builder = StringBuilder()
  for id, task in self.tasks {
    if id > 0 {
      builder.write_char(';')
    }
    builder.write_string(
      "\{task.name}:\{solution.get(task.start)}-\{solution.get(task.end)}@\{task.resource}",
    )
  }
  builder.to_string()
}

///|
/// Render tasks by start time and resource id.
pub fn CalendarModel::render(
  self : CalendarModel,
  solution : Solution,
) -> String {
  let builder = StringBuilder()
  for index, item in self.intervals(solution) {
    if index > 0 {
      builder.write_char('\n')
    }
    let (name, start, end, resource) = item
    builder.write_string("\{name}: resource=\{resource}, \{start}..\{end}")
  }
  builder.to_string()
}

///|
/// A summary of calendar utilization.
pub struct CalendarSummary {
  tasks : Int
  makespan : Int
  occupied : Int
  resource_load : Array[Int]
}

///|
/// Compute utilization counters from a solution.
pub fn CalendarModel::summary(
  self : CalendarModel,
  solution : Solution,
) -> CalendarSummary {
  let loads : Array[Int] = []
  for _ in 0..<self.resources {
    loads.push(0)
  }
  let mut occupied = 0
  for task in self.tasks {
    occupied += task.duration
    loads[task.resource] += task.duration
  }
  {
    tasks: self.task_count(),
    makespan: self.makespan(solution),
    occupied,
    resource_load: loads,
  }
}

///|
/// Return the scheduled task count.
pub fn CalendarSummary::tasks(self : CalendarSummary) -> Int {
  self.tasks
}

///|
/// Return the schedule makespan.
pub fn CalendarSummary::makespan(self : CalendarSummary) -> Int {
  self.makespan
}

///|
/// Return total occupied time.
pub fn CalendarSummary::occupied(self : CalendarSummary) -> Int {
  self.occupied
}

///|
/// Return per-resource occupied time.
pub fn CalendarSummary::resource_load(self : CalendarSummary) -> Array[Int] {
  self.resource_load.copy()
}

///|
/// Render utilization counters.
pub fn CalendarSummary::describe(self : CalendarSummary) -> String {
  "tasks=\{self.tasks}, makespan=\{self.makespan}, occupied=\{self.occupied}, loads=\{Repr(self.resource_load)}"
}

///|
/// Build a simple precedence chain.
pub fn calendar_chain(durations : Array[Int], horizon : Int) -> CalendarModel? {
  if durations.length() == 0 {
    return None
  }
  match calendar_model(horizon, 1) {
    Some(model) => {
      let ids : Array[Int] = []
      for index, duration in durations {
        match model.add_task("task_\{index}", duration, 0) {
          Some(id) => ids.push(id)
          None => return None
        }
      }
      for index in 0..<(ids.length() - 1) {
        model.post_precedence(ids[index], ids[index + 1], 0)
      }
      model.post_resource_non_overlap(0)
      Some(model)
    }
    None => None
  }
}
