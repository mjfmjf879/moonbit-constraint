///|
/// A standard 9x9 Sudoku model backed by the finite-domain solver.
pub struct Sudoku {
  solver : Solver
  cells : Array[Int]
  givens : Array[Int]
}

///|
/// Parse a Sudoku puzzle. Digits 1-9 are givens; `0` and `.` are blanks.
/// Whitespace is ignored so puzzles can be copied from formatted grids.
pub fn sudoku(puzzle : String) -> Sudoku? {
  let digits : Array[Int] = []
  for character in puzzle {
    if character.is_whitespace() {
      continue
    }
    if character == '0' || character == '.' {
      digits.push(0)
    } else if character >= '1' && character <= '9' {
      digits.push(character.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  if digits.length() != 81 {
    return None
  }
  let solver = new_solver()
  let cells : Array[Int] = []
  for index in 0..<81 {
    cells.push(solver.add_variable(variable("cell_\{index}", 1, 9)))
  }
  for row in 0..<9 {
    let row_ids : Array[Int] = []
    for column in 0..<9 {
      row_ids.push(cells[row * 9 + column])
    }
    solver.add_constraint(all_different(row_ids))
  }
  for column in 0..<9 {
    let column_ids : Array[Int] = []
    for row in 0..<9 {
      column_ids.push(cells[row * 9 + column])
    }
    solver.add_constraint(all_different(column_ids))
  }
  for box_row in 0..<3 {
    for box_column in 0..<3 {
      let box_ids : Array[Int] = []
      for row in 0..<3 {
        for column in 0..<3 {
          box_ids.push(cells[(box_row * 3 + row) * 9 + box_column * 3 + column])
        }
      }
      solver.add_constraint(all_different(box_ids))
    }
  }
  for index, digit in digits {
    if digit > 0 && !solver.assign(cells[index], digit) {
      return None
    }
  }
  Some({ solver, cells, givens: digits })
}

///|
/// Build an empty Sudoku board.
pub fn empty_sudoku() -> Sudoku {
  match
    sudoku(
      ".................................................................................",
    ) {
    Some(value) => value
    None => abort("the built-in empty Sudoku puzzle is invalid")
  }
}

///|
/// Return the cell identifier at row and column coordinates.
pub fn Sudoku::cell(self : Sudoku, row : Int, column : Int) -> Int {
  if row < 0 || row >= 9 || column < 0 || column >= 9 {
    abort("Sudoku coordinates must be between 0 and 8")
  }
  self.cells[row * 9 + column]
}

///|
/// Add the two main diagonal constraints for a variant Sudoku.
pub fn Sudoku::add_diagonals(self : Sudoku) -> Unit {
  let main : Array[Int] = []
  let secondary : Array[Int] = []
  for index in 0..<9 {
    main.push(self.cell(index, index))
    secondary.push(self.cell(index, 8 - index))
  }
  self.solver.add_constraint(all_different(main))
  self.solver.add_constraint(all_different(secondary))
}

///|
/// Add a pair of cells that must differ by an exact distance.
pub fn Sudoku::add_distance(
  self : Sudoku,
  row : Int,
  column : Int,
  other_row : Int,
  other_column : Int,
  distance_value : Int,
) -> Bool {
  if row < 0 ||
    row >= 9 ||
    column < 0 ||
    column >= 9 ||
    other_row < 0 ||
    other_row >= 9 ||
    other_column < 0 ||
    other_column >= 9 ||
    distance_value < 0 {
    return false
  }
  self.solver.add_constraint(
    distance(
      self.cell(row, column),
      self.cell(other_row, other_column),
      distance_value,
    ),
  )
  true
}

///|
/// Solve the Sudoku once.
pub fn Sudoku::solve(self : Sudoku) -> Solution? {
  self.solver.solve()
}

///|
/// Return up to `limit` Sudoku solutions.
pub fn Sudoku::solve_all(self : Sudoku, limit : Int) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Count solutions up to a cap without exposing the whole solution array.
pub fn Sudoku::count_solutions(self : Sudoku, cap : Int) -> Int {
  self.solve_all(cap).length()
}

///|
/// Return search counters for the most recent solve.
pub fn Sudoku::stats(self : Sudoku) -> SearchStats {
  self.solver.stats()
}

///|
/// Return the internal cell identifiers in row-major order.
pub fn Sudoku::cell_ids(self : Sudoku) -> Array[Int] {
  self.cells.copy()
}

///|
/// Return the original givens as 81 digits, with zero for blanks.
pub fn Sudoku::givens(self : Sudoku) -> Array[Int] {
  self.givens.copy()
}

///|
/// Return the underlying solver for advanced variants.
pub fn Sudoku::solver(self : Sudoku) -> Solver {
  self.solver
}

///|
/// Render a solved board with three-by-three separators.
pub fn Sudoku::render(self : Sudoku, solution : Solution) -> String {
  let builder = StringBuilder()
  for row in 0..<9 {
    if row > 0 {
      builder.write_char('\n')
    }
    if row > 0 && row % 3 == 0 {
      builder.write_string("------+-------+------\n")
    }
    for column in 0..<9 {
      if column > 0 && column % 3 == 0 {
        builder.write_string(" | ")
      } else if column > 0 {
        builder.write_char(' ')
      }
      builder.write_string("\{solution.get(self.cell(row, column))}")
    }
  }
  builder.to_string()
}

///|
/// Render a compact 81-character solution string.
pub fn Sudoku::compact(self : Sudoku, solution : Solution) -> String {
  let builder = StringBuilder()
  for cell in self.cells {
    builder.write_string("\{solution.get(cell)}")
  }
  builder.to_string()
}

///|
/// Check whether a solution obeys every row, column and box rule.
pub fn Sudoku::is_valid(self : Sudoku, solution : Solution) -> Bool {
  for row in 0..<9 {
    let seen = Set([])
    for column in 0..<9 {
      let value = solution.get(self.cell(row, column))
      if value < 1 || value > 9 || seen.contains(value) {
        return false
      }
      seen.add(value)
    }
  }
  for column in 0..<9 {
    let seen = Set([])
    for row in 0..<9 {
      let value = solution.get(self.cell(row, column))
      if seen.contains(value) {
        return false
      }
      seen.add(value)
    }
  }
  for box_row in 0..<3 {
    for box_column in 0..<3 {
      let seen = Set([])
      for row in 0..<3 {
        for column in 0..<3 {
          let value = solution.get(
            self.cell(box_row * 3 + row, box_column * 3 + column),
          )
          if seen.contains(value) {
            return false
          }
          seen.add(value)
        }
      }
    }
  }
  true
}

///|
/// Return a canonical puzzle used in examples and benchmark baselines.
pub fn classic_sudoku() -> Sudoku? {
  let puzzle = "530070000" +
    "600195000" +
    "098000060" +
    "800060003" +
    "400803001" +
    "700020006" +
    "060000280" +
    "000419005" +
    "000080079"
  sudoku(puzzle)
}

///|
/// Return a solved canonical board for regression tests.
pub fn classic_solution_string() -> String {
  "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
}

///|
/// Convert a compact board string into a 9x9 integer matrix.
pub fn sudoku_grid(compact : String) -> Array[Array[Int]]? {
  let puzzle = match sudoku(compact) {
    Some(value) => value
    None => return None
  }
  let result : Array[Array[Int]] = []
  for row in 0..<9 {
    let line : Array[Int] = []
    for column in 0..<9 {
      line.push(puzzle.givens[row * 9 + column])
    }
    result.push(line)
  }
  Some(result)
}

///|
/// Construct a Sudoku from a 9x9 matrix, returning `None` for malformed data.
pub fn sudoku_from_grid(grid : Array[Array[Int]]) -> Sudoku? {
  if grid.length() != 9 {
    return None
  }
  let builder = StringBuilder()
  for row in grid {
    if row.length() != 9 {
      return None
    }
    for value in row {
      if value < 0 || value > 9 {
        return None
      }
      builder.write_string("\{value}")
    }
  }
  sudoku(builder.to_string())
}
