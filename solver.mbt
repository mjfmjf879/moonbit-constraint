///|
/// The mutable model and deterministic finite-domain search engine.
pub struct Solver {
  variables : Array[Variable]
  constraints : Array[Constraint]
  mut max_solutions : Int
  mut search_config : SearchConfig
  mut last_stats : SearchStats
}

///|
/// Create an empty model using MRV and ascending value order.
pub fn new_solver() -> Solver {
  {
    variables: [],
    constraints: [],
    max_solutions: 1,
    search_config: default_search_config(),
    last_stats: empty_search_stats(),
  }
}

///|
/// Number of variables in the model.
pub fn Solver::variable_count(self : Solver) -> Int {
  self.variables.length()
}

///|
/// Number of posted constraints in the model.
pub fn Solver::constraint_count(self : Solver) -> Int {
  self.constraints.length()
}

///|
/// Return a copy of the current variable declarations.
pub fn Solver::variables(self : Solver) -> Array[Variable] {
  self.variables.map(v => v.clone())
}

///|
/// Return a copy of all posted constraints.
pub fn Solver::constraints(self : Solver) -> Array[Constraint] {
  self.constraints.copy()
}

///|
/// Add a variable and return its zero-based identifier.
pub fn Solver::add_variable(self : Solver, variable : Variable) -> Int {
  let id = self.variables.length()
  self.variables.push(variable)
  id
}

///|
/// Add a constraint after checking all referenced variable identifiers.
pub fn Solver::add_constraint(self : Solver, constraint : Constraint) -> Unit {
  self.validate_constraint(constraint)
  self.constraints.push(constraint)
}

///|
/// Assign a value before solving. This is useful for givens in application
/// models such as Sudoku and for incremental model construction.
pub fn Solver::assign(self : Solver, variable : Int, value : Int) -> Bool {
  self.validate_variable(variable)
  self.variables[variable].domain.assign(value)
}

///|
/// Read a variable domain from the model without exposing mutable internals.
pub fn Solver::domain_of(self : Solver, variable : Int) -> Domain {
  self.validate_variable(variable)
  self.variables[variable].domain.clone()
}

///|
/// Set the maximum number of solutions collected by `solve_all`.
pub fn Solver::limit(self : Solver, count : Int) -> Unit {
  self.max_solutions = if count < 1 { 1 } else { count }
  self.search_config.max_solutions = self.max_solutions
}

///|
/// Replace the search configuration for future solves.
pub fn Solver::configure(self : Solver, config : SearchConfig) -> Unit {
  self.search_config = config
  self.max_solutions = config.max_solutions
}

///|
/// Get counters from the most recent solve.
pub fn Solver::stats(self : Solver) -> SearchStats {
  self.last_stats
}

///|
/// Reset counters without changing the model.
pub fn Solver::reset_stats(self : Solver) -> Unit {
  self.last_stats = empty_search_stats()
}

///|
/// Return a concise model summary for CLI diagnostics.
pub fn Solver::summary(self : Solver) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "variables=\{self.variables.length()}, constraints=\{self.constraints.length()}",
  )
  for id, variable in self.variables {
    builder.write_string(
      "\n  [\{id}] \{variable.name}: \{variable.domain.describe()}",
    )
  }
  builder.to_string()
}

///|
/// Internal relation used by binary domain revision.
priv enum BinaryRelation {
  RelationEqual
  RelationNotEqual
  RelationLessThan
  RelationLessEqual
  RelationGreaterThan
  RelationGreaterEqual
}

///|
/// Result of one constraint revision.
priv enum Revision {
  RevisionStable
  RevisionChanged
  RevisionContradiction
}

///|
/// Return whether a pair satisfies a binary relation.
fn relation_holds(relation : BinaryRelation, left : Int, right : Int) -> Bool {
  match relation {
    RelationEqual => left == right
    RelationNotEqual => left != right
    RelationLessThan => left < right
    RelationLessEqual => left <= right
    RelationGreaterThan => left > right
    RelationGreaterEqual => left >= right
  }
}

