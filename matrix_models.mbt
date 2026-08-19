///|
/// Integer matrix utilities used by grid constraints and resource heatmaps.
///
/// Matrices are row-major, bounds checked at construction, and intentionally
/// use integers so they can be shared by solver preprocessing, image-like
/// occupancy grids, and deterministic benchmark fixtures.
pub struct IntMatrix {
  rows : Int
  columns : Int
  values : Array[Int]
}

///|
/// Create a zero-filled matrix.
pub fn int_matrix(rows : Int, columns : Int) -> IntMatrix {
  if rows < 0 || columns < 0 {
    abort("matrix dimensions must be non-negative")
  }
  let values : Array[Int] = []
  for _ in 0..<(rows * columns) {
    values.push(0)
  }
  { rows, columns, values }
}

///|
/// Create a matrix from row-major values.
pub fn int_matrix_from_values(
  rows : Int,
  columns : Int,
  values : Array[Int],
) -> IntMatrix? {
  if rows < 0 || columns < 0 || values.length() != rows * columns {
    return None
  }
  Some({ rows, columns, values: values.copy() })
}

///|
/// Create a filled matrix.
pub fn filled_matrix(rows : Int, columns : Int, value : Int) -> IntMatrix {
  let result = int_matrix(rows, columns)
  result.fill(value)
  result
}

///|
/// Return row count.
pub fn IntMatrix::row_count(self : IntMatrix) -> Int {
  self.rows
}

///|
/// Return column count.
pub fn IntMatrix::column_count(self : IntMatrix) -> Int {
  self.columns
}

///|
/// Validate a cell coordinate.
pub fn IntMatrix::valid_cell(self : IntMatrix, row : Int, column : Int) -> Bool {
  row >= 0 && row < self.rows && column >= 0 && column < self.columns
}

///|
/// Convert a cell to a row-major index.
fn IntMatrix::matrix_index(self : IntMatrix, row : Int, column : Int) -> Int {
  if !self.valid_cell(row, column) {
    abort("matrix cell is outside the matrix")
  }
  row * self.columns + column
}

///|
/// Read a cell.
pub fn IntMatrix::get(self : IntMatrix, row : Int, column : Int) -> Int {
  self.values[self.matrix_index(row, column)]
}

///|
/// Write a cell and return whether it changed.
pub fn IntMatrix::set(
  self : IntMatrix,
  row : Int,
  column : Int,
  value : Int,
) -> Bool {
  let index = self.matrix_index(row, column)
  let changed = self.values[index] != value
  self.values[index] = value
  changed
}

///|
/// Fill every cell.
pub fn IntMatrix::fill(self : IntMatrix, value : Int) -> Unit {
  for index in 0..<self.values.length() {
    self.values[index] = value
  }
}

///|
/// Return copied row-major values.
pub fn IntMatrix::values(self : IntMatrix) -> Array[Int] {
  self.values.copy()
}

///|
/// Return a copied row.
pub fn IntMatrix::row(self : IntMatrix, row : Int) -> Array[Int] {
  if row < 0 || row >= self.rows {
    return []
  }
  let result : Array[Int] = []
  for column in 0..<self.columns {
    result.push(self.values[row * self.columns + column])
  }
  result
}

///|
/// Return a copied column.
pub fn IntMatrix::column(self : IntMatrix, column : Int) -> Array[Int] {
  if column < 0 || column >= self.columns {
    return []
  }
  let result : Array[Int] = []
  for row in 0..<self.rows {
    result.push(self.values[row * self.columns + column])
  }
  result
}

///|
/// Return the transpose.
pub fn IntMatrix::transpose(self : IntMatrix) -> IntMatrix {
  let result = int_matrix(self.columns, self.rows)
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      ignore(result.set(column, row, self.get(row, column)))
    }
  }
  result
}

///|
/// Add two matrices.
pub fn IntMatrix::add(self : IntMatrix, other : IntMatrix) -> IntMatrix? {
  if self.rows != other.rows || self.columns != other.columns {
    return None
  }
  let result = int_matrix(self.rows, self.columns)
  for index in 0..<self.values.length() {
    result.values[index] = self.values[index] + other.values[index]
  }
  Some(result)
}

///|
/// Subtract two matrices.
pub fn IntMatrix::subtract(self : IntMatrix, other : IntMatrix) -> IntMatrix? {
  if self.rows != other.rows || self.columns != other.columns {
    return None
  }
  let result = int_matrix(self.rows, self.columns)
  for index in 0..<self.values.length() {
    result.values[index] = self.values[index] - other.values[index]
  }
  Some(result)
}

