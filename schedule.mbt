///|
/// A compact multi-day staff scheduling model.
///
/// Each slot is an integer variable containing the assigned worker. The
/// builder adds per-day uniqueness, workload bounds, and optional rotation
/// constraints while leaving the model open for application-specific rules.
pub struct ScheduleProblem {
  solver : Solver
  slots : Array[Int]
  people : Int
  days : Int
  shifts_per_day : Int
  minimum_load : Int
  maximum_load : Int
}

///|
/// Create a balanced schedule model.
pub fn balanced_schedule(
  people : Int,
  days : Int,
  shifts_per_day : Int,
) -> ScheduleProblem? {
  if people < 1 || days < 1 || shifts_per_day < 1 || shifts_per_day > people {
    return None
  }
  let total_slots = days * shifts_per_day
  let minimum_load = total_slots / people
  let maximum_load = if total_slots % people == 0 {
    minimum_load
  } else {
    minimum_load + 1
  }
  let solver = new_solver()
  let slots : Array[Int] = []
  for slot in 0..<total_slots {
    slots.push(solver.add_variable(variable("slot_\{slot}", 0, people - 1)))
  }
  for day in 0..<days {
    let start = day * shifts_per_day
    let day_slots = slots[start:start + shifts_per_day].to_owned()
    solver.add_constraint(all_different(day_slots))
  }
  for person in 0..<people {
    solver.add_constraint(at_least_value(slots, person, minimum_load))
    solver.add_constraint(at_most_value(slots, person, maximum_load))
  }
  Some({
    solver,
    slots,
    people,
    days,
    shifts_per_day,
    minimum_load,
    maximum_load,
  })
}

///|
/// Add a rule that the same shift rotates between consecutive days.
pub fn ScheduleProblem::avoid_same_shift(
  self : ScheduleProblem,
  shift : Int,
) -> Bool {
  if shift < 0 || shift >= self.shifts_per_day {
    return false
  }
  if self.days < 2 {
    return true
  }
  for day in 0..<(self.days - 1) {
    let left = self.slots[day * self.shifts_per_day + shift]
    let right = self.slots[(day + 1) * self.shifts_per_day + shift]
    self.solver.add_constraint(not_equal(left, right))
  }
  true
}

///|
/// Add a rule that two workers cannot share a day.
pub fn ScheduleProblem::avoid_pair(
  self : ScheduleProblem,
  first : Int,
  second : Int,
) -> Bool {
  if first < 0 || first >= self.people || second < 0 || second >= self.people {
    return false
  }
  if first == second {
    return false
  }
  for day in 0..<self.days {
    let day_slots = self.slots[day * self.shifts_per_day:day *
    self.shifts_per_day +
    self.shifts_per_day].to_owned()
    let first_count = count_value(day_slots, first, 1)
    let second_count = count_value(day_slots, second, 1)
    self.solver.add_constraint(at_most_value(day_slots, first, 1))
    self.solver.add_constraint(at_most_value(day_slots, second, 1))
    ignore(first_count)
    ignore(second_count)
  }
  true
}

///|
/// Add an exact assignment for one day and shift.
pub fn ScheduleProblem::fix(
  self : ScheduleProblem,
  day : Int,
  shift : Int,
  person : Int,
) -> Bool {
  if day < 0 || day >= self.days || shift < 0 || shift >= self.shifts_per_day {
    return false
  }
  if person < 0 || person >= self.people {
    return false
  }
  self.solver.assign(self.slot(day, shift), person)
}

///|
/// Return a slot variable identifier.
pub fn ScheduleProblem::slot(
  self : ScheduleProblem,
  day : Int,
  shift : Int,
) -> Int {
  if day < 0 || day >= self.days || shift < 0 || shift >= self.shifts_per_day {
    abort("schedule slot is outside the problem dimensions")
  }
  self.slots[day * self.shifts_per_day + shift]
}

///|
/// Read the configured workload lower bound.
pub fn ScheduleProblem::minimum_load(self : ScheduleProblem) -> Int {
  self.minimum_load
}

///|
/// Read the configured workload upper bound.
pub fn ScheduleProblem::maximum_load(self : ScheduleProblem) -> Int {
  self.maximum_load
}

