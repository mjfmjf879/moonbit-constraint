///|
/// A maximal contiguous segment of an integer domain.
pub struct DomainInterval {
  lower : Int
  upper : Int
} derive(Debug, Eq)

///|
/// Construct an interval.
pub fn domain_interval(lower : Int, upper : Int) -> DomainInterval {
  if lower > upper {
    abort("domain interval lower bound must not exceed upper bound")
  }
  { lower, upper }
}

///|
/// Read an interval's lower bound.
pub fn DomainInterval::lower(self : DomainInterval) -> Int {
  self.lower
}

///|
/// Read an interval's upper bound.
pub fn DomainInterval::upper(self : DomainInterval) -> Int {
  self.upper
}

///|
/// Number of integers in an interval.
pub fn DomainInterval::size(self : DomainInterval) -> Int {
  self.upper - self.lower + 1
}

///|
/// Whether a value is contained in an interval.
pub fn DomainInterval::contains(self : DomainInterval, value : Int) -> Bool {
  value >= self.lower && value <= self.upper
}

///|
/// Whether two intervals overlap or touch.
pub fn DomainInterval::touches(
  self : DomainInterval,
  other : DomainInterval,
) -> Bool {
  self.lower <= other.upper + 1 && other.lower <= self.upper + 1
}

///|
/// Return the intersection of two intervals, when it exists.
pub fn DomainInterval::intersect(
  self : DomainInterval,
  other : DomainInterval,
) -> DomainInterval? {
  let lower = if self.lower > other.lower { self.lower } else { other.lower }
  let upper = if self.upper < other.upper { self.upper } else { other.upper }
  if lower > upper {
    None
  } else {
    Some({ lower, upper })
  }
}

///|
/// Return a stable textual interval.
pub fn DomainInterval::describe(self : DomainInterval) -> String {
  if self.lower == self.upper {
    "\{self.lower}"
  } else {
    "\{self.lower}..\{self.upper}"
  }
}

///|
/// Return maximal contiguous segments of the remaining domain.
pub fn Domain::intervals(self : Domain) -> Array[DomainInterval] {
  let result : Array[DomainInterval] = []
  let values = self.values()
  if values.length() == 0 {
    return result
  }
  let mut start = values[0]
  let mut previous = values[0]
  for index in 1..<values.length() {
    let current = values[index]
    if current != previous + 1 {
      result.push({ lower: start, upper: previous })
      start = current
    }
    previous = current
  }
  result.push({ lower: start, upper: previous })
  result
}

///|
/// Render a domain as a compact union of intervals.
pub fn Domain::compact(self : Domain) -> String {
  let builder = StringBuilder()
  builder.write_char('{')
  for index, segment in self.intervals() {
    if index > 0 {
      builder.write_string(", ")
    }
    builder.write_string(segment.describe())
  }
  builder.write_char('}')
  builder.to_string()
}

///|
/// Number of values in the inclusive range that remain available.
pub fn Domain::count_range(self : Domain, lower : Int, upper : Int) -> Int {
  let mut count = 0
  if lower > upper {
    return 0
  }
  for value in self.values() {
    if value >= lower && value <= upper {
      count += 1
    }
  }
  count
}

///|
/// Return the zero-based rank of a value, if present.
pub fn Domain::rank(self : Domain, value : Int) -> Int? {
  if !self.contains(value) {
    return None
  }
  let mut rank = 0
  for candidate in self.values() {
    if candidate == value {
      return Some(rank)
    }
    rank += 1
  }
  None
}

///|
/// Return the value at a zero-based rank.
pub fn Domain::nth(self : Domain, rank : Int) -> Int? {
  if rank < 0 || rank >= self.size() {
    return None
  }
  Some(self.values()[rank])
}

///|
/// Return the smallest available value without allocating the full list.
pub fn Domain::choose_smallest(self : Domain) -> Int? {
  self.min()
}

///|
/// Return the largest available value without allocating the full list.
pub fn Domain::choose_largest(self : Domain) -> Int? {
  self.max()
}

///|
/// Sum all available values using an overflow-conscious accumulator.
pub fn Domain::sum_values(self : Domain) -> Int {
  let mut total = 0
  for value in self.values() {
    total += value
  }
  total
}

