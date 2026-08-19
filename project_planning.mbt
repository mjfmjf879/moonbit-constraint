///|
/// Project planning primitives for dependency-constrained work.
///
/// A planning task has a start variable, a fixed duration, an optional
/// release time, a due date, and a resource demand. The API supports both a
/// fast critical-path analysis and a Solver-backed schedule for exact checks.
pub struct PlanningTask {
  id : Int
  name : String
  duration : Int
  resource : Int
  demand : Int
  release : Int
  due : Int
}

///|
/// Create a task with no release restriction and an open due date.
pub fn planning_task(
  id : Int,
  name : String,
  duration : Int,
  resource : Int,
  demand : Int,
) -> PlanningTask {
  {
    id,
    name,
    duration: if duration < 0 {
      0
    } else {
      duration
    },
    resource,
    demand: if demand < 0 {
      0
    } else {
      demand
    },
    release: 0,
    due: 2147483647,
  }
}

///|
/// Return a task with a release and due window.
pub fn PlanningTask::with_window(
  self : PlanningTask,
  release : Int,
  due : Int,
) -> PlanningTask {
  { ..self, release, due }
}

///|
/// Read the task identifier.
pub fn PlanningTask::id(self : PlanningTask) -> Int {
  self.id
}

///|
/// Read the task name.
pub fn PlanningTask::name(self : PlanningTask) -> String {
  self.name
}

///|
/// Read the duration.
pub fn PlanningTask::duration(self : PlanningTask) -> Int {
  self.duration
}

///|
/// Read the resource identifier.
pub fn PlanningTask::resource(self : PlanningTask) -> Int {
  self.resource
}

///|
/// Read the resource demand.
pub fn PlanningTask::demand(self : PlanningTask) -> Int {
  self.demand
}

///|
/// Return whether the time window is valid.
pub fn PlanningTask::valid_window(self : PlanningTask) -> Bool {
  self.release <= self.due
}

///|
/// Return whether an interval contains a time point.
pub fn PlanningTask::contains(
  self : PlanningTask,
  start : Int,
  time : Int,
) -> Bool {
  time >= start && time < start + self.duration
}

///|
/// A precedence arc from one task to another.
pub struct PlanningDependency {
  before : Int
  after : Int
  lag : Int
}

///|
/// Create a dependency with a minimum lag after the predecessor.
pub fn planning_dependency(
  before : Int,
  after : Int,
  lag : Int,
) -> PlanningDependency {
  { before, after, lag: if lag < 0 { 0 } else { lag } }
}

///|
/// Read the predecessor.
pub fn PlanningDependency::before(self : PlanningDependency) -> Int {
  self.before
}

///|
/// Read the successor.
pub fn PlanningDependency::after(self : PlanningDependency) -> Int {
  self.after
}

///|
/// Read the minimum lag.
pub fn PlanningDependency::lag(self : PlanningDependency) -> Int {
  self.lag
}

///|
/// A project plan with an exact finite-domain start model.
pub struct ProjectPlan {
  solver : Solver
  tasks : Array[PlanningTask]
  starts : Array[Int]
  dependencies : Array[PlanningDependency]
  horizon : Int
  capacities : Array[Int]
}

///|
/// Construct a project plan and its start variables.
pub fn project_plan(
  tasks : Array[PlanningTask],
  horizon : Int,
  capacities : Array[Int],
) -> ProjectPlan? {
  if horizon < 0 || capacities.length() == 0 {
    return None
  }
  for index, task in tasks {
    if task.id != index ||
      task.resource < 0 ||
      task.resource >= capacities.length() ||
      task.demand < 0 ||
      !task.valid_window() ||
      task.duration > horizon {
      return None
    }
    if task.due > horizon + task.duration && task.due != 2147483647 {
      return None
    }
    if task.demand > capacities[task.resource] {
      return None
    }
  }
  for capacity in capacities {
    if capacity < 0 {
      return None
    }
  }
  let solver = new_solver()
  let starts : Array[Int] = []
  for task in tasks {
    let latest = horizon - task.duration
    let variable = solver.add_variable(variable("start_\{task.id}", 0, latest))
    starts.push(variable)
    solver.add_constraint(greater_equal(variable, task.release))
    if task.due != 2147483647 {
      solver.add_constraint(less_equal(variable, task.due - task.duration))
    }
  }
  Some({
    solver,
    tasks: tasks.copy(),
    starts,
    dependencies: [],
    horizon,
    capacities: capacities.copy(),
  })
}

///|
/// Read the number of tasks.
pub fn ProjectPlan::task_count(self : ProjectPlan) -> Int {
  self.tasks.length()
}