///|
/// Revise both sides of a binary relation until every remaining value has a
/// support on the other side.
fn revise_binary(
  left : Domain,
  right : Domain,
  relation : BinaryRelation,
) -> Revision {
  let mut changed = false
  for value in left.values() {
    let mut supported = false
    for other in right.values() {
      if relation_holds(relation, value, other) {
        supported = true
        break
      }
    }
    if !supported && left.remove(value) {
      changed = true
    }
  }
  for other in right.values() {
    let mut supported = false
    for value in left.values() {
      if relation_holds(relation, value, other) {
        supported = true
        break
      }
    }
    if !supported && right.remove(other) {
      changed = true
    }
  }
  if left.is_empty() || right.is_empty() {
    RevisionContradiction
  } else if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Return the current singleton assignment vector.
fn singleton_values(domains : Array[Domain]) -> Array[Int?] {
  domains.map(domain => domain.singleton())
}

///|
/// Copy every domain before entering a search child.
fn clone_domains(domains : Array[Domain]) -> Array[Domain] {
  domains.map(domain => domain.clone())
}

///|
/// Check a complete or partial assignment against a posted constraint.
fn check_constraint(constraint : Constraint, values : Array[Int?]) -> Bool {
  match constraint {
    Equal(a, b) => check_binary_values(values, a, b, RelationEqual)
    NotEqual(a, b) => check_binary_values(values, a, b, RelationNotEqual)
    LessThan(a, b) => check_binary_values(values, a, b, RelationLessThan)
    LessEqual(a, b) => check_binary_values(values, a, b, RelationLessEqual)
    GreaterThan(a, b) => check_binary_values(values, a, b, RelationGreaterThan)
    GreaterEqual(a, b) =>
      check_binary_values(values, a, b, RelationGreaterEqual)
    AllDifferent(ids) => check_all_different(values, ids)
    Sum(ids, target) => check_sum(values, ids, target)
    Element(index, table_values, result) =>
      check_element(values, index, table_values, result)
    Linear(terms, target) => check_linear(values, terms, target)
    LinearLessEqual(terms, target) =>
      check_linear_bound(values, terms, target, false)
    LinearGreaterEqual(terms, target) =>
      check_linear_bound(values, terms, target, true)
    Between(variable, lower, upper) =>
      match values[variable] {
        Some(value) => value >= lower && value <= upper
        None => true
      }
    Member(variable, allowed) =>
      match values[variable] {
        Some(value) => allowed.contains(value)
        None => true
      }
    CountValue(ids, value, count) =>
      check_count(values, ids, value, count, count)
    AtMostValue(ids, value, count) => check_count(values, ids, value, 0, count)
    AtLeastValue(ids, value, count) =>
      check_count(values, ids, value, count, ids.length())
    Minimum(ids, result) => check_minimum(values, ids, result)
    Maximum(ids, result) => check_maximum(values, ids, result)
    Absolute(source, result) => check_absolute(values, source, result)
    Distance(left, right, distance_value) =>
      check_distance(values, left, right, distance_value)
    NotDistance(left, right, distance_value) =>
      match (values[left], values[right]) {
        (Some(_), Some(_)) =>
          !check_distance(values, left, right, distance_value)
        _ => true
      }
    Table(ids, rows) => check_table(values, ids, rows)
    NoOverlap(tasks) => check_no_overlap(values, tasks)
    Cumulative(tasks, capacity) => check_cumulative(tasks, values, capacity)
  }
}

///|
fn check_binary_values(
  values : Array[Int?],
  left : Int,
  right : Int,
  relation : BinaryRelation,
) -> Bool {
  match (values[left], values[right]) {
    (Some(a), Some(b)) => relation_holds(relation, a, b)
    _ => true
  }
}

///|
fn check_all_different(values : Array[Int?], ids : Array[Int]) -> Bool {
  let seen = Set([])
  for id in ids {
    match values[id] {
      Some(value) =>
        if seen.contains(value) {
          return false
        } else {
          seen.add(value)
        }
      None => ()
    }
  }
  true
}

///|
fn check_sum(values : Array[Int?], ids : Array[Int], target : Int) -> Bool {
  let mut total = 0
  let mut complete = true
  for id in ids {
    match values[id] {
      Some(value) => total += value
      None => complete = false
    }
  }
  !complete || total == target
}

///|
fn check_linear(
  values : Array[Int?],
  terms : Array[(Int, Int)],
  target : Int,
) -> Bool {
  let mut total = 0
  let mut complete = true
  for term in terms {
    let (id, coefficient) = term
    match values[id] {
      Some(value) => total += coefficient * value
      None => complete = false
    }
  }
  !complete || total == target
}

///|
/// Check a linear inequality on a complete or partial assignment.
fn check_linear_bound(
  values : Array[Int?],
  terms : Array[(Int, Int)],
  target : Int,
  lower_bound : Bool,
) -> Bool {
  let mut minimum = 0
  let mut maximum = 0
  let mut complete = true
  for term in terms {
    let (id, coefficient) = term
    match values[id] {
      Some(value) => {
        let contribution = coefficient * value
        minimum += contribution
        maximum += contribution
      }
      None => complete = false
    }
  }
  if !complete {
    true
  } else if lower_bound {
    maximum >= target
  } else {
    minimum <= target
  }
}

///|
fn check_element(
  values : Array[Int?],
  index : Int,
  table_values : Array[Int],
  result : Int,
) -> Bool {
  match (values[index], values[result]) {
    (Some(position), Some(value)) =>
      position >= 0 &&
      position < table_values.length() &&
      table_values[position] == value
    _ => true
  }
}

///|
fn check_count(
  values : Array[Int?],
  ids : Array[Int],
  value : Int,
  lower : Int,
  upper : Int,
) -> Bool {
  let mut found = 0
  let mut unknown = 0
  for id in ids {
    match values[id] {
      Some(candidate) => if candidate == value { found += 1 }
      None => unknown += 1
    }
  }
  found <= upper && found + unknown >= lower
}

///|
fn check_minimum(values : Array[Int?], ids : Array[Int], result : Int) -> Bool {
  match values[result] {
    Some(expected) => {
      let mut complete = true
      let mut minimum_value = 2147483647
      for id in ids {
        match values[id] {
          Some(value) => if value < minimum_value { minimum_value = value }
          None => complete = false
        }
      }
      !complete || minimum_value == expected
    }
    None => true
  }
}

///|
fn check_maximum(values : Array[Int?], ids : Array[Int], result : Int) -> Bool {
  match values[result] {
    Some(expected) => {
      let mut complete = true
      let mut maximum_value = -2147483647
      for id in ids {
        match values[id] {
          Some(value) => if value > maximum_value { maximum_value = value }
          None => complete = false
        }
      }
      !complete || maximum_value == expected
    }
    None => true
  }
}

///|
fn check_absolute(values : Array[Int?], source : Int, result : Int) -> Bool {
  match (values[source], values[result]) {
    (Some(value), Some(expected)) =>
      if value < 0 {
        -value == expected
      } else {
        value == expected
      }
    _ => true
  }
}

///|
fn check_distance(
  values : Array[Int?],
  left : Int,
  right : Int,
  distance_value : Int,
) -> Bool {
  match (values[left], values[right]) {
    (Some(a), Some(b)) => {
      let difference = a - b
      if difference < 0 {
        -difference == distance_value
      } else {
        difference == distance_value
      }
    }
    _ => true
  }
}

///|
fn check_table(
  values : Array[Int?],
  ids : Array[Int],
  rows : Array[Array[Int]],
) -> Bool {
  let mut complete = true
  for id in ids {
    if values[id] is None {
      complete = false
    }
  }
  if !complete {
    return true
  }
  for row in rows {
    let mut matches = row.length() == ids.length()
    for position, id in ids {
      match values[id] {
        Some(value) => if row[position] != value { matches = false }
        None => ()
      }
    }
    if matches {
      return true
    }
  }
  false
}

///|
fn check_no_overlap(values : Array[Int?], tasks : Array[(Int, Int)]) -> Bool {
  for left_index, left_task in tasks {
    let (left_id, left_duration) = left_task
    for right_index, right_task in tasks {
      let (right_id, right_duration) = right_task
      if left_index < right_index {
        match (values[left_id], values[right_id]) {
          (Some(left), Some(right)) =>
            if !(left + left_duration <= right || right + right_duration <= left) {
              return false
            }
          _ => ()
        }
      }
    }
  }
  true
}

///|
fn check_cumulative(
  tasks : Array[(Int, Int, Int)],
  values : Array[Int?],
  capacity : Int,
) -> Bool {
  let mut complete = true
  for task in tasks {
    let (start_id, _, _) = task
    if values[start_id] is None {
      complete = false
    }
  }
  if !complete {
    return true
  }
  let mut first = 2147483647
  let mut last = -2147483647
  for task in tasks {
    let (start_id, duration, _) = task
    match values[start_id] {
      Some(start) => {
        if start < first {
          first = start
        }
        if start + duration > last {
          last = start + duration
        }
      }
      None => ()
    }
  }
  if first >= last {
    return true
  }
  for time in first..<=last {
    let mut load = 0
    for task in tasks {
      let (start_id, duration, demand) = task
      match values[start_id] {
        Some(start) =>
          if time >= start && time < start + duration {
            load += demand
          }
        None => ()
      }
    }
    if load > capacity {
      return false
    }
  }
  true
}

///|
/// Restrict one domain and account for removed values.
fn revise_range(
  domain : Domain,
  lower : Int,
  upper : Int,
  stats : SearchStats,
) -> Revision {
  let before = domain.size()
  ignore(domain.intersect_range(lower, upper))
  let after = domain.size()
  stats.pruned_values += before - after
  if domain.is_empty() {
    RevisionContradiction
  } else if before != after {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Revise a domain against a finite allowed set.
fn revise_member(
  domain : Domain,
  allowed : Array[Int],
  stats : SearchStats,
) -> Revision {
  let before = domain.size()
  ignore(domain.intersect_values(allowed))
  let after = domain.size()
  stats.pruned_values += before - after
  if domain.is_empty() {
    RevisionContradiction
  } else if before != after {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Remove values without a support in an extensional table.
fn revise_table(
  domains : Array[Domain],
  ids : Array[Int],
  rows : Array[Array[Int]],
  stats : SearchStats,
) -> Revision {
  let mut changed = false
  for position, id in ids {
    for candidate in domains[id].values() {
      let mut supported = false
      for row in rows {
        if row.length() != ids.length() || row[position] != candidate {
          continue
        }
        let mut compatible = true
        for row_position, row_value in row {
          if !domains[ids[row_position]].contains(row_value) {
            compatible = false
          }
        }
        if compatible {
          supported = true
          break
        }
      }
      if !supported && domains[id].remove(candidate) {
        changed = true
        stats.pruned_values += 1
      }
    }
    if domains[id].is_empty() {
      return RevisionContradiction
    }
  }
  if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Propagate a weighted sum by bounds and remove unsupported values.
fn revise_linear(
  domains : Array[Domain],
  terms : Array[(Int, Int)],
  target : Int,
  stats : SearchStats,
) -> Revision {
  let mut changed = false
  for current_term in terms {
    let (current_id, current_coefficient) = current_term
    if current_coefficient == 0 {
      continue
    }
    let mut other_min = 0
    let mut other_max = 0
    for other_term in terms {
      let (other_id, other_coefficient) = other_term
      if other_id == current_id && other_coefficient == current_coefficient {
        continue
      }
      match (domains[other_id].min(), domains[other_id].max()) {
        (Some(low), Some(high)) =>
          if other_coefficient >= 0 {
            other_min += other_coefficient * low
            other_max += other_coefficient * high
          } else {
            other_min += other_coefficient * high
            other_max += other_coefficient * low
          }
        _ => return RevisionContradiction
      }
    }
    let candidate_min = if current_coefficient > 0 {
      ceil_div(target - other_max, current_coefficient)
    } else {
      ceil_div(target - other_min, current_coefficient)
    }
    let candidate_max = if current_coefficient > 0 {
      floor_div(target - other_min, current_coefficient)
    } else {
      floor_div(target - other_max, current_coefficient)
    }
    let before = domains[current_id].size()
    ignore(domains[current_id].intersect_range(candidate_min, candidate_max))
    let after = domains[current_id].size()
    stats.pruned_values += before - after
    if after == 0 {
      return RevisionContradiction
    }
    if before != after {
      changed = true
    }
  }
  if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Propagate a linear upper or lower bound using interval arithmetic.
fn revise_linear_bound(
  domains : Array[Domain],
  terms : Array[(Int, Int)],
  target : Int,
  lower_bound : Bool,
  stats : SearchStats,
) -> Revision {
  let mut changed = false
  for current_term in terms {
    let (current_id, coefficient) = current_term
    if coefficient == 0 {
      continue
    }
    let mut other_min = 0
    let mut other_max = 0
    for other_term in terms {
      let (other_id, other_coefficient) = other_term
      if other_id == current_id && other_coefficient == coefficient {
        continue
      }
      match (domains[other_id].min(), domains[other_id].max()) {
        (Some(low), Some(high)) =>
          if other_coefficient >= 0 {
            other_min += other_coefficient * low
            other_max += other_coefficient * high
          } else {
            other_min += other_coefficient * high
            other_max += other_coefficient * low
          }
        _ => return RevisionContradiction
      }
    }
    let (lower, upper) = if lower_bound {
      if coefficient > 0 {
        (ceil_div(target - other_max, coefficient), 2147483647)
      } else {
        (-2147483647, floor_div(target - other_max, coefficient))
      }
    } else if coefficient > 0 {
      (-2147483647, floor_div(target - other_min, coefficient))
    } else {
      (ceil_div(target - other_min, coefficient), 2147483647)
    }
    let before = domains[current_id].size()
    ignore(domains[current_id].intersect_range(lower, upper))
    let after = domains[current_id].size()
    stats.pruned_values += before - after
    if after == 0 {
      return RevisionContradiction
    }
    if before != after {
      changed = true
    }
  }
  if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Mathematical floor division for integers, including negative operands.
fn floor_div(numerator : Int, denominator : Int) -> Int {
  if denominator == 0 {
    return 0
  }
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  if remainder != 0 && (remainder < 0) != (denominator < 0) {
    quotient - 1
  } else {
    quotient
  }
}

///|
/// Mathematical ceiling division for integers, including negative operands.
fn ceil_div(numerator : Int, denominator : Int) -> Int {
  -floor_div(-numerator, denominator)
}

///|
/// Revise a count constraint using assigned and possible occurrences.
fn revise_count(
  domains : Array[Domain],
  ids : Array[Int],
  value : Int,
  lower : Int,
  upper : Int,
  stats : SearchStats,
) -> Revision {
  let mut fixed = 0
  let mut possible = 0
  for id in ids {
    if domains[id].contains(value) {
      possible += 1
    }
    if domains[id].singleton() is Some(candidate) && candidate == value {
      fixed += 1
    }
  }
  if fixed > upper || possible < lower {
    return RevisionContradiction
  }
  let mut changed = false
  if fixed == upper {
    for id in ids {
      if domains[id].singleton() is None && domains[id].remove(value) {
        changed = true
        stats.pruned_values += 1
      }
    }
  }
  if possible == lower {
    for id in ids {
      if domains[id].contains(value) && domains[id].singleton() is None {
        let before = domains[id].size()
        ignore(domains[id].assign(value))
        let after = domains[id].size()
        stats.pruned_values += before - after
        if before != after {
          changed = true
        }
      }
    }
  }
  for id in ids {
    if domains[id].is_empty() {
      return RevisionContradiction
    }
  }
  if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Revise an element constraint in both directions.
fn revise_element(
  domains : Array[Domain],
  index : Int,
  table_values : Array[Int],
  result : Int,
  stats : SearchStats,
) -> Revision {
  let mut changed = false
  for position in domains[index].values() {
    if position < 0 ||
      position >= table_values.length() ||
      !domains[result].contains(table_values[position]) {
      if domains[index].remove(position) {
        changed = true
        stats.pruned_values += 1
      }
    }
  }
  for candidate in domains[result].values() {
    let mut supported = false
    for position in domains[index].values() {
      if position >= 0 &&
        position < table_values.length() &&
        table_values[position] == candidate {
        supported = true
        break
      }
    }
    if !supported && domains[result].remove(candidate) {
      changed = true
      stats.pruned_values += 1
    }
  }
  if domains[index].is_empty() || domains[result].is_empty() {
    RevisionContradiction
  } else if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Revise minimum/maximum result bounds.
fn revise_extreme(
  domains : Array[Domain],
  ids : Array[Int],
  result : Int,
  minimum_result : Bool,
  stats : SearchStats,
) -> Revision {
  if ids.length() == 0 {
    return RevisionContradiction
  }
  let mut lower = 2147483647
  let mut upper = -2147483647
  for id in ids {
    match (domains[id].min(), domains[id].max()) {
      (Some(low), Some(high)) =>
        if minimum_result {
          if low < lower {
            lower = low
          }
          if high < upper || upper == -2147483647 {
            upper = high
          }
        } else {
          if low > lower || lower == 2147483647 {
            lower = low
          }
          if high > upper {
            upper = high
          }
        }
      _ => return RevisionContradiction
    }
  }
  revise_range(domains[result], lower, upper, stats)
}

///|
/// Revise a single posted constraint.
fn revise_constraint(
  constraint : Constraint,
  domains : Array[Domain],
  stats : SearchStats,
) -> Revision {
  match constraint {
    Equal(left, right) =>
      revise_binary(domains[left], domains[right], RelationEqual)
    NotEqual(left, right) =>
      revise_binary(domains[left], domains[right], RelationNotEqual)
    LessThan(left, right) =>
      revise_binary(domains[left], domains[right], RelationLessThan)
    LessEqual(left, right) =>
      revise_binary(domains[left], domains[right], RelationLessEqual)
    GreaterThan(left, right) =>
      revise_binary(domains[left], domains[right], RelationGreaterThan)
    GreaterEqual(left, right) =>
      revise_binary(domains[left], domains[right], RelationGreaterEqual)
    AllDifferent(ids) => {
      let mut changed = false
      let fixed = Set([])
      for id in ids {
        match domains[id].singleton() {
          Some(value) =>
            if fixed.contains(value) {
              return RevisionContradiction
            } else {
              fixed.add(value)
            }
          None => ()
        }
      }
      for id in ids {
        if domains[id].singleton() is None {
          for value in fixed.to_array() {
            if domains[id].remove(value) {
              changed = true
              stats.pruned_values += 1
            }
          }
        }
        if domains[id].is_empty() {
          return RevisionContradiction
        }
      }
      if changed {
        RevisionChanged
      } else {
        RevisionStable
      }
    }
    Sum(ids, target) =>
      revise_linear(domains, ids.map(id => (id, 1)), target, stats)
    Element(index, table_values, result) =>
      revise_element(domains, index, table_values, result, stats)
    Linear(terms, target) => revise_linear(domains, terms, target, stats)
    LinearLessEqual(terms, target) =>
      revise_linear_bound(domains, terms, target, false, stats)
    LinearGreaterEqual(terms, target) =>
      revise_linear_bound(domains, terms, target, true, stats)
    Between(variable, lower, upper) =>
      revise_range(domains[variable], lower, upper, stats)
    Member(variable, allowed) =>
      revise_member(domains[variable], allowed, stats)
    CountValue(ids, value, count) =>
      revise_count(domains, ids, value, count, count, stats)
    AtMostValue(ids, value, count) =>
      revise_count(domains, ids, value, 0, count, stats)
    AtLeastValue(ids, value, count) =>
      revise_count(domains, ids, value, count, ids.length(), stats)
    Minimum(ids, result) => revise_extreme(domains, ids, result, true, stats)
    Maximum(ids, result) => revise_extreme(domains, ids, result, false, stats)
    Absolute(source, result) => revise_absolute(domains, source, result, stats)
    Distance(left, right, distance_value) =>
      revise_distance(domains, left, right, distance_value, stats)
    // The complement of an exact distance is non-convex.  Deferring it to
    // complete-assignment checking avoids unsound domain pruning; the search
    // loop still enforces the relation before accepting a solution.
    NotDistance(_, _, _) => RevisionStable
    Table(ids, rows) => revise_table(domains, ids, rows, stats)
    NoOverlap(tasks) => revise_no_overlap(domains, tasks, stats)
    Cumulative(_, _) => RevisionStable
  }
}

///|
fn revise_absolute(
  domains : Array[Domain],
  source : Int,
  result : Int,
  stats : SearchStats,
) -> Revision {
  let possible : Array[Int] = []
  for value in domains[source].values() {
    let absolute_value = if value < 0 { -value } else { value }
    if !possible.contains(absolute_value) {
      possible.push(absolute_value)
    }
  }
  let mut result_revision = revise_member(domains[result], possible, stats)
  if result_revision is RevisionContradiction {
    return result_revision
  }
  for value in domains[source].values() {
    let absolute_value = if value < 0 { -value } else { value }
    if !domains[result].contains(absolute_value) &&
      domains[source].remove(value) {
      stats.pruned_values += 1
      result_revision = RevisionChanged
    }
  }
  if domains[source].is_empty() {
    RevisionContradiction
  } else {
    result_revision
  }
}

///|
fn revise_distance(
  domains : Array[Domain],
  left : Int,
  right : Int,
  distance_value : Int,
  stats : SearchStats,
) -> Revision {
  let mut changed = false
  for value in domains[left].values() {
    let mut supported = false
    for other in domains[right].values() {
      let difference = value - other
      let absolute_difference = if difference < 0 {
        -difference
      } else {
        difference
      }
      if absolute_difference == distance_value {
        supported = true
      }
    }
    if !supported && domains[left].remove(value) {
      changed = true
      stats.pruned_values += 1
    }
  }
  for other in domains[right].values() {
    let mut supported = false
    for value in domains[left].values() {
      let difference = value - other
      let absolute_difference = if difference < 0 {
        -difference
      } else {
        difference
      }
      if absolute_difference == distance_value {
        supported = true
      }
    }
    if !supported && domains[right].remove(other) {
      changed = true
      stats.pruned_values += 1
    }
  }
  if domains[left].is_empty() || domains[right].is_empty() {
    RevisionContradiction
  } else if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
fn revise_no_overlap(
  domains : Array[Domain],
  tasks : Array[(Int, Int)],
  stats : SearchStats,
) -> Revision {
  let mut changed = false
  for left_index, left_task in tasks {
    let (left_id, left_duration) = left_task
    for right_index, right_task in tasks {
      let (right_id, right_duration) = right_task
      if left_index >= right_index {
        continue
      }
      for left in domains[left_id].values() {
        let mut supported = false
        for right in domains[right_id].values() {
          if left + left_duration <= right || right + right_duration <= left {
            supported = true
            break
          }
        }
        if !supported && domains[left_id].remove(left) {
          changed = true
          stats.pruned_values += 1
        }
      }
      for right in domains[right_id].values() {
        let mut supported = false
        for left in domains[left_id].values() {
          if left + left_duration <= right || right + right_duration <= left {
            supported = true
            break
          }
        }
        if !supported && domains[right_id].remove(right) {
          changed = true
          stats.pruned_values += 1
        }
      }
    }
  }
  for task in tasks {
    let (id, _) = task
    if domains[id].is_empty() {
      return RevisionContradiction
    }
  }
  if changed {
    RevisionChanged
  } else {
    RevisionStable
  }
}

///|
/// Propagate all constraints to a fixpoint.
fn Solver::propagate(
  self : Solver,
  domains : Array[Domain],
  config : SearchConfig,
  stats : SearchStats,
) -> Bool {
  let mut round = 0
  let mut changed = true
  while changed && round < config.propagation_rounds {
    round += 1
    stats.propagations += 1
    changed = false
    for constraint in self.constraints {
      stats.constraint_checks += 1
      match revise_constraint(constraint, domains, stats) {
        RevisionContradiction => return false
        RevisionChanged => changed = true
        RevisionStable => ()
      }
    }
  }
  if round >= config.propagation_rounds && changed {
    stats.restarts += 1
  }
  for domain in domains {
    if domain.is_empty() {
      return false
    }
  }
  let values = singleton_values(domains)
  for constraint in self.constraints {
    if !check_constraint(constraint, values) {
      return false
    }
  }
  true
}

///|
/// Count how many constraints mention a variable.
fn variable_degree(constraints : Array[Constraint], variable : Int) -> Int {
  let mut degree = 0
  for constraint in constraints {
    if constraint_mentions(constraint, variable) {
      degree += 1
    }
  }
  degree
}

///|
/// Test whether a constraint references a variable.
fn constraint_mentions(constraint : Constraint, variable : Int) -> Bool {
  match constraint {
    Equal(left, right)
    | NotEqual(left, right)
    | LessThan(left, right)
    | LessEqual(left, right)
    | GreaterThan(left, right)
    | GreaterEqual(left, right) => left == variable || right == variable
    AllDifferent(ids)
    | Sum(ids, _)
    | CountValue(ids, _, _)
    | AtMostValue(ids, _, _)
    | AtLeastValue(ids, _, _)
    | Minimum(ids, _)
    | Maximum(ids, _) => ids.contains(variable)
    Element(index, _, result)
    | Distance(index, result, _)
    | NotDistance(index, result, _) => index == variable || result == variable
    Linear(terms, _)
    | LinearLessEqual(terms, _)
    | LinearGreaterEqual(terms, _) =>
      terms.any(term => {
        let (id, _) = term
        id == variable
      })
    Between(id, _, _) | Member(id, _) | Absolute(id, _) => id == variable
    Table(ids, _) => ids.contains(variable)
    NoOverlap(tasks) =>
      tasks.any(task => {
        let (id, _) = task
        id == variable
      })
    Cumulative(tasks, _) =>
      tasks.any(task => {
        let (id, _, _) = task
        id == variable
      })
  }
}

///|
/// Select one unassigned variable according to the configured heuristic.
fn Solver::choose_variable(
  self : Solver,
  domains : Array[Domain],
  config : SearchConfig,
) -> Int? {
  let mut selected : Int? = None
  let mut selected_size = 2147483647
  let mut selected_degree = -1
  for id, _ in self.variables {
    if domains[id].is_singleton() {
      continue
    }
    let size = domains[id].size()
    let degree = variable_degree(self.constraints, id)
    let better = match config.variable_heuristic {
      MinimumRemainingValues => size < selected_size
      FirstUnassigned => selected is None
      MaximumDegree => degree > selected_degree || selected is None
      DomOverDegree =>
        selected is None ||
        size * (selected_degree + 1) < selected_size * (degree + 1)
    }
    if better {
      selected = Some(id)
      selected_size = size
      selected_degree = degree
    }
  }
  selected
}

///|
/// Order candidates without relying on backend-specific sorting behavior.
fn order_values(values : Array[Int], heuristic : ValueHeuristic) -> Array[Int] {
  match heuristic {
    AscendingValues => values
    DescendingValues => {
      let result : Array[Int] = []
      let last = values.length() - 1
      for index in last>=..0 {
        result.push(values[index])
      }
      result
    }
    MedianFirst => {
      let result : Array[Int] = []
      if values.length() == 0 {
        return result
      }
      let middle = values.length() / 2
      result.push(values[middle])
      for offset in 1..<=values.length() {
        let right = middle + offset
        let left = middle - offset
        if right < values.length() {
          result.push(values[right])
        }
        if left >= 0 {
          result.push(values[left])
        }
      }
      result
    }
  }
}

///|
/// Search one node after propagation.
fn Solver::search_node(
  self : Solver,
  domains : Array[Domain],
  output : Array[Solution],
  depth : Int,
  config : SearchConfig,
  stats : SearchStats,
) -> Unit {
  if output.length() >= config.max_solutions {
    return
  }
  if stats.nodes >= config.node_limit {
    stats.truncated = true
    return
  }
  stats.nodes += 1
  if depth > stats.maximum_depth {
    stats.maximum_depth = depth
  }
  if !self.propagate(domains, config, stats) {
    stats.failures += 1
    if config.enable_learning {
      stats.learned_conflicts += 1
    }
    return
  }
  match self.choose_variable(domains, config) {
    None => {
      let values = domains.map(domain => {
        match domain.min() {
          Some(value) => value
          None => 0
        }
      })
      output.push({ values, })
      stats.solutions += 1
    }
    Some(variable) => {
      let candidates = order_values(
        domains[variable].values(),
        config.value_heuristic,
      )
      for candidate in candidates {
        if output.length() >= config.max_solutions {
          break
        }
        let child = clone_domains(domains)
        if child[variable].assign(candidate) {
          self.search_node(child, output, depth + 1, config, stats)
        } else {
          stats.failures += 1
        }
      }
    }
  }
}

///|
/// Solve with an explicit configuration.
pub fn Solver::solve_with(
  self : Solver,
  config : SearchConfig,
) -> Array[Solution] {
  let actual_limit = if config.max_solutions < 1 {
    1
  } else {
    config.max_solutions
  }
  let actual_config = config.limit(actual_limit)
  self.last_stats = empty_search_stats()
  let domains = self.variables.map(variable => variable.domain.clone())
  let output : Array[Solution] = []
  self.search_node(domains, output, 0, actual_config, self.last_stats)
  output
}

///|
/// Find up to the configured number of solutions using propagation and MRV.
pub fn Solver::solve_all(self : Solver) -> Array[Solution] {
  self.solve_with(self.search_config.limit(self.max_solutions))
}

///|
/// Find one solution, if the model is satisfiable.
pub fn Solver::solve(self : Solver) -> Solution? {
  self.limit(1)
  self.solve_all().get(0)
}

///|
/// Enumerate solutions and return the one with the best objective value.
pub fn Solver::optimize(
  self : Solver,
  variable : Int,
  direction : OptimizationDirection,
) -> OptimizationResult? {
  self.validate_variable(variable)
  let config = self.search_config.limit(2147483647)
  let solutions = self.solve_with(config)
  match solutions.get(0) {
    None => None
    Some(first) => {
      let mut best = first
      let mut best_value = first.get(variable)
      for candidate in solutions {
        let value = candidate.get(variable)
        let better = match direction {
          MinimizeValue => value < best_value
          MaximizeValue => value > best_value
        }
        if better {
          best = candidate
          best_value = value
        }
      }
      Some({ solution: best, objective: best_value })
    }
  }
}

///|
/// Check a variable identifier and fail early with a useful model error.
fn Solver::validate_variable(self : Solver, variable : Int) -> Unit {
  if variable < 0 || variable >= self.variables.length() {
    abort("constraint references an unknown variable")
  }
}

///|
/// Validate a constraint before storing it in the model.
fn Solver::validate_constraint(self : Solver, constraint : Constraint) -> Unit {
  let validate_ids = (ids : Array[Int]) => {
    for id in ids {
      self.validate_variable(id)
    }
  }
  match constraint {
    Equal(left, right)
    | NotEqual(left, right)
    | LessThan(left, right)
    | LessEqual(left, right)
    | GreaterThan(left, right)
    | GreaterEqual(left, right) => validate_ids([left, right])
    AllDifferent(ids)
    | Sum(ids, _)
    | CountValue(ids, _, _)
    | AtMostValue(ids, _, _)
    | AtLeastValue(ids, _, _)
    | Minimum(ids, _)
    | Maximum(ids, _) => validate_ids(ids)
    Element(index, _, result)
    | Distance(index, result, _)
    | NotDistance(index, result, _) => validate_ids([index, result])
    Linear(terms, _)
    | LinearLessEqual(terms, _)
    | LinearGreaterEqual(terms, _) =>
      validate_ids(
        terms.map(term => {
          let (id, _) = term
          id
        }),
      )
    Between(id, _, _) | Member(id, _) | Absolute(id, _) => validate_ids([id])
    Table(ids, rows) => {
      validate_ids(ids)
      for row in rows {
        if row.length() != ids.length() {
          abort("table constraint row has the wrong arity")
        }
      }
    }
    NoOverlap(tasks) =>
      validate_ids(
        tasks.map(task => {
          let (id, _) = task
          id
        }),
      )
    Cumulative(tasks, capacity) => {
      if capacity < 0 {
        abort("cumulative capacity must not be negative")
      }
      validate_ids(
        tasks.map(task => {
          let (id, _, _) = task
          id
        }),
      )
    }
  }
}
