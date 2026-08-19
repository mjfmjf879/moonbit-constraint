///|
/// Repeatable model execution sessions.
///
/// A session records attempts, signatures, and solver counters around a model.
/// It is intended for local acceptance runs and for collecting evidence that a
/// change remains deterministic across repeated solves.
pub struct SolveAttempt {
  index : Int
  solved : Bool
  solution_count : Int
  work : Int
  signature : Int
}

///|
/// Create an attempt record.
pub fn solve_attempt(
  index : Int,
  solved : Bool,
  solution_count : Int,
  stats : SearchStats,
  signature : Int,
) -> SolveAttempt {
  {
    index,
    solved,
    solution_count,
    work: stats.node_count() +
    stats.propagation_count() +
    stats.check_count() +
    stats.pruned_count(),
    signature,
  }
}

///|
/// A repeated execution session.
pub struct SolveSession {
  name : String
  attempts : Array[SolveAttempt]
  signatures : Array[Int]
}

///|
/// Create an empty session.
pub fn solve_session(name : String) -> SolveSession {
  { name, attempts: [], signatures: [] }
}

///|
/// Execute a solver once and record its result.
pub fn SolveSession::run(
  self : SolveSession,
  solver : Solver,
  limit : Int,
) -> SolveAttempt {
  solver.limit(limit)
  let solutions = solver.solve_all()
  let signature = if solutions.length() == 0 {
    0
  } else {
    solution_signature(solutions[0])
  }
  let attempt = solve_attempt(
    self.attempts.length(),
    solutions.length() > 0,
    solutions.length(),
    solver.stats(),
    signature,
  )
  self.attempts.push(attempt)
  self.signatures.push(signature)
  attempt
}

///|
/// Return attempt count.
pub fn SolveSession::length(self : SolveSession) -> Int {
  self.attempts.length()
}

///|
/// Return attempts.
pub fn SolveSession::attempts(self : SolveSession) -> Array[SolveAttempt] {
  self.attempts.copy()
}

///|
/// Return whether all attempts solved.
pub fn SolveSession::all_solved(self : SolveSession) -> Bool {
  for attempt in self.attempts {
    if !attempt.solved {
      return false
    }
  }
  true
}

///|
/// Return whether all signatures agree.
pub fn SolveSession::deterministic(self : SolveSession) -> Bool {
  if self.signatures.length() < 2 {
    return true
  }
  for signature in self.signatures {
    if signature != self.signatures[0] {
      return false
    }
  }
  true
}

///|
/// Return total work.
pub fn SolveSession::total_work(self : SolveSession) -> Int {
  let mut result = 0
  for attempt in self.attempts {
    result += attempt.work
  }
  result
}

///|
/// Return average work.
pub fn SolveSession::average_work(self : SolveSession) -> Int {
  if self.attempts.length() == 0 {
    0
  } else {
    self.total_work() / self.attempts.length()
  }
}

///|
/// Return the largest work attempt.
pub fn SolveSession::maximum_work(self : SolveSession) -> Int {
  let mut result = 0
  for attempt in self.attempts {
    if attempt.work > result {
      result = attempt.work
    }
  }
  result
}

///|
/// Return whether work is stable within a tolerance.
pub fn SolveSession::work_stable(
  self : SolveSession,
  tolerance_percent : Int,
) -> Bool {
  if self.attempts.length() < 2 {
    return true
  }
  let baseline = self.attempts[0].work
  for attempt in self.attempts[1:] {
    if regressed(baseline, attempt.work, tolerance_percent) ||
      regressed(attempt.work, baseline, tolerance_percent) {
      return false
    }
  }
  true
}

///|
/// Return a quality review for a session.
pub fn SolveSession::review(self : SolveSession) -> QualityReview {
  let review = quality_review()
  review.require(
    "all-solved",
    self.all_solved(),
    "every attempt produced a solution",
  )
  review.require(
    "deterministic",
    self.deterministic(),
    "first solution signatures agree",
  )
  review.minimum("attempts", self.attempts.length(), 1, "at least one run")
  review
}

///|
/// Return a compact session report.
pub fn SolveSession::describe(self : SolveSession) -> String {
  "\{self.name}: attempts=\{self.attempts.length()}, solved=\{self.all_solved()}, deterministic=\{self.deterministic()}, average_work=\{self.average_work()}"
}

///|
/// Return a session fingerprint.
pub fn SolveSession::signature(self : SolveSession) -> Int {
  let mut result = 31
  for attempt in self.attempts {
    result = result * 37 + attempt.signature + attempt.work
  }
  result
}

///|
/// Return a solution fingerprint.
pub fn solution_signature(solution : Solution) -> Int {
  let mut result = 17
  for index, value in solution.values {
    result = result * 31 + value + index * 7
  }
  result
}

///|
/// Return whether two attempts agree on outcome and signature.
pub fn attempts_equal(left : SolveAttempt, right : SolveAttempt) -> Bool {
  left.solved == right.solved &&
  left.solution_count == right.solution_count &&
  left.signature == right.signature
}

///|
/// Return attempts ordered by work.
pub fn sort_attempts_by_work(
  attempts : Array[SolveAttempt],
) -> Array[SolveAttempt] {
  let result = attempts.copy()
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if result[right].work < result[left].work {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return a stable attempt line.
pub fn SolveAttempt::describe(self : SolveAttempt) -> String {
  "attempt=\{self.index}, solved=\{self.solved}, solutions=\{self.solution_count}, work=\{self.work}, signature=\{self.signature}"
}

///|
/// Return the number of distinct outcomes.
pub fn distinct_attempt_signatures(attempts : Array[SolveAttempt]) -> Int {
  let signatures : Array[Int] = []
  for attempt in attempts {
    if !signatures.contains(attempt.signature) {
      signatures.push(attempt.signature)
    }
  }
  signatures.length()
}