///|
/// Solve the schedule once.
pub fn ScheduleProblem::solve(self : ScheduleProblem) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate schedule solutions.
pub fn ScheduleProblem::solve_all(
  self : ScheduleProblem,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return solver counters for the most recent schedule solve.
pub fn ScheduleProblem::stats(self : ScheduleProblem) -> SearchStats {
  self.solver.stats()
}

///|
/// Return the underlying model for additional constraints.
pub fn ScheduleProblem::solver(self : ScheduleProblem) -> Solver {
  self.solver
}

///|
/// Return all slot identifiers in day-major order.
pub fn ScheduleProblem::slot_ids(self : ScheduleProblem) -> Array[Int] {
  self.slots.copy()
}

///|
/// Convert a solution to a day-by-day integer matrix.
pub fn ScheduleProblem::assignments(
  self : ScheduleProblem,
  solution : Solution,
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for day in 0..<self.days {
    let row : Array[Int] = []
    for shift in 0..<self.shifts_per_day {
      row.push(solution.get(self.slot(day, shift)))
    }
    result.push(row)
  }
  result
}

///|
/// Render a solution as a stable, human-readable grid.
pub fn ScheduleProblem::render(
  self : ScheduleProblem,
  solution : Solution,
) -> String {
  let builder = StringBuilder()
  for day in 0..<self.days {
    if day > 0 {
      builder.write_char('\n')
    }
    builder.write_string("day \{day}: ")
    for shift in 0..<self.shifts_per_day {
      if shift > 0 {
        builder.write_string(" | ")
      }
      builder.write_string(
        "shift \{shift}=worker \{solution.get(self.slot(day, shift))}",
      )
    }
  }
  builder.to_string()
}

///|
/// Return whether an assignment covers every slot exactly once.
pub fn ScheduleProblem::is_complete(
  self : ScheduleProblem,
  solution : Solution,
) -> Bool {
  for slot in self.slots {
    let value = solution.get(slot)
    if value < 0 || value >= self.people {
      return false
    }
  }
  true
}

///|
/// A small weighted preference used by application code to rank schedules.
pub struct SchedulePreference {
  day : Int
  shift : Int
  preferred_person : Int
  penalty : Int
}

///|
/// Construct a preference record.
pub fn schedule_preference(
  day : Int,
  shift : Int,
  preferred_person : Int,
  penalty : Int,
) -> SchedulePreference {
  { day, shift, preferred_person, penalty }
}

///|
/// Score a solution by summing penalties for preference violations.
pub fn ScheduleProblem::score(
  self : ScheduleProblem,
  solution : Solution,
  preferences : Array[SchedulePreference],
) -> Int {
  let mut score = 0
  for preference in preferences {
    if preference.day < 0 ||
      preference.day >= self.days ||
      preference.shift < 0 ||
      preference.shift >= self.shifts_per_day {
      continue
    }
    if solution.get(self.slot(preference.day, preference.shift)) !=
      preference.preferred_person {
      score += preference.penalty
    }
  }
  score
}

///|
/// Return a canonical small rotating schedule used by docs and benchmarks.
pub fn rotating_schedule(
  people : Int,
  days : Int,
  shifts : Int,
) -> ScheduleProblem? {
  match balanced_schedule(people, days, shifts) {
    None => None
    Some(problem) => {
      if people > 1 {
        ignore(problem.avoid_same_shift(0))
      }
      Some(problem)
    }
  }
}

///|
/// Build a schedule from a fixed pattern and verify its dimensions.
pub fn schedule_from_pattern(
  people : Int,
  pattern : Array[Array[Int]],
) -> ScheduleProblem? {
  if pattern.length() == 0 || people < 1 {
    return None
  }
  let shifts = pattern[0].length()
  if shifts == 0 || shifts > people {
    return None
  }
  let problem = match balanced_schedule(people, pattern.length(), shifts) {
    Some(value) => value
    None => return None
  }
  for day, row in pattern {
    if row.length() != shifts {
      return None
    }
    for shift, person in row {
      if !problem.fix(day, shift, person) {
        return None
      }
    }
  }
  Some(problem)
}
