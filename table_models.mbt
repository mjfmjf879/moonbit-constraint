///|
/// A validated extensional relation that can be posted to a solver.
pub struct RelationTable {
  arity : Int
  rows : Array[Array[Int]]
}

///|
/// Build a relation table from rows with a common arity.
pub fn relation_table(rows : Array[Array[Int]]) -> RelationTable? {
  if rows.length() == 0 {
    return None
  }
  let arity = rows[0].length()
  if arity == 0 {
    return None
  }
  for row in rows {
    if row.length() != arity {
      return None
    }
  }
  Some({ arity, rows: rows.map(row => row.copy()) })
}

///|
/// Return relation arity.
pub fn RelationTable::arity(self : RelationTable) -> Int {
  self.arity
}

///|
/// Return a defensive copy of relation rows.
pub fn RelationTable::rows(self : RelationTable) -> Array[Array[Int]] {
  self.rows.map(row => row.copy())
}

///|
/// Post this relation for a tuple of variables.
pub fn RelationTable::post(
  self : RelationTable,
  solver : Solver,
  variables : Array[Int],
) -> Bool {
  if variables.length() != self.arity {
    return false
  }
  solver.add_constraint(table(variables, self.rows))
  true
}

///|
/// Return whether a row occurs in the relation.
pub fn RelationTable::contains(self : RelationTable, row : Array[Int]) -> Bool {
  if row.length() != self.arity {
    return false
  }
  for candidate in self.rows {
    let mut matches = true
    for index in 0..<self.arity {
      if candidate[index] != row[index] {
        matches = false
      }
    }
    if matches {
      return true
    }
  }
  false
}

///|
/// Return the rows compatible with a partial tuple.
pub fn RelationTable::compatible(
  self : RelationTable,
  partial : Array[Int?],
) -> Array[Array[Int]] {
  if partial.length() != self.arity {
    return []
  }
  let result : Array[Array[Int]] = []
  for row in self.rows {
    let mut matches = true
    for index, value in partial {
      match value {
        Some(expected) => if row[index] != expected { matches = false }
        None => ()
      }
    }
    if matches {
      result.push(row.copy())
    }
  }
  result
}

///|
/// Return the projection of one relation column.
pub fn RelationTable::column(self : RelationTable, index : Int) -> Array[Int] {
  if index < 0 || index >= self.arity {
    return []
  }
  let result : Array[Int] = []
  for row in self.rows {
    if !result.contains(row[index]) {
      result.push(row[index])
    }
  }
  result
}

///|
/// Render rows for diagnostics.
pub fn RelationTable::describe(self : RelationTable) -> String {
  let builder = StringBuilder()
  builder.write_string("arity=\{self.arity}, rows=\{self.rows.length()}")
  for row in self.rows {
    builder.write_string("\n  \{Repr(row)}")
  }
  builder.to_string()
}

///|
/// Return a table for `left != right` over a finite value set.
pub fn not_equal_table(values : Array[Int]) -> RelationTable? {
  let rows : Array[Array[Int]] = []
  for left in values {
    for right in values {
      if left != right {
        rows.push([left, right])
      }
    }
  }
  relation_table(rows)
}

///|
/// Return a table for `left < right` over a finite value set.
pub fn less_than_table(values : Array[Int]) -> RelationTable? {
  let rows : Array[Array[Int]] = []
  for left in values {
    for right in values {
      if left < right {
        rows.push([left, right])
      }
    }
  }
  relation_table(rows)
}

///|
/// Return a table for a finite arithmetic sum.
pub fn sum_table(left : Domain, right : Domain, target : Int) -> RelationTable? {
  let rows : Array[Array[Int]] = []
  for left_value in left.values() {
    for right_value in right.values() {
      if left_value + right_value == target {
        rows.push([left_value, right_value])
      }
    }
  }
  relation_table(rows)
}

///|
/// Post exactly-one for Boolean indicator variables.
pub fn post_exactly_one(solver : Solver, indicators : Array[Int]) -> Unit {
  solver.add_constraint(sum(indicators, 1))
}

///|
/// Post at-most-one for Boolean indicator variables.
pub fn post_at_most_one(solver : Solver, indicators : Array[Int]) -> Unit {
  solver.add_constraint(at_most_value(indicators, 1, 1))
}

///|
/// Post an exactly-k cardinality constraint over Boolean indicators.
pub fn post_exactly_k(
  solver : Solver,
  indicators : Array[Int],
  count : Int,
) -> Unit {
  solver.add_constraint(sum(indicators, count))
}

///|
/// Post a binary relation table for two variables.
pub fn post_binary_table(
  solver : Solver,
  left : Int,
  right : Int,
  relation : RelationTable,
) -> Bool {
  relation.post(solver, [left, right])
}

///|
/// A Latin square model with row and column permutation constraints.
pub struct LatinSquare {
  solver : Solver
  cells : Array[Int]
  size : Int
}

