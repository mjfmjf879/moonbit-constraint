///|
/// A finite integer domain represented by an inclusive interval and holes.
pub struct Domain {
  lower : Int
  upper : Int
  removed : Array[Int]
} derive(Debug)

///|
/// Create a domain containing every integer in `[lower, upper]`.
pub fn domain(lower : Int, upper : Int) -> Domain {
  if lower > upper {
    abort("domain lower bound must not exceed upper bound")
  }
  { lower, upper, removed: [] }
}

///|
/// Create a domain containing one value.
pub fn singleton_domain(value : Int) -> Domain {
  { lower: value, upper: value, removed: [] }
}

///|
/// Create a domain from an arbitrary set of values.
///
/// Values outside the smallest enclosing interval are not stored separately;
/// the interval is kept as the compact representation and the missing values
/// are recorded as holes. Duplicate values are ignored.
pub fn domain_from_values(values : Array[Int]) -> Domain {
  if values.length() == 0 {
    abort("domain_from_values requires at least one value")
  }
  let mut lower = values[0]
  let mut upper = values[0]
  for value in values {
    if value < lower {
      lower = value
    }
    if value > upper {
      upper = value
    }
  }
  let result = { lower, upper, removed: [] }
  for value in lower..<=upper {
    if !values.contains(value) {
      ignore(result.remove(value))
    }
  }
  result
}

///|
/// Make an independent copy of a domain.
pub fn Domain::clone(self : Domain) -> Domain {
  { lower: self.lower, upper: self.upper, removed: self.removed.copy() }
}

///|
/// Restore the removed-value state from another domain with the same interval.
/// This is used by incremental solver probes to make temporary assumptions
/// fully reversible after propagation and search.
pub fn Domain::restore(self : Domain, snapshot : Domain) -> Unit {
  if self.lower != snapshot.lower || self.upper != snapshot.upper {
    abort("cannot restore a domain with a different interval")
  }
  while self.removed.length() > 0 {
    ignore(self.removed.pop())
  }
  for value in snapshot.removed {
    self.removed.push(value)
  }
}

///|
/// Return the smallest value in the domain, or `None` when it is empty.
pub fn Domain::min(self : Domain) -> Int? {
  for value in self.lower..<=self.upper {
    if self.contains(value) {
      return Some(value)
    }
  }
  None
}

///|
/// Return the largest value in the domain, or `None` when it is empty.
pub fn Domain::max(self : Domain) -> Int? {
  for value in self.upper>=..self.lower {
    if self.contains(value) {
      return Some(value)
    }
  }
  None
}

///|
/// Test whether `value` is still available.
pub fn Domain::contains(self : Domain, value : Int) -> Bool {
  value >= self.lower && value <= self.upper && !self.removed.contains(value)
}

///|
/// Return the fixed lower endpoint of the original interval.
pub fn Domain::interval_lower(self : Domain) -> Int {
  self.lower
}

///|
/// Return the fixed upper endpoint of the original interval.
pub fn Domain::interval_upper(self : Domain) -> Int {
  self.upper
}

///|
/// Return all available values in ascending order.
pub fn Domain::values(self : Domain) -> Array[Int] {
  let result : Array[Int] = []
  for value in self.lower..<=self.upper {
    if self.contains(value) {
      result.push(value)
    }
  }
  result
}

///|
/// Number of values still available.
pub fn Domain::size(self : Domain) -> Int {
  self.values().length()
}

///|
/// Whether no value remains in the domain.
pub fn Domain::is_empty(self : Domain) -> Bool {
  self.min() is None
}

///|
/// Whether every value in the enclosing interval is still available.
pub fn Domain::is_contiguous(self : Domain) -> Bool {
  self.removed.length() == 0
}

///|
/// Return the first available value at or above `value`.
pub fn Domain::next(self : Domain, value : Int) -> Int? {
  let start = if value < self.lower { self.lower } else { value }
  if start > self.upper {
    return None
  }
  for candidate in start..<=self.upper {
    if self.contains(candidate) {
      return Some(candidate)
    }
  }
  None
}

///|
/// Return the last available value at or below `value`.
pub fn Domain::previous(self : Domain, value : Int) -> Int? {
  let start = if value > self.upper { self.upper } else { value }
  if start < self.lower {
    return None
  }
  for candidate in start>=..self.lower {
    if self.contains(candidate) {
      return Some(candidate)
    }
  }
  None
}

///|
/// Remove every value below `lower` and report whether the domain changed.
pub fn Domain::remove_below(self : Domain, lower : Int) -> Bool {
  let mut changed = false
  for value in self.lower..<=self.upper {
    if value < lower && self.remove(value) {
      changed = true
    }
  }
  changed
}

///|
/// Remove every value above `upper` and report whether the domain changed.
pub fn Domain::remove_above(self : Domain, upper : Int) -> Bool {
  let mut changed = false
  for value in self.lower..<=self.upper {
    if value > upper && self.remove(value) {
      changed = true
    }
  }
  changed
}

///|
/// Keep only values that also occur in `allowed`.
pub fn Domain::intersect_values(self : Domain, allowed : Array[Int]) -> Bool {
  let mut changed = false
  for value in self.values() {
    if !allowed.contains(value) && self.remove(value) {
      changed = true
    }
  }
  changed
}

///|
/// Keep only values in the inclusive range.
pub fn Domain::intersect_range(self : Domain, lower : Int, upper : Int) -> Bool {
  if lower > upper {
    let mut changed = false
    for value in self.values() {
      if self.remove(value) {
        changed = true
      }
    }
    return changed
  }
  let changed_below = self.remove_below(lower)
  let changed_above = self.remove_above(upper)
  changed_below || changed_above
}

///|
/// Return the only value when this domain is a singleton.
pub fn Domain::singleton(self : Domain) -> Int? {
  if self.size() != 1 {
    return None
  }
  self.min()
}

///|
/// Return the number of removed values in the enclosing interval.
pub fn Domain::removed_count(self : Domain) -> Int {
  self.removed.length()
}

///|
/// Return a stable textual form useful in diagnostics and benchmark output.
pub fn Domain::describe(self : Domain) -> String {
  let values = self.values()
  if values.length() == 0 {
    return "{}"
  }
  let builder = StringBuilder()
  builder.write_char('{')
  for index, value in values {
    if index > 0 {
      builder.write_string(", ")
    }
    builder.write_string("\{value}")
  }
  builder.write_char('}')
  builder.to_string()
}

///|
/// Narrow the domain to one value.
pub fn Domain::assign(self : Domain, value : Int) -> Bool {
  if !self.contains(value) {
    return false
  }
  for candidate in self.values() {
    if candidate != value {
      self.removed.push(candidate)
    }
  }
  true
}

///|
/// Remove one value. Returns whether the domain changed.
pub fn Domain::remove(self : Domain, value : Int) -> Bool {
  if !self.contains(value) {
    return false
  }
  self.removed.push(value)
  true
}

///|
/// Check whether the domain has exactly one value.
pub fn Domain::is_singleton(self : Domain) -> Bool {
  self.size() == 1
}
