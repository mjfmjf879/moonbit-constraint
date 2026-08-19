///|
/// A non-attacking N-Queens model.
pub struct NQueens {
  solver : Solver
  queens : Array[Int]
  size : Int
}

///|
/// Build an N-Queens model using all-different columns and diagonal distance
/// constraints. The model is useful as a deterministic search benchmark.
pub fn n_queens(size : Int) -> NQueens? {
  if size < 1 {
    return None
  }
  let solver = new_solver()
  let queens : Array[Int] = []
  for row in 0..<size {
    queens.push(solver.add_variable(variable("queen_\{row}", 0, size - 1)))
  }
  solver.add_constraint(all_different(queens))
  for left in 0..<size {
    for right in (left + 1)..<size {
      solver.add_constraint(
        not_distance(queens[left], queens[right], right - left),
      )
    }
  }
  Some({ solver, queens, size })
}

///|
/// Solve N-Queens once.
pub fn NQueens::solve(self : NQueens) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate up to `limit` placements.
pub fn NQueens::solve_all(self : NQueens, limit : Int) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return search counters.
pub fn NQueens::stats(self : NQueens) -> SearchStats {
  self.solver.stats()
}

///|
/// Return queen variables in row order.
pub fn NQueens::queen_ids(self : NQueens) -> Array[Int] {
  self.queens.copy()
}

///|
/// Draw a placement with `Q` and `.` characters.
pub fn NQueens::render(self : NQueens, solution : Solution) -> String {
  let builder = StringBuilder()
  for row in 0..<self.size {
    if row > 0 {
      builder.write_char('\n')
    }
    let column = solution.get(self.queens[row])
    for position in 0..<self.size {
      if position > 0 {
        builder.write_char(' ')
      }
      builder.write_char(if position == column { 'Q' } else { '.' })
    }
  }
  builder.to_string()
}

///|
/// Validate a complete N-Queens placement.
pub fn NQueens::is_valid(self : NQueens, solution : Solution) -> Bool {
  if !self.solver.is_valid_solution(solution) {
    return false
  }
  for left in 0..<self.size {
    for right in (left + 1)..<self.size {
      let delta = solution.get(self.queens[left]) -
        solution.get(self.queens[right])
      let absolute = if delta < 0 { -delta } else { delta }
      if absolute == right - left {
        return false
      }
    }
  }
  true
}

///|
/// Return the smallest known solution size that has a non-empty placement.
pub fn first_solvable_n_queens(lower : Int, upper : Int) -> Int? {
  if lower > upper {
    return None
  }
  for size in lower..<=upper {
    match n_queens(size) {
      Some(problem) => if problem.solve() is Some(_) { return Some(size) }
      None => ()
    }
  }
  None
}

///|
/// Return a canonical placement for the eight-queens example.
pub fn eight_queens_solution() -> String? {
  match n_queens(8) {
    Some(problem) =>
      match problem.solve() {
        Some(solution) => Some(problem.render(solution))
        None => None
      }
    None => None
  }
}

///|
/// Build a fixed-size N-Queens model with a preferred first row.
pub fn n_queens_with_first_column(size : Int, first_column : Int) -> NQueens? {
  match n_queens(size) {
    Some(problem) =>
      if first_column < 0 || first_column >= size {
        None
      } else if problem.solver.assign(problem.queens[0], first_column) {
        Some(problem)
      } else {
        None
      }
    None => None
  }
}

///|
/// Return a compact row-to-column representation.
pub fn NQueens::compact(self : NQueens, solution : Solution) -> String {
  let builder = StringBuilder()
  for row in 0..<self.size {
    if row > 0 {
      builder.write_char(',')
    }
    builder.write_string("\{solution.get(self.queens[row])}")
  }
  builder.to_string()
}