///|
/// Read the planning horizon.
pub fn ProjectPlan::horizon(self : ProjectPlan) -> Int {
  self.horizon
}

///|
/// Read a task.
pub fn ProjectPlan::task(self : ProjectPlan, id : Int) -> PlanningTask {
  if id < 0 || id >= self.tasks.length() {
    abort("planning task is outside the project")
  }
  self.tasks[id]
}

///|
/// Read a start variable identifier.
pub fn ProjectPlan::start_variable(self : ProjectPlan, id : Int) -> Int {
  if id < 0 || id >= self.starts.length() {
    abort("planning task is outside the project")
  }
  self.starts[id]
}

///|
/// Add a precedence relationship.
pub fn ProjectPlan::add_dependency(
  self : ProjectPlan,
  before : Int,
  after : Int,
  lag : Int,
) -> Bool {
  if before < 0 ||
    after < 0 ||
    before >= self.tasks.length() ||
    after >= self.tasks.length() ||
    before == after {
    return false
  }
  let dependency = planning_dependency(before, after, lag)
  self.dependencies.push(dependency)
  self.solver.add_constraint(
    linear_greater_equal(
      [(self.starts[after], 1), (self.starts[before], -1)],
      self.tasks[before].duration + dependency.lag,
    ),
  )
  true
}

///|
/// Add a fixed assignment for a task start.
pub fn ProjectPlan::fix_start(
  self : ProjectPlan,
  id : Int,
  start : Int,
) -> Bool {
  if id < 0 ||
    id >= self.tasks.length() ||
    start < 0 ||
    start + self.tasks[id].duration > self.horizon {
    return false
  }
  self.solver.assign(self.starts[id], start)
}

///|
/// Add pairwise non-overlap constraints for a resource's tasks.
pub fn ProjectPlan::post_resource_non_overlap(
  self : ProjectPlan,
  resource : Int,
) -> Bool {
  if resource < 0 || resource >= self.capacities.length() {
    return false
  }
  let intervals : Array[(Int, Int)] = []
  for index, task in self.tasks {
    if task.resource == resource {
      intervals.push((self.starts[index], task.duration))
    }
  }
  if intervals.length() > 1 {
    self.solver.add_constraint(no_overlap(intervals))
  }
  true
}

///|
/// Add non-overlap constraints for every resource.
pub fn ProjectPlan::post_all_resource_non_overlap(self : ProjectPlan) -> Unit {
  for resource in 0..<self.capacities.length() {
    ignore(self.post_resource_non_overlap(resource))
  }
}

///|
/// Read copied dependencies.
pub fn ProjectPlan::dependencies(
  self : ProjectPlan,
) -> Array[PlanningDependency] {
  self.dependencies.copy()
}

///|
/// Return a topological task order, or None when dependencies cycle.
pub fn ProjectPlan::topological_order(self : ProjectPlan) -> Array[Int]? {
  let indegree : Array[Int] = []
  let outgoing : Array[Array[Int]] = []
  for _ in self.tasks {
    indegree.push(0)
    outgoing.push([])
  }
  for dependency in self.dependencies {
    indegree[dependency.after] += 1
    outgoing[dependency.before].push(dependency.after)
  }
  let ready : Array[Int] = []
  for id in 0..<self.tasks.length() {
    if indegree[id] == 0 {
      ready.push(id)
    }
  }
  let result : Array[Int] = []
  let mut head = 0
  while head < ready.length() {
    let task = ready[head]
    head += 1
    result.push(task)
    for successor in outgoing[task] {
      indegree[successor] -= 1
      if indegree[successor] == 0 {
        ready.push(successor)
      }
    }
  }
  if result.length() == self.tasks.length() {
    Some(result)
  } else {
    None
  }
}

///|
/// Return whether the dependency network is acyclic.
pub fn ProjectPlan::has_cycle(self : ProjectPlan) -> Bool {
  self.topological_order() is None
}

///|
/// Compute earliest feasible starts using a critical-path pass.
pub fn ProjectPlan::earliest_starts(self : ProjectPlan) -> Array[Int] {
  let result : Array[Int] = []
  for task in self.tasks {
    result.push(task.release)
  }
  match self.topological_order() {
    None => result
    Some(order) => {
      for task in order {
        for dependency in self.dependencies {
          if dependency.after == task {
            let candidate = result[dependency.before] +
              self.tasks[dependency.before].duration +
              dependency.lag
            if candidate > result[task] {
              result[task] = candidate
            }
          }
        }
      }
      result
    }
  }
}

