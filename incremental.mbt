///|
/// A value decision that can be applied to an existing model without
/// rebuilding its constraints.
pub struct Assumption {
  variable : Int
  value : Int
} derive(Debug, Eq)

///|
/// Construct a variable/value decision.
pub fn assumption(variable : Int, value : Int) -> Assumption {
  { variable, value }
}

///|
/// Return the variable referenced by a decision.
pub fn Assumption::variable(self : Assumption) -> Int {
  self.variable
}

///|
/// Return the value required by a decision.
pub fn Assumption::value(self : Assumption) -> Int {
  self.value
}

///|
/// Render a decision in a stable diagnostic form.
pub fn Assumption::describe(self : Assumption) -> String {
  "v\{self.variable}=\{self.value}"
}

///|
/// An ordered set of decisions used for incremental probes.
pub struct AssumptionSet {
  items : Array[Assumption]
}

///|
/// Create an empty assumption set.
pub fn assumptions() -> AssumptionSet {
  { items: [] }
}

///|
/// Create an assumption set from an array. Duplicate variables are rejected
/// by retaining the first decision and ignoring later duplicates.
pub fn assumptions_from(items : Array[Assumption]) -> AssumptionSet {
  let result = assumptions()
  for item in items {
    ignore(result.add(item))
  }
  result
}

///|
/// Add a decision when its variable is not already present.
pub fn AssumptionSet::add(self : AssumptionSet, item : Assumption) -> Bool {
  for existing in self.items {
    if existing.variable == item.variable {
      return false
    }
  }
  self.items.push(item)
  true
}

///|
/// Add a variable/value pair when its variable is not already present.
pub fn AssumptionSet::add_value(
  self : AssumptionSet,
  variable : Int,
  value : Int,
) -> Bool {
  self.add(assumption(variable, value))
}

///|
/// Number of decisions in the set.
pub fn AssumptionSet::length(self : AssumptionSet) -> Int {
  self.items.length()
}

///|
/// Whether the set has no decisions.
pub fn AssumptionSet::is_empty(self : AssumptionSet) -> Bool {
  self.items.length() == 0
}

///|
/// Return a copy of the decisions.
pub fn AssumptionSet::values(self : AssumptionSet) -> Array[Assumption] {
  self.items.copy()
}

///|
/// Find a decision for a variable.
pub fn AssumptionSet::get(self : AssumptionSet, variable : Int) -> Assumption? {
  for item in self.items {
    if item.variable == variable {
      return Some(item)
    }
  }
  None
}

///|
/// Test whether the set contains a variable/value pair.
pub fn AssumptionSet::contains(
  self : AssumptionSet,
  variable : Int,
  value : Int,
) -> Bool {
  match self.get(variable) {
    Some(item) => item.value == value
    None => false
  }
}

///|
/// Render decisions in insertion order.
pub fn AssumptionSet::describe(self : AssumptionSet) -> String {
  let builder = StringBuilder()
  builder.write_char('[')
  for index, item in self.items {
    if index > 0 {
      builder.write_string(", ")
    }
    builder.write_string(item.describe())
  }
  builder.write_char(']')
  builder.to_string()
}

///|
/// A reversible copy of the variable domains and search settings.
pub struct ModelSnapshot {
  domains : Array[Domain]
  max_solutions : Int
  search_config : SearchConfig
}

///|
/// Save the current domains and search configuration.
pub fn Solver::snapshot(self : Solver) -> ModelSnapshot {
  {
    domains: self.variables.map(variable => variable.domain.clone()),
    max_solutions: self.max_solutions,
    search_config: self.search_config,
  }
}

///|
/// Restore a snapshot captured from this solver's variable layout.
pub fn Solver::restore(self : Solver, snapshot : ModelSnapshot) -> Unit {
  if snapshot.domains.length() != self.variables.length() {
    abort("snapshot variable count does not match solver")
  }
  for id, domain in snapshot.domains {
    self.variables[id].domain.restore(domain)
  }
  self.max_solutions = snapshot.max_solutions
  self.search_config = snapshot.search_config
}

///|
/// Return the number of variables in a snapshot.
pub fn ModelSnapshot::variable_count(self : ModelSnapshot) -> Int {
  self.domains.length()
}