///|
/// Build a Latin square over symbols `0..size-1`.
pub fn latin_square(size : Int) -> LatinSquare? {
  if size < 1 {
    return None
  }
  let solver = new_solver()
  let cells : Array[Int] = []
  for row in 0..<size {
    for column in 0..<size {
      cells.push(
        solver.add_variable(variable("latin_\{row}_\{column}", 0, size - 1)),
      )
    }
  }
  for row in 0..<size {
    let ids : Array[Int] = []
    for column in 0..<size {
      ids.push(cells[row * size + column])
    }
    solver.add_constraint(all_different(ids))
  }
  for column in 0..<size {
    let ids : Array[Int] = []
    for row in 0..<size {
      ids.push(cells[row * size + column])
    }
    solver.add_constraint(all_different(ids))
  }
  Some({ solver, cells, size })
}

///|
/// Fix the first row to canonical symbol order.
pub fn LatinSquare::fix_first_row(self : LatinSquare) -> Unit {
  for column in 0..<self.size {
    ignore(self.solver.assign(self.cells[column], column))
  }
}

///|
/// Return a cell identifier.
pub fn LatinSquare::cell(self : LatinSquare, row : Int, column : Int) -> Int {
  if row < 0 || row >= self.size || column < 0 || column >= self.size {
    abort("Latin square coordinates are outside the model")
  }
  self.cells[row * self.size + column]
}

///|
/// Solve the Latin square once.
pub fn LatinSquare::solve(self : LatinSquare) -> Solution? {
  self.solver.solve()
}

///|
/// Return a matrix of a Latin square solution.
pub fn LatinSquare::matrix(
  self : LatinSquare,
  solution : Solution,
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for row in 0..<self.size {
    let line : Array[Int] = []
    for column in 0..<self.size {
      line.push(solution.get(self.cell(row, column)))
    }
    result.push(line)
  }
  result
}

///|
/// Validate a Latin square solution.
pub fn LatinSquare::is_valid(self : LatinSquare, solution : Solution) -> Bool {
  self.solver.is_valid_solution(solution)
}

///|
/// Return search statistics.
pub fn LatinSquare::stats(self : LatinSquare) -> SearchStats {
  self.solver.stats()
}

///|
/// A magic-square model with all-different cells and line sums.
pub struct MagicSquare {
  solver : Solver
  cells : Array[Int]
  size : Int
  magic_sum : Int
}

///|
/// Build a normal magic square model for a positive odd size.
pub fn magic_square(size : Int) -> MagicSquare? {
  if size < 1 || size % 2 == 0 {
    return None
  }
  let solver = new_solver()
  let cells : Array[Int] = []
  let max_value = size * size
  for index in 0..<max_value {
    cells.push(solver.add_variable(variable("magic_\{index}", 1, max_value)))
  }
  solver.add_constraint(all_different(cells))
  let magic_sum = size * (max_value + 1) / 2
  for row in 0..<size {
    let ids : Array[Int] = []
    for column in 0..<size {
      ids.push(cells[row * size + column])
    }
    solver.add_constraint(sum(ids, magic_sum))
  }
  for column in 0..<size {
    let ids : Array[Int] = []
    for row in 0..<size {
      ids.push(cells[row * size + column])
    }
    solver.add_constraint(sum(ids, magic_sum))
  }
  let main : Array[Int] = []
  let secondary : Array[Int] = []
  for index in 0..<size {
    main.push(cells[index * size + index])
    secondary.push(cells[index * size + size - 1 - index])
  }
  solver.add_constraint(sum(main, magic_sum))
  solver.add_constraint(sum(secondary, magic_sum))
  Some({ solver, cells, size, magic_sum })
}

///|
/// Return the target line sum.
pub fn MagicSquare::target(self : MagicSquare) -> Int {
  self.magic_sum
}

///|
/// Return a cell identifier.
pub fn MagicSquare::cell(self : MagicSquare, row : Int, column : Int) -> Int {
  if row < 0 || row >= self.size || column < 0 || column >= self.size {
    abort("magic square coordinates are outside the model")
  }
  self.cells[row * self.size + column]
}

///|
/// Solve a magic square once.
pub fn MagicSquare::solve(self : MagicSquare) -> Solution? {
  self.solver.solve()
}

///|
/// Return a matrix from a magic-square solution.
pub fn MagicSquare::matrix(
  self : MagicSquare,
  solution : Solution,
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for row in 0..<self.size {
    let line : Array[Int] = []
    for column in 0..<self.size {
      line.push(solution.get(self.cell(row, column)))
    }
    result.push(line)
  }
  result
}

///|
/// Return whether a magic-square assignment is valid.
pub fn MagicSquare::is_valid(self : MagicSquare, solution : Solution) -> Bool {
  self.solver.is_valid_solution(solution)
}

///|
/// Return statistics from the most recent solve.
pub fn MagicSquare::stats(self : MagicSquare) -> SearchStats {
  self.solver.stats()
}