///|
/// Compute latest starts without extending the project horizon.
pub fn ProjectPlan::latest_starts(self : ProjectPlan) -> Array[Int] {
  let result : Array[Int] = []
  for task in self.tasks {
    result.push(self.horizon - task.duration)
  }
  match self.topological_order() {
    None => result
    Some(order) => {
      let last = order.length() - 1
      for position in last>=..0 {
        let task = order[position]
        for dependency in self.dependencies {
          if dependency.before == task {
            let candidate = result[dependency.after] -
              self.tasks[task].duration -
              dependency.lag
            if candidate < result[task] {
              result[task] = candidate
            }
          }
        }
      }
      result
    }
  }
}

///|
/// Return task slack from earliest and latest passes.
pub fn ProjectPlan::slacks(self : ProjectPlan) -> Array[Int] {
  let earliest = self.earliest_starts()
  let latest = self.latest_starts()
  let result : Array[Int] = []
  for id in 0..<self.tasks.length() {
    result.push(latest[id] - earliest[id])
  }
  result
}

///|
/// Return all zero-slack tasks.
pub fn ProjectPlan::critical_tasks(self : ProjectPlan) -> Array[Int] {
  let result : Array[Int] = []
  for id, slack in self.slacks() {
    if slack <= 0 {
      result.push(id)
    }
  }
  result
}

///|
/// Return the critical-path makespan.
pub fn ProjectPlan::critical_path_length(self : ProjectPlan) -> Int {
  let starts = self.earliest_starts()
  let mut result = 0
  for id, start in starts {
    let finish = start + self.tasks[id].duration
    if finish > result {
      result = finish
    }
  }
  result
}

