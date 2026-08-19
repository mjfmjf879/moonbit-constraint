///|
/// Small result helpers shared by CLI integrations.
pub struct ResultCounter {
  mut accepted : Int
  mut rejected : Int
}

///|
pub fn result_counter() -> ResultCounter {
  { accepted: 0, rejected: 0 }
}

///|
pub fn ResultCounter::accept(self : ResultCounter, value : Bool) -> Bool {
  if value {
    self.accepted += 1
  } else {
    self.rejected += 1
  }
  value
}

///|
pub fn ResultCounter::total(self : ResultCounter) -> Int {
  self.accepted + self.rejected
}

///|
pub fn ResultCounter::success_rate(self : ResultCounter) -> Int {
  if self.total() == 0 {
    0
  } else {
    self.accepted * 100 / self.total()
  }
}

///|
pub fn ResultCounter::passed(self : ResultCounter) -> Bool {
  self.rejected == 0
}

///|
pub fn ResultCounter::describe(self : ResultCounter) -> String {
  "accepted=\{self.accepted}, rejected=\{self.rejected}, rate=\{self.success_rate()}%"
}

///|
/// Count booleans.
pub fn count_true(values : Array[Bool]) -> Int {
  let mut result = 0
  for value in values {
    if value {
      result += 1
    }
  }
  result
}

///|
pub fn count_false(values : Array[Bool]) -> Int {
  values.length() - count_true(values)
}

///|
pub fn all_true(values : Array[Bool]) -> Bool {
  for value in values {
    if !value {
      return false
    }
  }
  true
}

///|
pub fn any_true(values : Array[Bool]) -> Bool {
  for value in values {
    if value {
      return true
    }
  }
  false
}

///|
pub fn boolean_signature(values : Array[Bool]) -> Int {
  let mut result = 17
  for value in values {
    let indicator = if value { 1 } else { 0 }
    result = result * 31 + indicator
  }
  result
}

///|
/// Convert booleans to integer indicators.
pub fn boolean_indicators(values : Array[Bool]) -> Array[Int] {
  values.map(value => if value { 1 } else { 0 })
}

///|
pub fn integer_indicators(values : Array[Int], target : Int) -> Array[Int] {
  values.map(value => if value == target { 1 } else { 0 })
}

///|
pub fn indicator_sum(values : Array[Int], target : Int) -> Int {
  integer_sum(integer_indicators(values, target))
}

///|
pub fn indicator_rate(values : Array[Int], target : Int) -> Int {
  if values.length() == 0 {
    0
  } else {
    indicator_sum(values, target) * 100 / values.length()
  }
}

///|
/// Return whether values stay inside a range.
pub fn all_in_range(values : Array[Int], lower : Int, upper : Int) -> Bool {
  for value in values {
    if value < lower || value > upper {
      return false
    }
  }
  true
}

///|
pub fn any_outside_range(values : Array[Int], lower : Int, upper : Int) -> Bool {
  !all_in_range(values, lower, upper)
}

///|
pub fn count_in_range(values : Array[Int], lower : Int, upper : Int) -> Int {
  let mut result = 0
  for value in values {
    if value >= lower && value <= upper {
      result += 1
    }
  }
  result
}

///|
pub fn range_completion(values : Array[Int], lower : Int, upper : Int) -> Int {
  if values.length() == 0 {
    0
  } else {
    count_in_range(values, lower, upper) * 100 / values.length()
  }
}

///|
/// Return a stable pairwise equality matrix.
pub fn equality_matrix(values : Array[Int]) -> IntMatrix {
  let result = int_matrix(values.length(), values.length())
  for row in 0..<values.length() {
    for column in 0..<values.length() {
      ignore(
        result.set(
          row,
          column,
          if values[row] == values[column] {
            1
          } else {
            0
          },
        ),
      )
    }
  }
  result
}

///|
pub fn difference_matrix(values : Array[Int]) -> IntMatrix {
  let result = int_matrix(values.length(), values.length())
  for row in 0..<values.length() {
    for column in 0..<values.length() {
      ignore(result.set(row, column, fm_abs(values[row] - values[column])))
    }
  }
  result
}

///|
pub fn pairwise_distance_sum(values : Array[Int]) -> Int {
  let mut result = 0
  for left in 0..<values.length() {
    for right in (left + 1)..<values.length() {
      result += fm_abs(values[left] - values[right])
    }
  }
  result
}

///|
/// Return an operational score from completion and violations.
pub fn operational_score(
  completion_percent : Int,
  violations : Int,
  penalty : Int,
) -> Int {
  let safe_penalty = if penalty < 0 { 0 } else { penalty }
  completion_percent * 1000 - violations * safe_penalty
}

///|
pub fn quality_score(review : QualityReview) -> Int {
  if review.passed() {
    1000 - review.warning_count() * 10
  } else {
    -review.failure_count() * 1000
  }
}

///|
pub fn bounded_quality_score(score : Int) -> Int {
  fm_clamp(score, -1000, 1000)
}