///|
/// Return a copy of a saved domain.
pub fn ModelSnapshot::domain_of(self : ModelSnapshot, variable : Int) -> Domain {
  self.domains[variable].clone()
}

///|
/// Render the saved domain state.
pub fn ModelSnapshot::describe(self : ModelSnapshot) -> String {
  let builder = StringBuilder()
  for id, domain in self.domains {
    if id > 0 {
      builder.write_char('\n')
    }
    builder.write_string("v\{id}=\{domain.describe()}")
  }
  builder.to_string()
}

///|
/// The result of a satisfiability probe under temporary decisions.
pub struct AssumptionResult {
  satisfiable : Bool
  solution : Solution?
  stats : SearchStats
  assumptions : AssumptionSet
}

///|
/// Whether the probe found a solution.
pub fn AssumptionResult::satisfiable(self : AssumptionResult) -> Bool {
  self.satisfiable
}

///|
/// Return the first solution found by the probe.
pub fn AssumptionResult::solution(self : AssumptionResult) -> Solution? {
  self.solution
}

///|
/// Return search counters for the probe.
pub fn AssumptionResult::stats(self : AssumptionResult) -> SearchStats {
  self.stats
}

///|
/// Return the decisions used by the probe.
pub fn AssumptionResult::assumptions(self : AssumptionResult) -> AssumptionSet {
  self.assumptions
}

///|
/// Render a compact probe result.
pub fn AssumptionResult::describe(self : AssumptionResult) -> String {
  let status = if self.satisfiable { "sat" } else { "unsat" }
  "\{status} \{self.assumptions.describe()} nodes=\{self.stats.node_count()} failures=\{self.stats.failure_count()}"
}

///|
/// Apply a set of decisions, solve once, and restore every original domain.
pub fn Solver::solve_with_assumptions(
  self : Solver,
  set : AssumptionSet,
) -> AssumptionResult {
  let saved = self.snapshot()
  let mut applicable = true
  for item in set.items {
    self.validate_variable(item.variable)
    if !self.assign(item.variable, item.value) {
      applicable = false
    }
  }
  let solution = if applicable { self.solve() } else { None }
  let result = {
    satisfiable: solution is Some(_),
    solution,
    stats: self.stats(),
    assumptions: assumptions_from(set.items),
  }
  self.restore(saved)
  result
}

///|
/// Enumerate solutions under temporary decisions.
pub fn Solver::solve_all_with_assumptions(
  self : Solver,
  set : AssumptionSet,
  limit : Int,
) -> Array[Solution] {
  let saved = self.snapshot()
  let mut applicable = true
  for item in set.items {
    self.validate_variable(item.variable)
    if !self.assign(item.variable, item.value) {
      applicable = false
    }
  }
  let result = if applicable {
    self.limit(limit)
    self.solve_all()
  } else {
    []
  }
  self.restore(saved)
  result
}

///|
/// Test a temporary decision set without exposing a solution.
pub fn Solver::is_consistent_with(self : Solver, set : AssumptionSet) -> Bool {
  self.solve_with_assumptions(set).satisfiable
}

///|
/// Build a set with one item omitted.
fn omit_assumption(items : Array[Assumption], omitted : Int) -> AssumptionSet {
  let result = assumptions()
  for index, item in items {
    if index != omitted {
      ignore(result.add(item))
    }
  }
  result
}

///|
/// A deletion-based conflict report for a set of temporary decisions.
pub struct ConflictReport {
  satisfiable : Bool
  core : AssumptionSet
  probes : Int
  original_size : Int
}

///|
/// Whether the complete decision set is satisfiable.
pub fn ConflictReport::satisfiable(self : ConflictReport) -> Bool {
  self.satisfiable
}

///|
/// Return the irreducible-by-deletion conflict subset.
pub fn ConflictReport::core(self : ConflictReport) -> AssumptionSet {
  self.core
}

///|
/// Return the number of solver probes used to derive the report.
pub fn ConflictReport::probes(self : ConflictReport) -> Int {
  self.probes
}

///|
/// Return the number of decisions initially examined.
pub fn ConflictReport::original_size(self : ConflictReport) -> Int {
  self.original_size
}

