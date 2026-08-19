///|
/// Solution portfolio and multi-objective selection utilities.
///
/// Finite-domain models frequently have several feasible schedules. This
/// module keeps a bounded, duplicate-free portfolio, supports lexicographic
/// and Pareto selection, and records deterministic search evidence for a CLI
/// or benchmark report.
pub enum PortfolioDirection {
  Minimize
  Maximize
}

///|
/// Choose the direction for a scalar metric.
pub fn portfolio_direction(prefer_low : Bool) -> PortfolioDirection {
  if prefer_low {
    Minimize
  } else {
    Maximize
  }
}

///|
/// A named objective component.
pub struct PortfolioObjectiveTerm {
  name : String
  direction : PortfolioDirection
  weight : Int
}

///|
/// Construct an objective term.
pub fn portfolio_objective_term(
  name : String,
  direction : PortfolioDirection,
  weight : Int,
) -> PortfolioObjectiveTerm {
  { name, direction, weight: if weight < 0 { -weight } else { weight } }
}

///|
/// A scored solution record.
pub struct SolutionRecord {
  solution : Solution
  values : Array[Int]
  scores : Array[Int]
  rank : Int
}

///|
/// Build a record from a solution and score vector.
pub fn solution_record(
  solution : Solution,
  scores : Array[Int],
) -> SolutionRecord {
  { solution, values: solution.values.copy(), scores: scores.copy(), rank: -1 }
}

///|
/// Read the copied solution values.
pub fn SolutionRecord::values(self : SolutionRecord) -> Array[Int] {
  self.values.copy()
}

///|
/// Read objective scores.
pub fn SolutionRecord::scores(self : SolutionRecord) -> Array[Int] {
  self.scores.copy()
}

///|
/// Return a stable record signature.
pub fn SolutionRecord::signature(self : SolutionRecord) -> Int {
  let mut result = 23
  for value in self.values {
    result = result * 31 + value
  }
  for score in self.scores {
    result = result * 37 + score
  }
  result
}

///|
/// A bounded solution collection.
pub struct SolutionPool {
  records : Array[SolutionRecord]
  limit : Int
  terms : Array[PortfolioObjectiveTerm]
}

///|
/// Create an empty portfolio pool.
pub fn solution_pool(
  limit : Int,
  terms : Array[PortfolioObjectiveTerm],
) -> SolutionPool {
  { records: [], limit: if limit < 1 { 1 } else { limit }, terms: terms.copy() }
}

///|
/// Return the number of stored solutions.
pub fn SolutionPool::length(self : SolutionPool) -> Int {
  self.records.length()
}

///|
/// Return whether the pool is full.
pub fn SolutionPool::is_full(self : SolutionPool) -> Bool {
  self.records.length() >= self.limit
}

///|
/// Return whether a solution value vector is already stored.
pub fn SolutionPool::contains(self : SolutionPool, values : Array[Int]) -> Bool {
  for record in self.records {
    if same_int_array(record.values, values) {
      return true
    }
  }
  false
}

///|
/// Add a scored solution and keep the best bounded set.
pub fn SolutionPool::insert(
  self : SolutionPool,
  record : SolutionRecord,
) -> Bool {
  if self.contains(record.values) {
    return false
  }
  self.records.push(record)
  sort_solution_records(self.records, self.terms)
  while self.records.length() > self.limit {
    ignore(self.records.pop())
  }
  true
}

///|
/// Return copied records in objective order.
pub fn SolutionPool::records(self : SolutionPool) -> Array[SolutionRecord] {
  self.records.copy()
}

///|
/// Return the best record.
pub fn SolutionPool::best(self : SolutionPool) -> SolutionRecord? {
  if self.records.length() == 0 {
    None
  } else {
    Some(self.records[0])
  }
}

///|
/// Return the worst record currently retained.
pub fn SolutionPool::worst(self : SolutionPool) -> SolutionRecord? {
  if self.records.length() == 0 {
    None
  } else {
    Some(self.records[self.records.length() - 1])
  }
}

///|
/// Return the number of objective dimensions.
pub fn SolutionPool::objective_count(self : SolutionPool) -> Int {
  self.terms.length()
}

///|
/// Return the Pareto-nondominated records.
pub fn SolutionPool::pareto_front(self : SolutionPool) -> Array[SolutionRecord] {
  let result : Array[SolutionRecord] = []
  for candidate in self.records {
    let mut dominated = false
    for other in self.records {
      if candidate.values == other.values {
        continue
      }
      if dominates(other, candidate, self.terms) {
        dominated = true
        break
      }
    }
    if !dominated {
      result.push(candidate)
    }
  }
  result
}

///|
/// Compute objective scores from a solution using variable indices.
pub fn score_solution(
  solution : Solution,
  terms : Array[PortfolioObjectiveTerm],
) -> Array[Int] {
  let scores : Array[Int] = []
  for term in terms {
    if term.name.has_prefix("v") {
      let index = parse_solution_index(term.name)
      if index >= 0 && index < solution.values.length() {
        scores.push(solution.values[index] * term.weight)
      } else {
        scores.push(0)
      }
    } else {
      scores.push(solution.values.length() * term.weight)
    }
  }
  scores
}

///|
/// Parse an objective variable name such as v3.
fn parse_solution_index(name : String) -> Int {
  if name.length() < 2 {
    return -1
  }
  let mut result = 0
  for index in 1..<name.length() {
    match name.get_char(index) {
      Some(character) => {
        if character < '0' || character > '9' {
          return -1
        }
        result = result * 10 + character.to_int() - '0'.to_int()
      }
      None => return -1
    }
  }
  result
}