///|
/// Multiply each cell by a scalar.
pub fn IntMatrix::scale(self : IntMatrix, factor : Int) -> IntMatrix {
  let result = int_matrix(self.rows, self.columns)
  for index in 0..<self.values.length() {
    result.values[index] = self.values[index] * factor
  }
  result
}

///|
/// Multiply two matrices.
pub fn IntMatrix::multiply(self : IntMatrix, other : IntMatrix) -> IntMatrix? {
  if self.columns != other.rows {
    return None
  }
  let result = int_matrix(self.rows, other.columns)
  for row in 0..<self.rows {
    for column in 0..<other.columns {
      let mut value = 0
      for shared in 0..<self.columns {
        value += self.get(row, shared) * other.get(shared, column)
      }
      ignore(result.set(row, column, value))
    }
  }
  Some(result)
}

///|
/// Return the trace of a square matrix.
pub fn IntMatrix::trace(self : IntMatrix) -> Int? {
  if self.rows != self.columns {
    return None
  }
  let mut result = 0
  for index in 0..<self.rows {
    result += self.get(index, index)
  }
  Some(result)
}

///|
/// Return the main diagonal.
pub fn IntMatrix::diagonal(self : IntMatrix) -> Array[Int] {
  let result : Array[Int] = []
  let limit = if self.rows < self.columns { self.rows } else { self.columns }
  for index in 0..<limit {
    result.push(self.get(index, index))
  }
  result
}

///|
/// Return row sums.
pub fn IntMatrix::row_sums(self : IntMatrix) -> Array[Int] {
  let result : Array[Int] = []
  for row in 0..<self.rows {
    let mut total = 0
    for column in 0..<self.columns {
      total += self.get(row, column)
    }
    result.push(total)
  }
  result
}

///|
/// Return column sums.
pub fn IntMatrix::column_sums(self : IntMatrix) -> Array[Int] {
  let result : Array[Int] = []
  for column in 0..<self.columns {
    let mut total = 0
    for row in 0..<self.rows {
      total += self.get(row, column)
    }
    result.push(total)
  }
  result
}

///|
/// Return the smallest cell value, or None for an empty matrix.
pub fn IntMatrix::minimum(self : IntMatrix) -> Int? {
  if self.values.length() == 0 {
    return None
  }
  let mut result = self.values[0]
  for value in self.values {
    if value < result {
      result = value
    }
  }
  Some(result)
}

///|
/// Return the largest cell value, or None for an empty matrix.
pub fn IntMatrix::maximum(self : IntMatrix) -> Int? {
  if self.values.length() == 0 {
    return None
  }
  let mut result = self.values[0]
  for value in self.values {
    if value > result {
      result = value
    }
  }
  Some(result)
}

///|
/// Count cells equal to a value.
pub fn IntMatrix::count(self : IntMatrix, value : Int) -> Int {
  let mut result = 0
  for candidate in self.values {
    if candidate == value {
      result += 1
    }
  }
  result
}

///|
/// Clamp every cell into an inclusive range.
pub fn IntMatrix::clamp(self : IntMatrix, lower : Int, upper : Int) -> Unit {
  for index in 0..<self.values.length() {
    if self.values[index] < lower {
      self.values[index] = lower
    } else if self.values[index] > upper {
      self.values[index] = upper
    }
  }
}

///|
/// Replace each cell by its sign.
pub fn IntMatrix::sign(self : IntMatrix) -> IntMatrix {
  let result = int_matrix(self.rows, self.columns)
  for index, value in self.values {
    result.values[index] = if value < 0 {
      -1
    } else if value > 0 {
      1
    } else {
      0
    }
  }
  result
}

///|
/// Rotate clockwise by 90 degrees.
pub fn IntMatrix::rotate_clockwise(self : IntMatrix) -> IntMatrix {
  let result = int_matrix(self.columns, self.rows)
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      ignore(result.set(column, self.rows - row - 1, self.get(row, column)))
    }
  }
  result
}

///|
/// Reflect across the vertical axis.
pub fn IntMatrix::reflect_horizontal(self : IntMatrix) -> IntMatrix {
  let result = int_matrix(self.rows, self.columns)
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      ignore(result.set(row, self.columns - column - 1, self.get(row, column)))
    }
  }
  result
}

///|
/// Reflect across the horizontal axis.
pub fn IntMatrix::reflect_vertical(self : IntMatrix) -> IntMatrix {
  let result = int_matrix(self.rows, self.columns)
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      ignore(result.set(self.rows - row - 1, column, self.get(row, column)))
    }
  }
  result
}

