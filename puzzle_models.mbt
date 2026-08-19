///|
/// Small exact puzzle models backed by finite-domain primitives.
///
/// These helpers are useful as regression fixtures as well as educational
/// examples: a puzzle carries its dimensions and clues, generates legal line
/// patterns, propagates forced cells, and exposes a stable verification path.
pub struct NonogramLine {
  length : Int
  clues : Array[Int]
}

///|
/// Create a nonogram line clue.
pub fn nonogram_line(length : Int, clues : Array[Int]) -> NonogramLine? {
  if length < 0 || (clues.length() == 0 && length > 0) {
    return None
  }
  for clue in clues {
    if clue < 1 {
      return None
    }
  }
  Some({ length, clues: clues.copy() })
}

///|
/// Return the minimum cells required by clues and separators.
pub fn NonogramLine::minimum_used(self : NonogramLine) -> Int {
  let mut result = 0
  for clue in self.clues {
    result += clue
  }
  if self.clues.length() > 0 {
    result += self.clues.length() - 1
  }
  result
}

///|
/// Return whether a binary line satisfies this clue.
pub fn NonogramLine::matches(self : NonogramLine, cells : Array[Int]) -> Bool {
  if cells.length() != self.length {
    return false
  }
  let runs : Array[Int] = []
  let mut current = 0
  for cell in cells {
    if cell != 0 {
      current += 1
    } else if current > 0 {
      runs.push(current)
      current = 0
    }
  }
  if current > 0 {
    runs.push(current)
  }
  if runs.length() != self.clues.length() {
    return false
  }
  for index in 0..<runs.length() {
    if runs[index] != self.clues[index] {
      return false
    }
  }
  true
}

///|
/// Generate all legal binary patterns for a clue.
pub fn NonogramLine::patterns(self : NonogramLine) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  let current : Array[Int] = []
  for _ in 0..<self.length {
    current.push(0)
  }
  nonogram_generate(self, 0, 0, current, result)
  result
}

///|
/// Recursive nonogram pattern generation.
fn nonogram_generate(
  line : NonogramLine,
  clue_index : Int,
  position : Int,
  cells : Array[Int],
  result : Array[Array[Int]],
) -> Unit {
  if clue_index >= line.clues.length() {
    result.push(cells.copy())
    return
  }
  let remaining = line.clues.length() - clue_index - 1
  let mut required_after = remaining
  let clue_start = clue_index + 1
  for index in clue_start..<line.clues.length() {
    required_after += line.clues[index]
  }
  let clue = line.clues[clue_index]
  let last_start = line.length - clue - required_after
  for start in position..<(last_start + 1) {
    let end = start + clue
    for cell in start..<end {
      cells[cell] = 1
    }
    let next = start + clue + 1
    if clue_index + 1 >= line.clues.length() {
      nonogram_generate(line, clue_index + 1, line.length, cells, result)
    } else {
      nonogram_generate(line, clue_index + 1, next, cells, result)
    }
    for cell in start..<end {
      cells[cell] = 0
    }
  }
}

///|
/// A rectangular nonogram puzzle.
pub struct NonogramPuzzle {
  rows : Array[NonogramLine]
  columns : Array[NonogramLine]
  cells : IntMatrix
}

///|
/// Create a blank nonogram puzzle.
pub fn nonogram_puzzle(
  rows : Array[NonogramLine],
  columns : Array[NonogramLine],
) -> NonogramPuzzle? {
  if rows.length() == 0 || columns.length() == 0 {
    return None
  }
  for row in rows {
    if row.length != columns.length() {
      return None
    }
  }
  for column in columns {
    if column.length != rows.length() {
      return None
    }
  }
  Some({
    rows: rows.copy(),
    columns: columns.copy(),
    cells: filled_matrix(rows.length(), columns.length(), -1),
  })
}

///|
/// Read puzzle dimensions.
pub fn NonogramPuzzle::row_count(self : NonogramPuzzle) -> Int {
  self.rows.length()
}

///|
/// Read column count.
pub fn NonogramPuzzle::column_count(self : NonogramPuzzle) -> Int {
  self.columns.length()
}

///|
/// Fix a cell to empty or filled.
pub fn NonogramPuzzle::fix(
  self : NonogramPuzzle,
  row : Int,
  column : Int,
  value : Int,
) -> Bool {
  if (value != 0 && value != 1) || !self.cells.valid_cell(row, column) {
    return false
  }
  let current = self.cells.get(row, column)
  if current == -1 {
    ignore(self.cells.set(row, column, value))
    true
  } else {
    current == value
  }
}

///|
/// Read a cell, or -1 when outside the puzzle.
pub fn NonogramPuzzle::cell(
  self : NonogramPuzzle,
  row : Int,
  column : Int,
) -> Int {
  if !self.cells.valid_cell(row, column) {
    -1
  } else {
    self.cells.get(row, column)
  }
}

///|
/// Filter line patterns by fixed cells.
fn nonogram_compatible(
  patterns : Array[Array[Int]],
  fixed : Array[Int],
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for pattern in patterns {
    let mut compatible = true
    for index, value in fixed {
      if value >= 0 && value != pattern[index] {
        compatible = false
      }
    }
    if compatible {
      result.push(pattern)
    }
  }
  result
}

