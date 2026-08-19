///|
/// Exact integer mathematics used by finite-domain model builders.
pub fn fm_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
pub fn fm_min(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
pub fn fm_max(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
pub fn fm_clamp(value : Int, lower : Int, upper : Int) -> Int {
  if value < lower {
    lower
  } else if value > upper {
    upper
  } else {
    value
  }
}

///|
pub fn fm_gcd(left : Int, right : Int) -> Int {
  let mut a = fm_abs(left)
  let mut b = fm_abs(right)
  while b != 0 {
    let temporary = a % b
    a = b
    b = temporary
  }
  a
}

///|
pub fn fm_lcm(left : Int, right : Int) -> Int {
  if left == 0 || right == 0 {
    0
  } else {
    fm_abs(left / fm_gcd(left, right) * right)
  }
}

///|
pub fn fm_sign(value : Int) -> Int {
  if value < 0 {
    -1
  } else if value > 0 {
    1
  } else {
    0
  }
}

///|
pub fn fm_factorial(value : Int) -> Int {
  let mut result = 1
  if value < 0 {
    return 0
  }
  for current in 2..<(value + 1) {
    result *= current
  }
  result
}

///|
pub fn fm_choose(n : Int, k : Int) -> Int {
  if n < 0 || k < 0 || k > n {
    return 0
  }
  let reduced = if k > n - k { n - k } else { k }
  let mut result = 1
  for current in 1..<(reduced + 1) {
    result = result * (n - reduced + current) / current
  }
  result
}

///|
pub fn fm_pow(base : Int, exponent : Int) -> Int {
  if exponent < 0 {
    return 0
  }
  let mut result = 1
  for _ in 0..<exponent {
    result *= base
  }
  result
}

///|
pub fn fm_floor_div(left : Int, right : Int) -> Int {
  if right == 0 {
    return 0
  }
  let quotient = left / right
  let remainder = left % right
  if remainder != 0 && (remainder > 0) != (right > 0) {
    quotient - 1
  } else {
    quotient
  }
}

///|
pub fn fm_ceil_div(left : Int, right : Int) -> Int {
  if right == 0 {
    return 0
  }
  let quotient = left / right
  let remainder = left % right
  if remainder != 0 && (remainder > 0) == (right > 0) {
    quotient + 1
  } else {
    quotient
  }
}

///|
pub fn fm_range_sum(lower : Int, upper : Int) -> Int {
  if lower > upper {
    0
  } else {
    (lower + upper) * (upper - lower + 1) / 2
  }
}

///|
pub fn fm_arithmetic_mean(left : Int, right : Int) -> Int {
  (left + right) / 2
}

///|
pub fn fm_midpoint(lower : Int, upper : Int) -> Int {
  lower + (upper - lower) / 2
}

///|
pub fn fm_distance(left : Int, right : Int) -> Int {
  fm_abs(left - right)
}

///|
pub fn fm_is_even(value : Int) -> Bool {
  value % 2 == 0
}

///|
pub fn fm_is_odd(value : Int) -> Bool {
  value % 2 != 0
}

///|
pub fn fm_is_prime(value : Int) -> Bool {
  if value < 2 {
    return false
  }
  let mut divisor = 2
  while divisor * divisor <= value {
    if value % divisor == 0 {
      return false
    }
    divisor += 1
  }
  true
}

///|
pub fn fm_next_prime(value : Int) -> Int {
  let mut candidate = if value < 2 { 2 } else { value }
  while !fm_is_prime(candidate) {
    candidate += 1
  }
  candidate
}

///|
pub fn fm_count_primes(lower : Int, upper : Int) -> Int {
  let mut result = 0
  for value in lower..<(upper + 1) {
    if fm_is_prime(value) {
      result += 1
    }
  }
  result
}

///|
pub fn fm_dot(left : Array[Int], right : Array[Int]) -> Int {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  let mut result = 0
  for index in 0..<limit {
    result += left[index] * right[index]
  }
  result
}

///|
pub fn fm_l1(values : Array[Int]) -> Int {
  let mut result = 0
  for value in values {
    result += fm_abs(value)
  }
  result
}

///|
pub fn fm_linf(values : Array[Int]) -> Int {
  let mut result = 0
  for value in values {
    if fm_abs(value) > result {
      result = fm_abs(value)
    }
  }
  result
}

///|
pub fn fm_range(values : Array[Int]) -> Int {
  if values.length() == 0 {
    0
  } else {
    integer_summary(values).maximum - integer_summary(values).minimum
  }
}

///|
pub fn fm_weighted_sum(values : Array[Int], weights : Array[Int]) -> Int {
  fm_dot(values, weights)
}

///|
pub fn fm_weighted_average(values : Array[Int], weights : Array[Int]) -> Int {
  let total = integer_sum(weights)
  if total == 0 {
    0
  } else {
    fm_dot(values, weights) / total
  }
}

///|
pub fn fm_prefix(values : Array[Int]) -> Array[Int] {
  sequence_cumulative(values)
}

///|
pub fn fm_suffix(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  let mut total = 0
  let input_last = values.length() - 1
  for index in input_last>=..0 {
    total += values[index]
    result.push(total)
  }
  let last = result.length() - 1
  let half = result.length() / 2
  for index in 0..<half {
    let other = last - index
    let temporary = result[index]
    result[index] = result[other]
    result[other] = temporary
  }
  result
}

///|
pub fn fm_rotate(values : Array[Int], offset : Int) -> Array[Int] {
  let result : Array[Int] = []
  if values.length() == 0 {
    return result
  }
  let shift = fm_mod_positive(offset, values.length())
  for index in 0..<values.length() {
    result.push(values[(index + shift) % values.length()])
  }
  result
}

///|
pub fn fm_reverse(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  let last = values.length() - 1
  for index in last>=..0 {
    result.push(values[index])
  }
  result
}

///|
pub fn fm_take(values : Array[Int], count : Int) -> Array[Int] {
  let result : Array[Int] = []
  let limit = if count < 0 {
    0
  } else if count > values.length() {
    values.length()
  } else {
    count
  }
  for index in 0..<limit {
    result.push(values[index])
  }
  result
}

///|
pub fn fm_drop(values : Array[Int], count : Int) -> Array[Int] {
  let result : Array[Int] = []
  let start = if count < 0 {
    0
  } else if count > values.length() {
    values.length()
  } else {
    count
  }
  for index in start..<values.length() {
    result.push(values[index])
  }
  result
}

///|
pub fn fm_chunk(values : Array[Int], size : Int) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  if size <= 0 {
    return result
  }
  let mut start = 0
  while start < values.length() {
    let row : Array[Int] = []
    let end = if start + size > values.length() {
      values.length()
    } else {
      start + size
    }
    for index in start..<end {
      row.push(values[index])
    }
    result.push(row)
    start = end
  }
  result
}

///|
pub fn fm_count_value(values : Array[Int], target : Int) -> Int {
  let mut result = 0
  for value in values {
    if value == target {
      result += 1
    }
  }
  result
}

///|
pub fn fm_contains_all(values : Array[Int], required : Array[Int]) -> Bool {
  for value in required {
    if !values.contains(value) {
      return false
    }
  }
  true
}

///|
pub fn fm_unique(values : Array[Int]) -> Array[Int] {
  integer_set(values).values()
}

///|
pub fn fm_union(left : Array[Int], right : Array[Int]) -> Array[Int] {
  integer_set(left).union(integer_set(right)).values()
}

///|
pub fn fm_intersection(left : Array[Int], right : Array[Int]) -> Array[Int] {
  integer_set(left).intersection(integer_set(right)).values()
}

///|
pub fn fm_difference(left : Array[Int], right : Array[Int]) -> Array[Int] {
  integer_set(left).difference(integer_set(right)).values()
}

///|
pub fn fm_argmin(values : Array[Int]) -> Int? {
  if values.length() == 0 {
    return None
  }
  let mut result = 0
  for index in 1..<values.length() {
    if values[index] < values[result] {
      result = index
    }
  }
  Some(result)
}

///|
pub fn fm_argmax(values : Array[Int]) -> Int? {
  if values.length() == 0 {
    return None
  }
  let mut result = 0
  for index in 1..<values.length() {
    if values[index] > values[result] {
      result = index
    }
  }
  Some(result)
}

///|
pub fn fm_rank(value : Int, values : Array[Int]) -> Int {
  let mut result = 0
  for candidate in values {
    if candidate < value {
      result += 1
    }
  }
  result
}

///|
pub fn fm_quantize(value : Int, step : Int) -> Int {
  if step <= 0 {
    value
  } else {
    fm_floor_div(value, step) * step
  }
}

///|
pub fn fm_bucket(value : Int, lower : Int, width : Int) -> Int {
  if width <= 0 {
    0
  } else {
    fm_floor_div(value - lower, width)
  }
}

///|
pub fn fm_interpolate(
  left : Int,
  right : Int,
  numerator : Int,
  denominator : Int,
) -> Int {
  if denominator == 0 {
    left
  } else {
    left + (right - left) * numerator / denominator
  }
}

///|
pub fn fm_percent(value : Int, total : Int) -> Int {
  if total == 0 {
    0
  } else {
    value * 100 / total
  }
}

///|
pub fn fm_saturating_add(left : Int, right : Int, upper : Int) -> Int {
  let value = left + right
  if value > upper {
    upper
  } else {
    value
  }
}

///|
pub fn fm_saturating_sub(left : Int, right : Int, lower : Int) -> Int {
  let value = left - right
  if value < lower {
    lower
  } else {
    value
  }
}

///|
pub fn fm_signum_sum(values : Array[Int]) -> Int {
  let mut result = 0
  for value in values {
    result += fm_sign(value)
  }
  result
}

///|
pub fn fm_alternating_sum(values : Array[Int]) -> Int {
  let mut result = 0
  for index, value in values {
    if fm_is_even(index) {
      result += value
    } else {
      result -= value
    }
  }
  result
}

///|
pub fn fm_mod_positive(value : Int, modulus : Int) -> Int {
  if modulus <= 0 {
    0
  } else {
    let result = value % modulus
    if result < 0 {
      result + modulus
    } else {
      result
    }
  }
}

///|
pub fn fm_wrap(value : Int, lower : Int, upper : Int) -> Int {
  if lower > upper {
    lower
  } else {
    lower + fm_mod_positive(value - lower, upper - lower + 1)
  }
}

///|
pub fn fm_clamp_array(
  values : Array[Int],
  lower : Int,
  upper : Int,
) -> Array[Int] {
  values.map(value => fm_clamp(value, lower, upper))
}

///|
pub fn fm_map_sign(values : Array[Int]) -> Array[Int] {
  values.map(value => fm_sign(value))
}

///|
pub fn fm_nonzero(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  for value in values {
    if value != 0 {
      result.push(value)
    }
  }
  result
}

///|
pub fn fm_repeat(value : Int, count : Int) -> Array[Int] {
  let result : Array[Int] = []
  for _ in 0..<count {
    result.push(value)
  }
  result
}

///|
pub fn fm_identity_permutation(size : Int) -> Array[Int] {
  let result : Array[Int] = []
  for value in 0..<size {
    result.push(value)
  }
  result
}

///|
pub fn fm_is_permutation(values : Array[Int], size : Int) -> Bool {
  if values.length() != size {
    return false
  }
  for value in 0..<size {
    if fm_count_value(values, value) != 1 {
      return false
    }
  }
  true
}

///|
pub fn fm_permutation_parity(values : Array[Int]) -> Int {
  let mut inversions = 0
  for left in 0..<values.length() {
    for right in (left + 1)..<values.length() {
      if values[left] > values[right] {
        inversions += 1
      }
    }
  }
  inversions % 2
}

///|
pub fn fm_swap(values : Array[Int], left : Int, right : Int) -> Bool {
  if left < 0 ||
    right < 0 ||
    left >= values.length() ||
    right >= values.length() {
    return false
  }
  let temporary = values[left]
  values[left] = values[right]
  values[right] = temporary
  true
}

///|
pub fn fm_sorted(values : Array[Int]) -> Array[Int] {
  let result = values.copy()
  sort_integers(result)
  result
}

///|
pub fn fm_is_sorted(values : Array[Int]) -> Bool {
  for index in 1..<values.length() {
    if values[index] < values[index - 1] {
      return false
    }
  }
  true
}

///|
pub fn fm_is_strictly_sorted(values : Array[Int]) -> Bool {
  for index in 1..<values.length() {
    if values[index] <= values[index - 1] {
      return false
    }
  }
  true
}

///|
pub fn fm_manhattan(left : Array[Int], right : Array[Int]) -> Int {
  let mut result = 0
  for index, value in left {
    let other = if index < right.length() { right[index] } else { 0 }
    result += fm_abs(value - other)
  }
  result
}

///|
pub fn fm_hamming(left : Array[Int], right : Array[Int]) -> Int {
  assignment_hamming_distance(left, right)
}

///|
pub fn fm_checksum(values : Array[Int]) -> Int {
  sequence_checksum(values)
}