///|
/// Render the report for logs or a diagnostics page.
pub fn ConflictReport::describe(self : ConflictReport) -> String {
  let status = if self.satisfiable { "sat" } else { "unsat" }
  "\{status}: core=\{self.core.describe()}, probes=\{self.probes}, original=\{self.original_size}"
}

///|
/// Find a deletion-minimal subset that still makes the model unsatisfiable.
/// The operation is deliberately conservative: it only removes an item when
/// the remaining set is still unsatisfiable.
pub fn Solver::explain_assumptions(
  self : Solver,
  set : AssumptionSet,
) -> ConflictReport {
  let initial = self.solve_with_assumptions(set)
  if initial.satisfiable {
    return {
      satisfiable: true,
      core: assumptions_from(set.items),
      probes: 1,
      original_size: set.length(),
    }
  }
  let mut core = set.values()
  let mut probes = 1
  let mut index = 0
  while index < core.length() {
    let candidate = omit_assumption(core, index)
    let probe = self.solve_with_assumptions(candidate)
    probes += 1
    if !probe.satisfiable {
      let shortened : Array[Assumption] = []
      for item_index, item in core {
        if item_index != index {
          shortened.push(item)
        }
      }
      core = shortened
    } else {
      index += 1
    }
  }
  {
    satisfiable: false,
    core: assumptions_from(core),
    probes,
    original_size: set.length(),
  }
}

///|
/// One assignment step recorded by an incremental solving client.
pub struct DecisionStep {
  variable : Int
  value : Int
  accepted : Bool
  depth : Int
}

///|
/// Construct a decision record.
pub fn decision_step(
  variable : Int,
  value : Int,
  accepted : Bool,
  depth : Int,
) -> DecisionStep {
  { variable, value, accepted, depth }
}

///|
/// Read the variable in a decision record.
pub fn DecisionStep::variable(self : DecisionStep) -> Int {
  self.variable
}

///|
/// Read the value in a decision record.
pub fn DecisionStep::value(self : DecisionStep) -> Int {
  self.value
}

///|
/// Whether this decision remained consistent.
pub fn DecisionStep::accepted(self : DecisionStep) -> Bool {
  self.accepted
}

///|
/// Read the search depth of a decision.
pub fn DecisionStep::depth(self : DecisionStep) -> Int {
  self.depth
}

///|
/// Render a decision record.
pub fn DecisionStep::describe(self : DecisionStep) -> String {
  let status = if self.accepted { "ok" } else { "fail" }
  "depth=\{self.depth} v\{self.variable}=\{self.value} \{status}"
}

///|
/// A reusable trace assembled by a model-building client.
pub struct DecisionTrace {
  steps : Array[DecisionStep]
}

///|
/// Create an empty decision trace.
pub fn decision_trace() -> DecisionTrace {
  { steps: [] }
}

///|
/// Append a step to a trace.
pub fn DecisionTrace::record(self : DecisionTrace, step : DecisionStep) -> Unit {
  self.steps.push(step)
}

///|
/// Return the number of recorded steps.
pub fn DecisionTrace::length(self : DecisionTrace) -> Int {
  self.steps.length()
}

///|
/// Return a copy of the trace steps.
pub fn DecisionTrace::steps(self : DecisionTrace) -> Array[DecisionStep] {
  self.steps.copy()
}

///|
/// Count accepted steps.
pub fn DecisionTrace::accepted_count(self : DecisionTrace) -> Int {
  let mut count = 0
  for step in self.steps {
    if step.accepted {
      count += 1
    }
  }
  count
}

///|
/// Count rejected steps.
pub fn DecisionTrace::rejected_count(self : DecisionTrace) -> Int {
  self.length() - self.accepted_count()
}

///|
/// Return the deepest recorded decision.
pub fn DecisionTrace::maximum_depth(self : DecisionTrace) -> Int {
  let mut result = 0
  for step in self.steps {
    if step.depth > result {
      result = step.depth
    }
  }
  result
}

///|
/// Render a multiline trace.
pub fn DecisionTrace::describe(self : DecisionTrace) -> String {
  let builder = StringBuilder()
  for index, step in self.steps {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(step.describe())
  }
  builder.to_string()
}