///|
/// Propagate forced cells from row and column pattern intersections.
pub fn NonogramPuzzle::propagate(self : NonogramPuzzle) -> Int {
  let mut changes = 0
  for row in 0..<self.rows.length() {
    let fixed = self.cells.row(row)
    let patterns = nonogram_compatible(self.rows[row].patterns(), fixed)
    if patterns.length() == 0 {
      continue
    }
    for column in 0..<self.columns.length() {
      let mut filled = true
      let mut empty = true
      for pattern in patterns {
        if pattern[column] == 0 {
          filled = false
        }
        if pattern[column] == 1 {
          empty = false
        }
      }
      let value = if filled { 1 } else if empty { 0 } else { -1 }
      if value >= 0 && self.cell(row, column) != value {
        ignore(self.cells.set(row, column, value))
        changes += 1
      }
    }
  }
  for column in 0..<self.columns.length() {
    let fixed = self.cells.column(column)
    let patterns = nonogram_compatible(self.columns[column].patterns(), fixed)
    if patterns.length() == 0 {
      continue
    }
    for row in 0..<self.rows.length() {
      let mut filled = true
      let mut empty = true
      for pattern in patterns {
        if pattern[row] == 0 {
          filled = false
        }
        if pattern[row] == 1 {
          empty = false
        }
      }
      let value = if filled { 1 } else if empty { 0 } else { -1 }
      if value >= 0 && self.cell(row, column) != value {
        ignore(self.cells.set(row, column, value))
        changes += 1
      }
    }
  }
  changes
}

///|
/// Return whether every row and column is solved.
pub fn NonogramPuzzle::solved(self : NonogramPuzzle) -> Bool {
  for row in 0..<self.rows.length() {
    if self.cells.row(row).contains(-1) ||
      !self.rows[row].matches(self.cells.row(row)) {
      return false
    }
  }
  for column in 0..<self.columns.length() {
    if self.cells.column(column).contains(-1) ||
      !self.columns[column].matches(self.cells.column(column)) {
      return false
    }
  }
  true
}

///|
/// Return whether the current partial board can still satisfy clues.
pub fn NonogramPuzzle::consistent(self : NonogramPuzzle) -> Bool {
  for row in 0..<self.rows.length() {
    if nonogram_compatible(self.rows[row].patterns(), self.cells.row(row)).length() ==
      0 {
      return false
    }
  }
  for column in 0..<self.columns.length() {
    if nonogram_compatible(
        self.columns[column].patterns(),
        self.cells.column(column),
      ).length() ==
      0 {
      return false
    }
  }
  true
}

///|
/// Render a board with ? for unknown cells.
pub fn NonogramPuzzle::render(self : NonogramPuzzle) -> String {
  let builder = StringBuilder()
  for row in 0..<self.rows.length() {
    if row > 0 {
      builder.write_char('\n')
    }
    for column in 0..<self.columns.length() {
      builder.write_char(
        if self.cell(row, column) == 1 {
          '#'
        } else if self.cell(row, column) == 0 {
          '.'
        } else {
          '?'
        },
      )
    }
  }
  builder.to_string()
}

///|
/// A Latin square model.
pub struct LatinPuzzle {
  size : Int
  values : IntMatrix
}

///|
/// Create an empty Latin square.
pub fn latin_puzzle(size : Int) -> LatinPuzzle? {
  if size < 1 {
    return None
  }
  Some({ size, values: filled_matrix(size, size, -1) })
}

///|
/// Set a Latin square cell.
pub fn LatinPuzzle::set(
  self : LatinPuzzle,
  row : Int,
  column : Int,
  value : Int,
) -> Bool {
  if row < 0 ||
    row >= self.size ||
    column < 0 ||
    column >= self.size ||
    value < 0 ||
    value >= self.size {
    return false
  }
  if self.values.row(row).contains(value) ||
    self.values.column(column).contains(value) {
    return self.values.get(row, column) == value
  }
  ignore(self.values.set(row, column, value))
  true
}

///|
/// Return legal values for a Latin square cell.
pub fn LatinPuzzle::candidates(
  self : LatinPuzzle,
  row : Int,
  column : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  if row < 0 || row >= self.size || column < 0 || column >= self.size {
    return result
  }
  let row_values = self.values.row(row)
  let column_values = self.values.column(column)
  for value in 0..<self.size {
    if !row_values.contains(value) && !column_values.contains(value) {
      result.push(value)
    }
  }
  result
}

///|
/// Return whether a Latin square is complete and valid.
pub fn LatinPuzzle::solved(self : LatinPuzzle) -> Bool {
  for row in 0..<self.size {
    let values = self.values.row(row)
    if values.contains(-1) || !validate_latin_line(values, self.size) {
      return false
    }
  }
  for column in 0..<self.size {
    if !validate_latin_line(self.values.column(column), self.size) {
      return false
    }
  }
  true
}

///|
/// Validate one Latin line.
fn validate_latin_line(values : Array[Int], size : Int) -> Bool {
  if values.length() != size {
    return false
  }
  for value in 0..<size {
    if !values.contains(value) {
      return false
    }
  }
  true
}

///|
/// Fill a cyclic Latin square.
pub fn cyclic_latin_puzzle(size : Int) -> LatinPuzzle? {
  match latin_puzzle(size) {
    None => None
    Some(puzzle) => {
      for row in 0..<size {
        for column in 0..<size {
          ignore(puzzle.values.set(row, column, (row + column) % size))
        }
      }
      Some(puzzle)
    }
  }
}

///|
/// Return a puzzle fingerprint.
pub fn LatinPuzzle::signature(self : LatinPuzzle) -> Int {
  self.values.signature() + self.size * 17
}