///|
/// Solve the exact start model once.
pub fn ProjectPlan::solve(self : ProjectPlan) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate project schedules.
pub fn ProjectPlan::solve_all(
  self : ProjectPlan,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Read the latest search statistics.
pub fn ProjectPlan::stats(self : ProjectPlan) -> SearchStats {
  self.solver.stats()
}

///|
/// Return the underlying solver for application-specific constraints.
pub fn ProjectPlan::solver(self : ProjectPlan) -> Solver {
  self.solver
}

///|
/// Extract start times from a solution.
pub fn ProjectPlan::schedule(
  self : ProjectPlan,
  solution : Solution,
) -> Array[Int] {
  self.starts.map(variable => solution.get(variable))
}

///|
/// Return a schedule's makespan.
pub fn ProjectPlan::makespan(self : ProjectPlan, starts : Array[Int]) -> Int {
  let mut result = 0
  for id, start in starts {
    if id < self.tasks.length() {
      let finish = start + self.tasks[id].duration
      if finish > result {
        result = finish
      }
    }
  }
  result
}

///|
/// Return resource usage at each time slot.
pub fn ProjectPlan::resource_profile(
  self : ProjectPlan,
  starts : Array[Int],
  resource : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for _ in 0..<self.horizon {
    result.push(0)
  }
  if resource < 0 || resource >= self.capacities.length() {
    return result
  }
  for id, task in self.tasks {
    if id >= starts.length() || task.resource != resource {
      continue
    }
    let start = starts[id]
    for time in start..<(start + task.duration) {
      if time >= 0 && time < result.length() {
        result[time] += task.demand
      }
    }
  }
  result
}

///|
/// Validate a concrete schedule and return stable error codes.
pub fn ProjectPlan::validate_schedule(
  self : ProjectPlan,
  starts : Array[Int],
) -> Array[String] {
  let errors : Array[String] = []
  if starts.length() != self.tasks.length() {
    errors.push("task-count-mismatch")
    return errors
  }
  for id, start in starts {
    let task = self.tasks[id]
    if start < task.release {
      errors.push("release-before-task-\{id}")
    }
    if start + task.duration > self.horizon {
      errors.push("horizon-exceeded-\{id}")
    }
    if start + task.duration > task.due {
      errors.push("due-date-exceeded-\{id}")
    }
  }
  for dependency in self.dependencies {
    if starts[dependency.after] <
      starts[dependency.before] +
      self.tasks[dependency.before].duration +
      dependency.lag {
      errors.push("precedence-\{dependency.before}-\{dependency.after}")
    }
  }
  for resource in 0..<self.capacities.length() {
    for time, load in self.resource_profile(starts, resource) {
      if load > self.capacities[resource] {
        errors.push("capacity-\{resource}-\{time}")
      }
    }
  }
  errors
}

///|
/// Return whether a concrete schedule is valid.
pub fn ProjectPlan::is_valid_schedule(
  self : ProjectPlan,
  starts : Array[Int],
) -> Bool {
  self.validate_schedule(starts).length() == 0
}

///|
/// Return a stable task timeline.
pub fn ProjectPlan::render(self : ProjectPlan, starts : Array[Int]) -> String {
  let builder = StringBuilder()
  for id, task in self.tasks {
    if id > 0 {
      builder.write_char('\n')
    }
    let start = if id < starts.length() { starts[id] } else { -1 }
    builder.write_string(
      "\{id}:\{task.name}@\{start}+\{task.duration}/r\{task.resource}",
    )
  }
  builder.to_string()
}

///|
/// Return tasks that directly precede a task.
pub fn ProjectPlan::predecessors(self : ProjectPlan, id : Int) -> Array[Int] {
  let result : Array[Int] = []
  for dependency in self.dependencies {
    if dependency.after == id {
      result.push(dependency.before)
    }
  }
  result
}

///|
/// Return tasks that directly follow a task.
pub fn ProjectPlan::successors(self : ProjectPlan, id : Int) -> Array[Int] {
  let result : Array[Int] = []
  for dependency in self.dependencies {
    if dependency.before == id {
      result.push(dependency.after)
    }
  }
  result
}

///|
/// Return the total work across all tasks.
pub fn ProjectPlan::total_work(self : ProjectPlan) -> Int {
  let mut result = 0
  for task in self.tasks {
    result += task.duration
  }
  result
}

///|
/// Return total demand-time across all tasks.
pub fn ProjectPlan::total_load(self : ProjectPlan) -> Int {
  let mut result = 0
  for task in self.tasks {
    result += task.duration * task.demand
  }
  result
}

///|
/// Return resource utilization in integer percentage points.
pub fn ProjectPlan::resource_utilization(
  self : ProjectPlan,
  starts : Array[Int],
  resource : Int,
) -> Int {
  if resource < 0 || resource >= self.capacities.length() || self.horizon == 0 {
    return 0
  }
  let profile = self.resource_profile(starts, resource)
  let mut total = 0
  for load in profile {
    total += load
  }
  total * 100 / (self.horizon * self.capacities[resource])
}

///|
/// Return the first task that uses a resource at a time.
pub fn ProjectPlan::task_at(
  self : ProjectPlan,
  starts : Array[Int],
  resource : Int,
  time : Int,
) -> Int? {
  for id, task in self.tasks {
    if task.resource == resource &&
      id < starts.length() &&
      task.contains(starts[id], time) {
      return Some(id)
    }
  }
  None
}

///|
/// Return all task ids using a resource.
pub fn ProjectPlan::tasks_on_resource(
  self : ProjectPlan,
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
/// Return a stable plan fingerprint.
pub fn ProjectPlan::signature(self : ProjectPlan) -> Int {
  let mut result = self.horizon * 31 + self.tasks.length()
  for task in self.tasks {
    result = result * 37 +
      task.id +
      task.duration * 3 +
      task.resource * 5 +
      task.demand * 7
  }
  for dependency in self.dependencies {
    result = result * 41 +
      dependency.before * 11 +
      dependency.after * 13 +
      dependency.lag
  }
  result
}

///|
/// Construct a chain of equal-duration tasks.
pub fn planning_chain(
  count : Int,
  duration : Int,
  resource : Int,
  demand : Int,
  horizon : Int,
  capacity : Int,
) -> ProjectPlan? {
  let tasks : Array[PlanningTask] = []
  for id in 0..<count {
    tasks.push(planning_task(id, "task_\{id}", duration, resource, demand))
  }
  match project_plan(tasks, horizon, [capacity]) {
    None => None
    Some(plan) => {
      for id in 1..<count {
        ignore(plan.add_dependency(id - 1, id, 0))
      }
      Some(plan)
    }
  }
}

///|
/// Return whether dependencies reference valid tasks.
pub fn ProjectPlan::dependencies_valid(self : ProjectPlan) -> Bool {
  for dependency in self.dependencies {
    if dependency.before < 0 ||
      dependency.after < 0 ||
      dependency.before >= self.tasks.length() ||
      dependency.after >= self.tasks.length() {
      return false
    }
  }
  true
}

///|
/// Return the number of critical tasks.
pub fn ProjectPlan::critical_task_count(self : ProjectPlan) -> Int {
  self.critical_tasks().length()
}

///|
/// Return the maximum resource demand.
pub fn ProjectPlan::maximum_demand(self : ProjectPlan) -> Int {
  let mut result = 0
  for task in self.tasks {
    if task.demand > result {
      result = task.demand
    }
  }
  result
}

///|
/// Return a project summary for CLI diagnostics.
pub fn ProjectPlan::describe(self : ProjectPlan) -> String {
  "tasks=\{self.tasks.length()}, dependencies=\{self.dependencies.length()}, horizon=\{self.horizon}, critical=\{self.critical_path_length()}"
}