///|
/// Return whether every value in `other` also occurs in `self`.
pub fn Domain::contains_all(self : Domain, other : Domain) -> Bool {
  for value in other.values() {
    if !self.contains(value) {
      return false
    }
  }
  true
}

///|
/// Return the intersection of two domains, or `None` if it is empty.
pub fn domain_intersection(left : Domain, right : Domain) -> Domain? {
  let values : Array[Int] = []
  for value in left.values() {
    if right.contains(value) {
      values.push(value)
    }
  }
  if values.length() == 0 {
    None
  } else {
    Some(domain_from_values(values))
  }
}

///|
/// Return the union of two domains.
pub fn domain_union(left : Domain, right : Domain) -> Domain {
  let values = left.values()
  for value in right.values() {
    if !values.contains(value) {
      values.push(value)
    }
  }
  domain_from_values(values)
}

///|
/// Return values in `left` that do not occur in `right`, when non-empty.
pub fn domain_difference(left : Domain, right : Domain) -> Domain? {
  let values : Array[Int] = []
  for value in left.values() {
    if !right.contains(value) {
      values.push(value)
    }
  }
  if values.length() == 0 {
    None
  } else {
    Some(domain_from_values(values))
  }
}

///|
/// Translate every value by a constant.
pub fn Domain::domain_shift(self : Domain, offset : Int) -> Domain {
  domain_from_values(self.values().map(value => value + offset))
}

///|
/// Multiply every value by a non-zero coefficient.
pub fn Domain::domain_scale(self : Domain, coefficient : Int) -> Domain {
  if coefficient == 0 {
    return singleton_domain(0)
  }
  domain_from_values(self.values().map(value => value * coefficient))
}

///|
/// Return all pairwise sums of two domains, if any pair exists.
pub fn domain_add(left : Domain, right : Domain) -> Domain? {
  let values : Array[Int] = []
  for left_value in left.values() {
    for right_value in right.values() {
      let value = left_value + right_value
      if !values.contains(value) {
        values.push(value)
      }
    }
  }
  if values.length() == 0 {
    None
  } else {
    Some(domain_from_values(values))
  }
}

///|
/// Return all pairwise differences of two domains, if any pair exists.
pub fn domain_subtract(left : Domain, right : Domain) -> Domain? {
  let values : Array[Int] = []
  for left_value in left.values() {
    for right_value in right.values() {
      let value = left_value - right_value
      if !values.contains(value) {
        values.push(value)
      }
    }
  }
  if values.length() == 0 {
    None
  } else {
    Some(domain_from_values(values))
  }
}

///|
/// Return a summary of domain shape for instrumentation.
pub struct DomainProfile {
  minimum : Int?
  maximum : Int?
  size : Int
  interval_count : Int
  removed_count : Int
}

///|
/// Build a domain profile without exposing implementation fields.
pub fn Domain::profile(self : Domain) -> DomainProfile {
  {
    minimum: self.min(),
    maximum: self.max(),
    size: self.size(),
    interval_count: self.intervals().length(),
    removed_count: self.removed_count(),
  }
}

///|
/// Render a domain profile for metrics output.
pub fn DomainProfile::describe(self : DomainProfile) -> String {
  "min=\{Repr(self.minimum)}, max=\{Repr(self.maximum)}, size=\{self.size}, intervals=\{self.interval_count}, removed=\{self.removed_count}"
}

///|
/// Read the profile's candidate count.
pub fn DomainProfile::size(self : DomainProfile) -> Int {
  self.size
}

///|
/// Read the profile's interval count.
pub fn DomainProfile::interval_count(self : DomainProfile) -> Int {
  self.interval_count
}

///|
/// Return a domain after removing a sorted list of values.
pub fn Domain::remove_many(self : Domain, values : Array[Int]) -> Int {
  let mut removed = 0
  for value in values {
    if self.remove(value) {
      removed += 1
    }
  }
  removed
}

///|
/// Return a domain after assigning the first available value.
pub fn Domain::assign_smallest(self : Domain) -> Bool {
  match self.min() {
    Some(value) => self.assign(value)
    None => false
  }
}

///|
/// Return a domain after assigning the last available value.
pub fn Domain::assign_largest(self : Domain) -> Bool {
  match self.max() {
    Some(value) => self.assign(value)
    None => false
  }
}
