///|
/// Explain finite-domain changes in a solver-friendly form.
///
/// Explanations are deliberately data-only: callers can render them as CLI
/// diagnostics, attach them to an assumption conflict, or snapshot them in a
/// regression test without depending on mutable solver internals.
pub struct DomainChange {
  variable : Int
  before : Domain
  after : Domain
  removed : Array[Int]
  added : Array[Int]
}

///|
/// Compute a domain change.
pub fn domain_change(
  variable : Int,
  before : Domain,
  after : Domain,
) -> DomainChange {
  let removed : Array[Int] = []
  let added : Array[Int] = []
  for value in before.values() {
    if !after.contains(value) {
      removed.push(value)
    }
  }
  for value in after.values() {
    if !before.contains(value) {
      added.push(value)
    }
  }
  { variable, before: before.clone(), after: after.clone(), removed, added }
}

///|
/// Return whether a domain changed.
pub fn DomainChange::changed(self : DomainChange) -> Bool {
  self.removed.length() > 0 || self.added.length() > 0
}

///|
/// Return removed values.
pub fn DomainChange::removed_values(self : DomainChange) -> Array[Int] {
  self.removed.copy()
}

///|
/// Return added values.
pub fn DomainChange::added_values(self : DomainChange) -> Array[Int] {
  self.added.copy()
}

///|
/// Return a stable explanation.
pub fn DomainChange::describe(self : DomainChange) -> String {
  "v\{self.variable}: removed=\{self.removed.length()}, added=\{self.added.length()}, before=\{self.before.describe()}, after=\{self.after.describe()}"
}

///|
/// A reason for a domain value removal.
pub struct PruningReason {
  variable : Int
  value : Int
  constraint : String
  detail : String
}

///|
/// Create a pruning reason.
pub fn pruning_reason(
  variable : Int,
  value : Int,
  constraint : String,
  detail : String,
) -> PruningReason {
  { variable, value, constraint, detail }
}

///|
/// A collection of pruning reasons.
pub struct PruningExplanation {
  reasons : Array[PruningReason]
}

///|
/// Create an empty explanation.
pub fn pruning_explanation() -> PruningExplanation {
  { reasons: [] }
}

///|
/// Add a reason when not duplicated.
pub fn PruningExplanation::add(
  self : PruningExplanation,
  reason : PruningReason,
) -> Bool {
  for current in self.reasons {
    if current.variable == reason.variable &&
      current.value == reason.value &&
      current.constraint == reason.constraint {
      return false
    }
  }
  self.reasons.push(reason)
  true
}

///|
/// Return reason count.
pub fn PruningExplanation::length(self : PruningExplanation) -> Int {
  self.reasons.length()
}

///|
/// Return reasons for one variable.
pub fn PruningExplanation::for_variable(
  self : PruningExplanation,
  variable : Int,
) -> Array[PruningReason] {
  let result : Array[PruningReason] = []
  for reason in self.reasons {
    if reason.variable == variable {
      result.push(reason)
    }
  }
  result
}

///|
/// Return whether a value has an explanation.
pub fn PruningExplanation::explains(
  self : PruningExplanation,
  variable : Int,
  value : Int,
) -> Bool {
  for reason in self.reasons {
    if reason.variable == variable && reason.value == value {
      return true
    }
  }
  false
}

///|
/// Render reasons.
pub fn PruningExplanation::describe(self : PruningExplanation) -> String {
  let builder = StringBuilder()
  for index, reason in self.reasons {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(
      "v\{reason.variable}=\{reason.value}:\{reason.constraint}:\{reason.detail}",
    )
  }
  builder.to_string()
}

///|
/// Compare two domain arrays.
pub fn compare_domain_arrays(
  before : Array[Domain],
  after : Array[Domain],
) -> Array[DomainChange] {
  let result : Array[DomainChange] = []
  let limit = if before.length() < after.length() {
    before.length()
  } else {
    after.length()
  }
  for variable in 0..<limit {
    let change = domain_change(variable, before[variable], after[variable])
    if change.changed() {
      result.push(change)
    }
  }
  result
}

///|
/// Return a domain snapshot from a solver.
pub fn solver_domains(solver : Solver) -> Array[Domain] {
  solver.variables().map(variable => variable.domain())
}

///|
/// Return a change list between two solvers.
pub fn solver_domain_changes(
  before : Solver,
  after : Solver,
) -> Array[DomainChange] {
  compare_domain_arrays(solver_domains(before), solver_domains(after))
}

///|
/// Return values common to all domains.
pub fn common_domain_values(domains : Array[Domain]) -> IntegerSet {
  if domains.length() == 0 {
    return integer_set([])
  }
  let result = integer_set(domains[0].values())
  for value in result.values() {
    for value_domain in domains {
      if !value_domain.contains(value) {
        ignore(result.remove(value))
        break
      }
    }
  }
  result
}

///|
/// Return the union of domain candidates.
pub fn union_domain_values(domains : Array[Domain]) -> IntegerSet {
  let values : Array[Int] = []
  for value_domain in domains {
    for value in value_domain.values() {
      values.push(value)
    }
  }
  integer_set(values)
}

///|
/// Return variables with singleton domains.
pub fn singleton_domain_ids(domains : Array[Domain]) -> Array[Int] {
  let result : Array[Int] = []
  for id, value_domain in domains {
    if value_domain.singleton() is Some(_) {
      result.push(id)
    }
  }
  result
}

///|
/// Return the total number of candidate values.
pub fn domain_candidate_count(domains : Array[Domain]) -> Int {
  let mut result = 0
  for value_domain in domains {
    result += value_domain.size()
  }
  result
}

///|
/// Return a stable domain-array signature.
pub fn domain_array_signature(domains : Array[Domain]) -> Int {
  let mut result = 17
  for value_domain in domains {
    result = result * 31 +
      value_domain.interval_lower() * 3 +
      value_domain.interval_upper() * 5
    for value in value_domain.values() {
      result = result * 37 + value
    }
  }
  result
}
