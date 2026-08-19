///|
/// Planning utilities that bridge schedules, routes, and resource calendars.
///
/// These functions answer operational questions around a model—what is late,
/// where is capacity tight, and which task should be moved—without changing
/// the underlying solver representation.
pub struct PlanningCapacityPoint {
  resource : Int
  time : Int
  load : Int
  capacity : Int
}

///|
/// Create a capacity point.
pub fn planning_capacity_point(
  resource : Int,
  time : Int,
  load : Int,
  capacity : Int,
) -> PlanningCapacityPoint {
  { resource, time, load, capacity }
}

///|
/// Return residual capacity.
pub fn PlanningCapacityPoint::residual(self : PlanningCapacityPoint) -> Int {
  self.capacity - self.load
}

///|
/// Return whether overloaded.
pub fn PlanningCapacityPoint::overloaded(self : PlanningCapacityPoint) -> Bool {
  self.load > self.capacity
}

///|
/// Return all project capacity points.
pub fn project_capacity_points(
  project : ProjectPlan,
  starts : Array[Int],
) -> Array[PlanningCapacityPoint] {
  let result : Array[PlanningCapacityPoint] = []
  for resource in 0..<project.capacities.length() {
    for time, load in project.resource_profile(starts, resource) {
      result.push(
        planning_capacity_point(
          resource,
          time,
          load,
          project.capacities[resource],
        ),
      )
    }
  }
  result
}

///|
/// Return the tightest capacity point.
pub fn tightest_capacity_point(
  project : ProjectPlan,
  starts : Array[Int],
) -> PlanningCapacityPoint? {
  let points = project_capacity_points(project, starts)
  if points.length() == 0 {
    return None
  }
  let mut result = points[0]
  for point in points {
    if point.residual() < result.residual() {
      result = point
    }
  }
  Some(result)
}

///|
/// Return overloaded capacity points.
pub fn overloaded_capacity_points(
  project : ProjectPlan,
  starts : Array[Int],
) -> Array[PlanningCapacityPoint] {
  let result : Array[PlanningCapacityPoint] = []
  for point in project_capacity_points(project, starts) {
    if point.overloaded() {
      result.push(point)
    }
  }
  result
}

///|
/// Return tasks sorted by slack.
pub fn tasks_by_slack(project : ProjectPlan) -> Array[Int] {
  let slacks = project.slacks()
  let result : Array[Int] = []
  for id in 0..<project.task_count() {
    result.push(id)
  }
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if slacks[result[right]] < slacks[result[left]] {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return tasks that finish after their due date.
pub fn late_project_tasks(
  project : ProjectPlan,
  starts : Array[Int],
) -> Array[Int] {
  let result : Array[Int] = []
  for id, task in project.tasks {
    if id < starts.length() &&
      task.due != 2147483647 &&
      starts[id] + task.duration > task.due {
      result.push(id)
    }
  }
  result
}

///|
/// Return total tardiness.
pub fn project_tardiness(project : ProjectPlan, starts : Array[Int]) -> Int {
  let mut result = 0
  for id in late_project_tasks(project, starts) {
    let finish = starts[id] + project.tasks[id].duration
    result += finish - project.tasks[id].due
  }
  result
}

///|
/// Return a project schedule score.
pub fn project_schedule_score(
  project : ProjectPlan,
  starts : Array[Int],
) -> Int {
  project.makespan(starts) +
  project_tardiness(project, starts) * 1000 +
  project.validate_schedule(starts).length() * 1000000
}

///|
/// Shift a schedule by a constant offset.
pub fn shift_project_schedule(
  project : ProjectPlan,
  starts : Array[Int],
  offset : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for index in 0..<project.task_count() {
    if index < starts.length() {
      result.push(starts[index] + offset)
    } else {
      result.push(-1)
    }
  }
  result
}

///|
/// Return whether two project schedules have the same precedence order.
pub fn same_project_order(
  project : ProjectPlan,
  left : Array[Int],
  right : Array[Int],
) -> Bool {
  if left.length() != right.length() || left.length() != project.task_count() {
    return false
  }
  for dependency in project.dependencies {
    if (left[dependency.before] < left[dependency.after]) !=
      (right[dependency.before] < right[dependency.after]) {
      return false
    }
  }
  true
}

///|
/// Return the first task that can be moved later without breaking successors.
pub fn movable_task(project : ProjectPlan, starts : Array[Int]) -> Int? {
  if starts.length() != project.task_count() {
    return None
  }
  let slacks = project.slacks()
  for id in tasks_by_slack(project) {
    if id < slacks.length() && slacks[id] > 0 {
      return Some(id)
    }
  }
  None
}

///|
/// Return the number of dependency arcs.
pub fn project_dependency_count(project : ProjectPlan) -> Int {
  project.dependencies.length()
}

///|
/// Return the total number of predecessor relationships.
pub fn project_predecessor_count(project : ProjectPlan) -> Int {
  let mut result = 0
  for id in 0..<project.task_count() {
    result += project.predecessors(id).length()
  }
  result
}

///|
/// Return a compact planning report.
pub fn project_planning_report(
  project : ProjectPlan,
  starts : Array[Int],
) -> String {
  "tasks=\{project.task_count()}, makespan=\{project.makespan(starts)}, tardiness=\{project_tardiness(project, starts)}, late=\{late_project_tasks(project, starts).length()}, errors=\{project.validate_schedule(starts).length()}"
}
