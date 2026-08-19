///|
/// Sequence analytics for traces, rosters, and solver decisions.
///
/// The routines are allocation-conscious for small integer traces and expose
/// stable edit, transition, run, and normalization metrics used by diagnostics.
pub struct SequenceReport {
  length : Int
  minimum : Int
  maximum : Int
  transitions : Int
  runs : Int
  checksum : Int
}

///|
/// Analyze an integer sequence.
pub fn sequence_report(values : Array[Int]) -> SequenceReport {
  let mut minimum = 0
  let mut maximum = 0
  if values.length() > 0 {
    minimum = values[0]
    maximum = values[0]
    for value in values {
      if value < minimum {
        minimum = value
      }
      if value > maximum {
        maximum = value
      }
    }
  }
  {
    length: values.length(),
    minimum,
    maximum,
    transitions: assignment_transitions(values),
    runs: sequence_run_count(values),
    checksum: sequence_checksum(values),
  }
}

///|
/// Count maximal runs.
pub fn sequence_run_count(values : Array[Int]) -> Int {
  if values.length() == 0 {
    return 0
  }
  let mut result = 1
  for index in 1..<values.length() {
    if values[index] != values[index - 1] {
      result += 1
    }
  }
  result
}

///|
/// Return run lengths.
pub fn sequence_run_lengths(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  if values.length() == 0 {
    return result
  }
  let mut current = 1
  for index in 1..<values.length() {
    if values[index] == values[index - 1] {
      current += 1
    } else {
      result.push(current)
      current = 1
    }
  }
  result.push(current)
  result
}

///|
/// Return run values paired with their lengths.
pub fn sequence_runs(values : Array[Int]) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  if values.length() == 0 {
    return result
  }
  let mut value = values[0]
  let mut length = 1
  for index in 1..<values.length() {
    if values[index] == value {
      length += 1
    } else {
      result.push((value, length))
      value = values[index]
      length = 1
    }
  }
  result.push((value, length))
  result
}

///|
/// Compute a deterministic checksum.
pub fn sequence_checksum(values : Array[Int]) -> Int {
  let mut result = 17
  for index, value in values {
    result = result * 31 + value + index * 7
  }
  result
}

///|
/// Normalize values by subtracting the minimum.
pub fn sequence_normalize(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  if values.length() == 0 {
    return result
  }
  let mut minimum = values[0]
  for value in values {
    if value < minimum {
      minimum = value
    }
  }
  for value in values {
    result.push(value - minimum)
  }
  result
}

///|
/// Return a cumulative sum sequence.
pub fn sequence_cumulative(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  let mut total = 0
  for value in values {
    total += value
    result.push(total)
  }
  result
}

///|
/// Return a first-difference sequence with an initial zero.
pub fn sequence_delta(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  if values.length() == 0 {
    return result
  }
  result.push(0)
  for index in 1..<values.length() {
    result.push(values[index] - values[index - 1])
  }
  result
}

///|
/// Return a weighted convolution with a same-length output.
pub fn sequence_convolve(
  values : Array[Int],
  kernel : Array[Int],
) -> Array[Int] {
  let result : Array[Int] = []
  if kernel.length() == 0 {
    return values.copy()
  }
  let center = kernel.length() / 2
  for index in 0..<values.length() {
    let mut total = 0
    for kernel_index in 0..<kernel.length() {
      let source = index + kernel_index - center
      if source >= 0 && source < values.length() {
        total += values[source] * kernel[kernel_index]
      }
    }
    result.push(total)
  }
  result
}

///|
/// Return the longest common subsequence length.
pub fn sequence_lcs_length(left : Array[Int], right : Array[Int]) -> Int {
  let table = int_matrix(left.length() + 1, right.length() + 1)
  for row in 1..<(left.length() + 1) {
    for column in 1..<(right.length() + 1) {
      let value = if left[row - 1] == right[column - 1] {
        table.get(row - 1, column - 1) + 1
      } else if table.get(row - 1, column) > table.get(row, column - 1) {
        table.get(row - 1, column)
      } else {
        table.get(row, column - 1)
      }
      ignore(table.set(row, column, value))
    }
  }
  table.get(left.length(), right.length())
}

///|
/// Return Levenshtein edit distance.
pub fn sequence_edit_distance(left : Array[Int], right : Array[Int]) -> Int {
  let table = int_matrix(left.length() + 1, right.length() + 1)
  for row in 0..<(left.length() + 1) {
    ignore(table.set(row, 0, row))
  }
  for column in 0..<(right.length() + 1) {
    ignore(table.set(0, column, column))
  }
  for row in 1..<(left.length() + 1) {
    for column in 1..<(right.length() + 1) {
      let mismatch = if left[row - 1] == right[column - 1] { 0 } else { 1 }
      let substitution = table.get(row - 1, column - 1) + mismatch
      let insertion = table.get(row, column - 1) + 1
      let deletion = table.get(row - 1, column) + 1
      let best = if substitution < insertion { substitution } else { insertion }
      ignore(
        table.set(row, column, if deletion < best { deletion } else { best }),
      )
    }
  }
  table.get(left.length(), right.length())
}

///|
/// Return whether a sequence contains a contiguous pattern.
pub fn sequence_contains(values : Array[Int], pattern : Array[Int]) -> Bool {
  if pattern.length() == 0 {
    return true
  }
  if pattern.length() > values.length() {
    return false
  }
  for start in 0..<(values.length() - pattern.length() + 1) {
    let mut matches = true
    for index in 0..<pattern.length() {
      if values[start + index] != pattern[index] {
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
/// Return whether a sequence is cyclically alternating.
pub fn sequence_cyclic_alternates(values : Array[Int]) -> Bool {
  if values.length() < 2 {
    return true
  }
  for index in 0..<values.length() {
    if values[index] == values[(index + 1) % values.length()] {
      return false
    }
  }
  true
}

///|
/// Return a stable sequence summary.
pub fn SequenceReport::describe(self : SequenceReport) -> String {
  "length=\{self.length}, min=\{self.minimum}, max=\{self.maximum}, transitions=\{self.transitions}, runs=\{self.runs}, checksum=\{self.checksum}"
}
