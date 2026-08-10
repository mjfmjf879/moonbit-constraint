///|
/// A finite integer domain represented by an inclusive interval and holes.
pub struct Domain {
  lower : Int
  upper : Int
  mut removed : Array[Int]
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
/// Narrow the domain to one value.
pub fn Domain::assign(self : Domain, value : Int) -> Bool {
  if !self.contains(value) {
    return false
  }
  self.removed = self.values().filter(v => v != value)
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
