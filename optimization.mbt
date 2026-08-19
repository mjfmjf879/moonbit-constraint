///|
/// One lexicographic objective component.
pub struct ObjectiveTerm {
  variable : Int
  direction : OptimizationDirection
  weight : Int
}

///|
/// Create an objective component with a non-zero weight.
pub fn objective_term(
  variable : Int,
  direction : OptimizationDirection,
  weight : Int,
) -> ObjectiveTerm {
  { variable, direction, weight: if weight == 0 { 1 } else { weight } }
}

///|
/// Read an objective variable identifier.
pub fn ObjectiveTerm::variable(self : ObjectiveTerm) -> Int {
  self.variable
}

///|
/// Read an objective direction.
pub fn ObjectiveTerm::direction(self : ObjectiveTerm) -> OptimizationDirection {
  self.direction
}

///|
/// Read the objective weight.
pub fn ObjectiveTerm::weight(self : ObjectiveTerm) -> Int {
  self.weight
}

///|
/// A multi-component objective used by application adapters.
pub struct Objective {
  terms : Array[ObjectiveTerm]
}

///|
/// Construct an objective from ordered terms.
pub fn objective(terms : Array[ObjectiveTerm]) -> Objective {
  { terms: terms.copy() }
}

///|
/// Construct a one-variable objective.
pub fn single_objective(
  variable : Int,
  direction : OptimizationDirection,
) -> Objective {
  objective([objective_term(variable, direction, 1)])
}

///|
/// Append a lower-priority objective component.
pub fn Objective::then(
  self : Objective,
  variable : Int,
  direction : OptimizationDirection,
  weight : Int,
) -> Objective {
  self.terms.push(objective_term(variable, direction, weight))
  self
}

///|
/// Return objective terms.
pub fn Objective::terms(self : Objective) -> Array[ObjectiveTerm] {
  self.terms.copy()
}

///|
/// Return the tuple of objective values for a solution.
pub fn Objective::values(self : Objective, solution : Solution) -> Array[Int] {
  self.terms.map(term => solution.get(term.variable))
}

///|
/// Calculate a weighted scalar score.
pub fn Objective::score(self : Objective, solution : Solution) -> Int {
  let mut score = 0
  for term in self.terms {
    let value = solution.get(term.variable)
    match term.direction {
      MinimizeValue => score -= value * term.weight
      MaximizeValue => score += value * term.weight
    }
  }
  score
}

///|
/// Return whether `candidate` is preferred to `incumbent` lexicographically.
pub fn Objective::is_better(
  self : Objective,
  candidate : Solution,
  incumbent : Solution,
) -> Bool {
  for term in self.terms {
    let candidate_value = candidate.get(term.variable)
    let incumbent_value = incumbent.get(term.variable)
    if candidate_value == incumbent_value {
      continue
    }
    match term.direction {
      MinimizeValue => return candidate_value < incumbent_value
      MaximizeValue => return candidate_value > incumbent_value
    }
  }
  false
}

///|
/// Return the preferred solution from a non-empty array.
pub fn Objective::best(
  self : Objective,
  solutions : Array[Solution],
) -> Solution? {
  match solutions.get(0) {
    None => None
    Some(first) => {
      let mut best = first
      for solution in solutions {
        if self.is_better(solution, best) {
          best = solution
        }
      }
      Some(best)
    }
  }
}

///|
/// A score paired with a solution for reporting and ranking.
pub struct ScoredSolution {
  solution : Solution
  score : Int
  rank : Int
}

///|
/// Build a scored solution.
pub fn scored_solution(
  solution : Solution,
  score : Int,
  rank : Int,
) -> ScoredSolution {
  { solution, score, rank }
}

///|
/// Return the underlying solution.
pub fn ScoredSolution::solution(self : ScoredSolution) -> Solution {
  self.solution
}

///|
/// Return the scalar score.
pub fn ScoredSolution::score(self : ScoredSolution) -> Int {
  self.score
}

///|
/// Return the one-based display rank.
pub fn ScoredSolution::rank(self : ScoredSolution) -> Int {
  self.rank
}

///|
/// Return a stable score report.
pub fn ScoredSolution::describe(self : ScoredSolution) -> String {
  "rank=\{self.rank}, score=\{self.score}, values=\{Repr(self.solution.values)}"
}

///|
/// Enumerate and rank solutions by a multi-component objective.
pub fn Solver::ranked_solutions(
  self : Solver,
  objective : Objective,
  limit : Int,
) -> Array[ScoredSolution] {
  self.limit(if limit < 1 { 1 } else { limit })
  let solutions = self.solve_all()
  let ranked : Array[Solution] = solutions.copy()
  ranked.sort_by((left, right) => {
    if objective.is_better(left, right) {
      -1
    } else if objective.is_better(right, left) {
      1
    } else {
      0
    }
  })
  let result : Array[ScoredSolution] = []
  for index, solution in ranked {
    result.push(scored_solution(solution, objective.score(solution), index + 1))
  }
  result
}

///|
/// Return the best solution after bounded enumeration.
pub fn Solver::best_solution(
  self : Solver,
  objective : Objective,
  limit : Int,
) -> ScoredSolution? {
  self.ranked_solutions(objective, limit).get(0)
}

///|
/// Return whether a solution dominates another over all objective terms.
pub fn Objective::dominates(
  self : Objective,
  candidate : Solution,
  other : Solution,
) -> Bool {
  let mut strictly_better = false
  for term in self.terms {
    let left = candidate.get(term.variable)
    let right = other.get(term.variable)
    match term.direction {
      MinimizeValue => {
        if left > right {
          return false
        }
        if left < right {
          strictly_better = true
        }
      }
      MaximizeValue => {
        if left < right {
          return false
        }
        if left > right {
          strictly_better = true
        }
      }
    }
  }
  strictly_better
}

///|
/// Filter a solution set to its Pareto frontier.
pub fn Objective::pareto_front(
  self : Objective,
  solutions : Array[Solution],
) -> Array[Solution] {
  let result : Array[Solution] = []
  for candidate in solutions {
    let mut dominated = false
    for other in solutions {
      if self.dominates(other, candidate) {
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
/// Return a simple objective summary.
pub fn Objective::describe(self : Objective) -> String {
  let builder = StringBuilder()
  for index, term in self.terms {
    if index > 0 {
      builder.write_string(" then ")
    }
    let direction = match term.direction {
      MinimizeValue => "min"
      MaximizeValue => "max"
    }
    builder.write_string("\{direction}(v\{term.variable})*\{term.weight}")
  }
  builder.to_string()
}

///|
/// Build a lexicographic objective from parallel arrays.
pub fn objective_from_directions(
  variables : Array[Int],
  directions : Array[OptimizationDirection],
) -> Objective? {
  if variables.length() != directions.length() || variables.length() == 0 {
    return None
  }
  let terms : Array[ObjectiveTerm] = []
  for index in 0..<variables.length() {
    terms.push(objective_term(variables[index], directions[index], 1))
  }
  Some(objective(terms))
}

///|
/// Return a score for a schedule preference set.
pub fn score_preferences(
  solution : Solution,
  variables : Array[Int],
  preferred : Array[Int],
  penalty : Array[Int],
) -> Int {
  if variables.length() != preferred.length() ||
    variables.length() != penalty.length() {
    return 2147483647
  }
  let mut score = 0
  for index in 0..<variables.length() {
    if solution.get(variables[index]) != preferred[index] {
      score += penalty[index]
    }
  }
  score
}