///|
/// Apply a four-neighbor convolution kernel.
pub fn IntMatrix::convolve3x3(
  self : IntMatrix,
  kernel : Array[Int],
  divisor : Int,
) -> IntMatrix? {
  if kernel.length() != 9 || divisor == 0 {
    return None
  }
  let result = int_matrix(self.rows, self.columns)
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      let mut total = 0
      for kernel_row in 0..<3 {
        for kernel_column in 0..<3 {
          let source_row = row + kernel_row - 1
          let source_column = column + kernel_column - 1
          if self.valid_cell(source_row, source_column) {
            total += self.get(source_row, source_column) *
              kernel[kernel_row * 3 + kernel_column]
          }
        }
      }
      ignore(result.set(row, column, total / divisor))
    }
  }
  Some(result)
}

///|
/// Return a binary occupancy mask.
pub fn IntMatrix::threshold(self : IntMatrix, limit : Int) -> IntMatrix {
  let result = int_matrix(self.rows, self.columns)
  for index, value in self.values {
    result.values[index] = if value >= limit { 1 } else { 0 }
  }
  result
}

///|
/// Return the four-neighbor cells of a coordinate.
pub fn IntMatrix::neighbors4(
  self : IntMatrix,
  row : Int,
  column : Int,
) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  let candidates : Array[(Int, Int)] = [
    (row - 1, column),
    (row, column + 1),
    (row + 1, column),
    (row, column - 1),
  ]
  for candidate in candidates {
    if self.valid_cell(candidate.0, candidate.1) {
      result.push(candidate)
    }
  }
  result
}

///|
/// Count a connected component of equal-valued cells.
pub fn IntMatrix::component_size(
  self : IntMatrix,
  row : Int,
  column : Int,
) -> Int {
  if !self.valid_cell(row, column) {
    return 0
  }
  let target = self.get(row, column)
  let seen = filled_bool_matrix(self.rows, self.columns, false)
  let queue : Array[(Int, Int)] = [(row, column)]
  seen[row][column] = true
  let mut head = 0
  let mut result = 0
  while head < queue.length() {
    let cell = queue[head]
    head += 1
    result += 1
    for neighbor in self.neighbors4(cell.0, cell.1) {
      if !seen[neighbor.0][neighbor.1] &&
        self.get(neighbor.0, neighbor.1) == target {
        seen[neighbor.0][neighbor.1] = true
        queue.push(neighbor)
      }
    }
  }
  result
}

///|
/// Create a boolean matrix.
fn filled_bool_matrix(
  rows : Int,
  columns : Int,
  value : Bool,
) -> Array[Array[Bool]] {
  let result : Array[Array[Bool]] = []
  for _ in 0..<rows {
    let row : Array[Bool] = []
    for _ in 0..<columns {
      row.push(value)
    }
    result.push(row)
  }
  result
}

///|
/// Return a four-neighbor shortest path on cells equal to a passable value.
pub fn IntMatrix::grid_path(
  self : IntMatrix,
  start : (Int, Int),
  goal : (Int, Int),
  passable : Int,
) -> Array[(Int, Int)]? {
  if !self.valid_cell(start.0, start.1) ||
    !self.valid_cell(goal.0, goal.1) ||
    self.get(start.0, start.1) != passable ||
    self.get(goal.0, goal.1) != passable {
    return None
  }
  let visited = filled_bool_matrix(self.rows, self.columns, false)
  let previous : Array[Array[(Int, Int)?]] = []
  for _ in 0..<self.rows {
    let row : Array[(Int, Int)?] = []
    for _ in 0..<self.columns {
      row.push(None)
    }
    previous.push(row)
  }
  let queue : Array[(Int, Int)] = [start]
  visited[start.0][start.1] = true
  let mut head = 0
  while head < queue.length() {
    let cell = queue[head]
    head += 1
    if cell == goal {
      break
    }
    for neighbor in self.neighbors4(cell.0, cell.1) {
      if !visited[neighbor.0][neighbor.1] &&
        self.get(neighbor.0, neighbor.1) == passable {
        visited[neighbor.0][neighbor.1] = true
        previous[neighbor.0][neighbor.1] = Some(cell)
        queue.push(neighbor)
      }
    }
  }
  if !visited[goal.0][goal.1] {
    return None
  }
  let reversed : Array[(Int, Int)] = [goal]
  let mut current = goal
  while current != start {
    match previous[current.0][current.1] {
      Some(value) => {
        current = value
        reversed.push(current)
      }
      None => return None
    }
  }
  let result : Array[(Int, Int)] = []
  let last = reversed.length() - 1
  for index in last>=..0 {
    result.push(reversed[index])
  }
  Some(result)
}