///|
/// Create a trace from a complete solution and its variable ids.
pub fn trace_solution(ids : Array[Int], solution : Solution) -> DecisionTrace {
  let trace = decision_trace()
  for depth, id in ids {
    trace.record(decision_step(id, solution.get(id), true, depth))
  }
  trace
}

///|
/// Compare two snapshots by their available values.
pub fn snapshots_equal(left : ModelSnapshot, right : ModelSnapshot) -> Bool {
  if left.domains.length() != right.domains.length() {
    return false
  }
  for id, domain in left.domains {
    if domain.values() != right.domains[id].values() {
      return false
    }
  }
  true
}

///|
/// Return a domain delta between two saved states.
pub struct DomainDelta {
  variable : Int
  before : Domain
  after : Domain
}

///|
/// Compute changed domains between two snapshots.
pub fn snapshot_deltas(
  before : ModelSnapshot,
  after : ModelSnapshot,
) -> Array[DomainDelta] {
  if before.domains.length() != after.domains.length() {
    abort("snapshot variable counts do not match")
  }
  let result : Array[DomainDelta] = []
  for id, domain in before.domains {
    if domain.values() != after.domains[id].values() {
      result.push({
        variable: id,
        before: domain.clone(),
        after: after.domains[id].clone(),
      })
    }
  }
  result
}

///|
/// Read the variable from a domain delta.
pub fn DomainDelta::variable(self : DomainDelta) -> Int {
  self.variable
}

///|
/// Read the previous domain.
pub fn DomainDelta::before(self : DomainDelta) -> Domain {
  self.before.clone()
}

///|
/// Read the narrowed domain.
pub fn DomainDelta::after(self : DomainDelta) -> Domain {
  self.after.clone()
}

///|
/// Render a delta for propagation diagnostics.
pub fn DomainDelta::describe(self : DomainDelta) -> String {
  "v\{self.variable}: \{self.before.describe()} -> \{self.after.describe()}"
}

///|
/// Apply assumptions to a snapshot and return the resulting state.
pub fn snapshot_assume(
  snapshot : ModelSnapshot,
  set : AssumptionSet,
) -> ModelSnapshot? {
  let domains = snapshot.domains.map(domain => domain.clone())
  for item in set.items {
    if item.variable < 0 || item.variable >= domains.length() {
      return None
    }
    if !domains[item.variable].assign(item.value) {
      return None
    }
  }
  Some({
    domains,
    max_solutions: snapshot.max_solutions,
    search_config: snapshot.search_config,
  })
}

///|
/// Return all fixed values in a snapshot as variable/value assumptions.
pub fn snapshot_assumptions(snapshot : ModelSnapshot) -> AssumptionSet {
  let result = assumptions()
  for id, domain in snapshot.domains {
    match domain.singleton() {
      Some(value) => ignore(result.add_value(id, value))
      None => ()
    }
  }
  result
}

///|
/// A bounded sequence of temporary model probes.
pub struct ProbeBatch {
  results : Array[AssumptionResult]
}

///|
/// Create an empty probe batch.
pub fn probe_batch() -> ProbeBatch {
  { results: [] }
}

///|
/// Probe and record a decision set.
pub fn Solver::probe(
  self : Solver,
  batch : ProbeBatch,
  set : AssumptionSet,
) -> AssumptionResult {
  let result = self.solve_with_assumptions(set)
  batch.results.push(result)
  result
}

///|
/// Number of recorded probes.
pub fn ProbeBatch::length(self : ProbeBatch) -> Int {
  self.results.length()
}

///|
/// Return a copy of recorded probe results.
pub fn ProbeBatch::results(self : ProbeBatch) -> Array[AssumptionResult] {
  self.results.copy()
}

///|
/// Count satisfiable probes.
pub fn ProbeBatch::satisfiable_count(self : ProbeBatch) -> Int {
  let mut count = 0
  for result in self.results {
    if result.satisfiable {
      count += 1
    }
  }
  count
}

///|
/// Count unsatisfiable probes.
pub fn ProbeBatch::unsatisfiable_count(self : ProbeBatch) -> Int {
  self.length() - self.satisfiable_count()
}

///|
/// Render a probe batch for regression logs.
pub fn ProbeBatch::describe(self : ProbeBatch) -> String {
  let builder = StringBuilder()
  for index, result in self.results {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(result.describe())
  }
  builder.to_string()
}