///|
/// Compare two records in configured objective order.
fn compare_records(
  left : SolutionRecord,
  right : SolutionRecord,
  terms : Array[PortfolioObjectiveTerm],
) -> Int {
  for index, term in terms {
    if index >= left.scores.length() || index >= right.scores.length() {
      continue
    }
    if left.scores[index] == right.scores[index] {
      continue
    }
    let better = if term.direction is Minimize {
      left.scores[index] < right.scores[index]
    } else {
      left.scores[index] > right.scores[index]
    }
    return if better { -1 } else { 1 }
  }
  0
}

///|
/// Sort records by stable lexicographic objective order.
fn sort_solution_records(
  records : Array[SolutionRecord],
  terms : Array[PortfolioObjectiveTerm],
) -> Unit {
  for left in 0..<records.length() {
    for right in (left + 1)..<records.length() {
      if compare_records(records[right], records[left], terms) < 0 {
        let temporary = records[left]
        records[left] = records[right]
        records[right] = temporary
      }
    }
  }
}

///|
/// Return whether one record dominates another.
fn dominates(
  left : SolutionRecord,
  right : SolutionRecord,
  terms : Array[PortfolioObjectiveTerm],
) -> Bool {
  let mut strictly_better = false
  for index, term in terms {
    if index >= left.scores.length() || index >= right.scores.length() {
      continue
    }
    let better_or_equal = if term.direction is Minimize {
      left.scores[index] <= right.scores[index]
    } else {
      left.scores[index] >= right.scores[index]
    }
    if !better_or_equal {
      return false
    }
    if left.scores[index] != right.scores[index] {
      strictly_better = true
    }
  }
  strictly_better
}

///|
/// Enumerate solutions into a bounded portfolio.
pub fn collect_solution_pool(
  solver : Solver,
  limit : Int,
  terms : Array[PortfolioObjectiveTerm],
) -> SolutionPool {
  let pool = solution_pool(limit, terms)
  solver.limit(if limit < 1 { 1 } else { limit })
  for solution in solver.solve_all() {
    ignore(
      pool.insert(solution_record(solution, score_solution(solution, terms))),
    )
  }
  pool
}

///|
/// Return a single best solution under objective terms.
pub fn best_solution(
  solver : Solver,
  terms : Array[PortfolioObjectiveTerm],
) -> Solution? {
  match collect_solution_pool(solver, 1, terms).best() {
    Some(record) => Some(record.solution)
    None => None
  }
}

///|
/// Return whether two integer assignments are equal.
pub fn same_int_array(left : Array[Int], right : Array[Int]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
/// Return Hamming distance between assignments.
pub fn assignment_hamming_distance(
  left : Array[Int],
  right : Array[Int],
) -> Int {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut result = if left.length() == right.length() { 0 } else { 1 }
  for index in 0..<limit {
    if left[index] != right[index] {
      result += 1
    }
  }
  result
}

///|
/// Return a copied solution with one variable changed.
pub fn solution_replace(
  solution : Solution,
  variable : Int,
  value : Int,
) -> Solution? {
  if variable < 0 || variable >= solution.values.length() {
    return None
  }
  let values = solution.values.copy()
  values[variable] = value
  Some({ values, })
}

///|
/// A deterministic search audit record.
pub struct PortfolioAudit {
  candidates : Int
  distinct : Int
  retained : Int
  pareto : Int
}

///|
/// Summarize a portfolio.
pub fn portfolio_audit(pool : SolutionPool) -> PortfolioAudit {
  {
    candidates: pool.records.length(),
    distinct: pool.records.length(),
    retained: pool.length(),
    pareto: pool.pareto_front().length(),
  }
}

///|
/// Read candidate count.
pub fn PortfolioAudit::candidates(self : PortfolioAudit) -> Int {
  self.candidates
}

///|
/// Read retained count.
pub fn PortfolioAudit::retained(self : PortfolioAudit) -> Int {
  self.retained
}

///|
/// Read Pareto count.
pub fn PortfolioAudit::pareto(self : PortfolioAudit) -> Int {
  self.pareto
}

///|
/// Return a stable audit summary.
pub fn PortfolioAudit::describe(self : PortfolioAudit) -> String {
  "candidates=\{self.candidates}, distinct=\{self.distinct}, retained=\{self.retained}, pareto=\{self.pareto}"
}

///|
/// Return the best score for one objective.
pub fn best_score(pool : SolutionPool, objective : Int) -> Int? {
  match pool.best() {
    Some(record) =>
      if objective < record.scores.length() {
        Some(record.scores[objective])
      } else {
        None
      }
    None => None
  }
}

///|
/// Return all records with the best primary objective.
pub fn primary_ties(pool : SolutionPool) -> Array[SolutionRecord] {
  let result : Array[SolutionRecord] = []
  match pool.best() {
    None => result
    Some(best) => {
      if best.scores.length() == 0 {
        return [best]
      }
      for record in pool.records {
        if record.scores.length() > 0 && record.scores[0] == best.scores[0] {
          result.push(record)
        }
      }
      result
    }
  }
}

///|
/// Return a pool fingerprint.
pub fn SolutionPool::signature(self : SolutionPool) -> Int {
  let mut result = self.limit * 17
  for record in self.records {
    result = result * 31 + record.signature()
  }
  result
}