///|
/// Compute an integral prefix-sum matrix.
pub fn IntMatrix::prefix_sum(self : IntMatrix) -> IntMatrix {
  let result = int_matrix(self.rows + 1, self.columns + 1)
  for row in 1..<(self.rows + 1) {
    for column in 1..<(self.columns + 1) {
      let value = self.get(row - 1, column - 1) +
        result.get(row - 1, column) +
        result.get(row, column - 1) -
        result.get(row - 1, column - 1)
      ignore(result.set(row, column, value))
    }
  }
  result
}

///|
/// Query an inclusive rectangle sum using a prefix matrix.
pub fn rectangle_sum(
  prefix : IntMatrix,
  top : Int,
  left : Int,
  bottom : Int,
  right : Int,
) -> Int? {
  if top < 0 ||
    left < 0 ||
    bottom < top ||
    right < left ||
    bottom + 1 >= prefix.rows ||
    right + 1 >= prefix.columns {
    return None
  }
  Some(
    prefix.get(bottom + 1, right + 1) -
    prefix.get(top, right + 1) -
    prefix.get(bottom + 1, left) +
    prefix.get(top, left),
  )
}

///|
/// Render a matrix with spaces between cells.
pub fn IntMatrix::render(self : IntMatrix) -> String {
  let builder = StringBuilder()
  for row in 0..<self.rows {
    if row > 0 {
      builder.write_char('\n')
    }
    for column in 0..<self.columns {
      if column > 0 {
        builder.write_char(' ')
      }
      builder.write_string("\{self.get(row, column)}")
    }
  }
  builder.to_string()
}

///|
/// Render rows as comma-separated integers.
pub fn IntMatrix::csv(self : IntMatrix) -> String {
  let builder = StringBuilder()
  for row in 0..<self.rows {
    if row > 0 {
      builder.write_char('\n')
    }
    for column in 0..<self.columns {
      if column > 0 {
        builder.write_char(',')
      }
      builder.write_string("\{self.get(row, column)}")
    }
  }
  builder.to_string()
}

///|
/// Parse a rectangular integer CSV matrix.
pub fn parse_int_matrix(input : String) -> IntMatrix? {
  let rows : Array[Array[Int]] = []
  for line_view in input.split("\n") {
    let line = line_view.to_owned()
    if line.trim() == "" {
      continue
    }
    match parse_integer_list(line) {
      Some(row) => rows.push(row)
      None => return None
    }
  }
  if rows.length() == 0 {
    return Some(int_matrix(0, 0))
  }
  let columns = rows[0].length()
  let values : Array[Int] = []
  for row in rows {
    if row.length() != columns {
      return None
    }
    for value in row {
      values.push(value)
    }
  }
  int_matrix_from_values(values.length() / columns, columns, values)
}

///|
/// Create an identity matrix.
pub fn identity_matrix(size : Int) -> IntMatrix {
  let result = int_matrix(size, size)
  for index in 0..<size {
    ignore(result.set(index, index, 1))
  }
  result
}

///|
/// Create a checkerboard matrix.
pub fn checkerboard_matrix(rows : Int, columns : Int) -> IntMatrix {
  let result = int_matrix(rows, columns)
  for row in 0..<rows {
    for column in 0..<columns {
      ignore(result.set(row, column, (row + column) % 2))
    }
  }
  result
}

///|
/// Return a stable matrix fingerprint.
pub fn IntMatrix::signature(self : IntMatrix) -> Int {
  let mut result = self.rows * 31 + self.columns
  for value in self.values {
    result = result * 37 + value
  }
  result
}

///|
/// Return a centered moving average with integer division.
pub fn IntMatrix::box_blur(self : IntMatrix, radius : Int) -> IntMatrix {
  if radius <= 0 {
    return self
  }
  let result = int_matrix(self.rows, self.columns)
  let width = radius * 2 + 1
  let area = width * width
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      let mut total = 0
      let row_start = row - radius
      let row_end = row + radius + 1
      let column_start = column - radius
      let column_end = column + radius + 1
      for source_row in row_start..<row_end {
        for source_column in column_start..<column_end {
          if self.valid_cell(source_row, source_column) {
            total += self.get(source_row, source_column)
          }
        }
      }
      ignore(result.set(row, column, total / area))
    }
  }
  result
}
