///|
/// Analytics for categorical assignments and roster stability.
///
/// These functions operate on integer labels and are intentionally independent
/// of a particular schedule representation. They can score worker rosters,
/// machine labels, cluster assignments, or any finite categorical plan.
pub struct AssignmentMetrics {
  count : Int
  categories : Int
  minimum : Int
  maximum : Int
  spread : Int
  transitions : Int
  changes : Int
}

///|
/// Count distinct categorical labels.
pub fn assignment_category_count(values : Array[Int]) -> Int {
  let categories : Array[Int] = []
  for value in values {
    if !categories.contains(value) {
      categories.push(value)
    }
  }
  categories.length()
}

///|
/// Return category counts for labels from 0 through category_count - 1.
pub fn assignment_counts(
  values : Array[Int],
  category_count : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for _ in 0..<category_count {
    result.push(0)
  }
  for value in values {
    if value >= 0 && value < result.length() {
      result[value] += 1
    }
  }
  result
}

///|
/// Return the number of adjacent label changes.
pub fn assignment_transitions(values : Array[Int]) -> Int {
  let mut result = 0
  for index in 1..<values.length() {
    if values[index] != values[index - 1] {
      result += 1
    }
  }
  result
}

///|
/// Count differences at matching positions.
pub fn assignment_changes(previous : Array[Int], current : Array[Int]) -> Int {
  let limit = if previous.length() < current.length() {
    previous.length()
  } else {
    current.length()
  }
  let mut result = if previous.length() == current.length() { 0 } else { 1 }
  for index in 0..<limit {
    if previous[index] != current[index] {
      result += 1
    }
  }
  result
}

///|
/// Return a categorical load imbalance score.
pub fn assignment_imbalance(values : Array[Int], category_count : Int) -> Int {
  let counts = assignment_counts(values, category_count)
  if counts.length() == 0 {
    return 0
  }
  let mut low = counts[0]
  let mut high = counts[0]
  for count in counts {
    if count < low {
      low = count
    }
    if count > high {
      high = count
    }
  }
  high - low
}

///|
/// Return a weighted change penalty.
pub fn assignment_change_penalty(
  previous : Array[Int],
  current : Array[Int],
  penalty : Int,
) -> Int {
  assignment_changes(previous, current) *
  (if penalty < 0 { 0 } else { penalty })
}

///|
/// Summarize an assignment sequence.
pub fn assignment_metrics(
  values : Array[Int],
  category_count : Int,
  previous : Array[Int],
) -> AssignmentMetrics {
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
  let actual_categories = assignment_category_count(values)
  let categories = if category_count > actual_categories {
    category_count
  } else {
    actual_categories
  }
  {
    count: values.length(),
    categories,
    minimum,
    maximum,
    spread: maximum - minimum,
    transitions: assignment_transitions(values),
    changes: assignment_changes(previous, values),
  }
}

///|
/// Read assignment count.
pub fn AssignmentMetrics::count(self : AssignmentMetrics) -> Int {
  self.count
}

///|
/// Read category count.
pub fn AssignmentMetrics::categories(self : AssignmentMetrics) -> Int {
  self.categories
}

///|
/// Read transition count.
pub fn AssignmentMetrics::transitions(self : AssignmentMetrics) -> Int {
  self.transitions
}

///|
/// Read change count.
pub fn AssignmentMetrics::changes(self : AssignmentMetrics) -> Int {
  self.changes
}

///|
/// Return a stable metric line.
pub fn AssignmentMetrics::describe(self : AssignmentMetrics) -> String {
  "count=\{self.count}, categories=\{self.categories}, spread=\{self.spread}, transitions=\{self.transitions}, changes=\{self.changes}"
}

///|
/// Return a rolling majority label.
pub fn rolling_majority(values : Array[Int], window : Int) -> Array[Int] {
  let result : Array[Int] = []
  if window <= 0 {
    return result
  }
  for index in 0..<values.length() {
    let start = if index + 1 < window { 0 } else { index + 1 - window }
    let mut best = values[start]
    let mut best_count = 0
    for candidate in start..<(index + 1) {
      let mut count = 0
      for current in start..<(index + 1) {
        if values[current] == values[candidate] {
          count += 1
        }
      }
      if count > best_count || (count == best_count && values[candidate] < best) {
        best = values[candidate]
        best_count = count
      }
    }
    result.push(best)
  }
  result
}

///|
/// Return a stable categorical fingerprint.
pub fn assignment_signature(values : Array[Int]) -> Int {
  let mut result = 17
  for value in values {
    result = result * 31 + value
  }
  result
}

///|
/// Return whether a sequence alternates between two labels.
pub fn assignment_alternates(
  values : Array[Int],
  first : Int,
  second : Int,
) -> Bool {
  for index, value in values {
    let expected = if index % 2 == 0 { first } else { second }
    if value != expected {
      return false
    }
  }
  true
}

///|
/// Return the longest run of one label.
pub fn longest_assignment_run(values : Array[Int]) -> Int {
  if values.length() == 0 {
    return 0
  }
  let mut best = 1
  let mut current = 1
  for index in 1..<values.length() {
    if values[index] == values[index - 1] {
      current += 1
      if current > best {
        best = current
      }
    } else {
      current = 1
    }
  }
  best
}

///|
/// Return each category's longest consecutive run.
pub fn category_run_lengths(
  values : Array[Int],
  category_count : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for _ in 0..<category_count {
    result.push(0)
  }
  if values.length() == 0 {
    return result
  }
  let mut current = values[0]
  let mut length = 1
  for index in 1..<values.length() {
    if values[index] == current {
      length += 1
    } else {
      if current >= 0 && current < result.length() && length > result[current] {
        result[current] = length
      }
      current = values[index]
      length = 1
    }
  }
  if current >= 0 && current < result.length() && length > result[current] {
    result[current] = length
  }
  result
}

///|
/// Return category labels absent from a sequence.
pub fn missing_assignment_categories(
  values : Array[Int],
  category_count : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for category in 0..<category_count {
    if !values.contains(category) {
      result.push(category)
    }
  }
  result
}

///|
/// Return whether every adjacent pair is different.
pub fn pairwise_assignment_changes(values : Array[Int]) -> Bool {
  for index in 1..<values.length() {
    if values[index] == values[index - 1] {
      return false
    }
  }
  true
}
