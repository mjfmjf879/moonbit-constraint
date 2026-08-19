///|
/// Small finite-set and relation structures for domain preprocessing.
///
/// IntegerSet keeps sorted unique values and offers the operations commonly
/// needed when filtering domains, composing allowed-value tables, or
/// explaining the support of a constraint.
pub struct IntegerSet {
  values : Array[Int]
}

///|
/// Create a sorted set from arbitrary values.
pub fn integer_set(values : Array[Int]) -> IntegerSet {
  let result : Array[Int] = []
  for value in values {
    if !result.contains(value) {
      result.push(value)
    }
  }
  sort_integers(result)
  { values: result }
}

///|
/// Create a consecutive integer set.
pub fn integer_set_range(lower : Int, upper : Int) -> IntegerSet {
  let result : Array[Int] = []
  if lower <= upper {
    for value in lower..<(upper + 1) {
      result.push(value)
    }
  }
  { values: result }
}

///|
/// Return set cardinality.
pub fn IntegerSet::length(self : IntegerSet) -> Int {
  self.values.length()
}

///|
/// Return whether a value belongs to the set.
pub fn IntegerSet::contains(self : IntegerSet, value : Int) -> Bool {
  self.values.contains(value)
}

///|
/// Return copied sorted values.
pub fn IntegerSet::values(self : IntegerSet) -> Array[Int] {
  self.values.copy()
}

///|
/// Insert a value.
pub fn IntegerSet::insert(self : IntegerSet, value : Int) -> Bool {
  if self.values.contains(value) {
    return false
  }
  self.values.push(value)
  sort_integers(self.values)
  true
}

///|
/// Remove a value.
pub fn IntegerSet::remove(self : IntegerSet, value : Int) -> Bool {
  let mut index = 0
  while index < self.values.length() {
    if self.values[index] == value {
      while index + 1 < self.values.length() {
        self.values[index] = self.values[index + 1]
        index += 1
      }
      ignore(self.values.pop())
      return true
    }
    index += 1
  }
  false
}

///|
/// Return the union.
pub fn IntegerSet::union(self : IntegerSet, other : IntegerSet) -> IntegerSet {
  let values = self.values.copy()
  for value in other.values {
    values.push(value)
  }
  integer_set(values)
}

///|
/// Return the intersection.
pub fn IntegerSet::intersection(
  self : IntegerSet,
  other : IntegerSet,
) -> IntegerSet {
  let values : Array[Int] = []
  for value in self.values {
    if other.contains(value) {
      values.push(value)
    }
  }
  integer_set(values)
}

///|
/// Return values in the left set but not the right set.
pub fn IntegerSet::difference(
  self : IntegerSet,
  other : IntegerSet,
) -> IntegerSet {
  let values : Array[Int] = []
  for value in self.values {
    if !other.contains(value) {
      values.push(value)
    }
  }
  integer_set(values)
}

///|
/// Return whether every value is in another set.
pub fn IntegerSet::subset_of(self : IntegerSet, other : IntegerSet) -> Bool {
  for value in self.values {
    if !other.contains(value) {
      return false
    }
  }
  true
}

///|
/// Return the smallest value.
pub fn IntegerSet::minimum(self : IntegerSet) -> Int? {
  if self.values.length() == 0 {
    None
  } else {
    Some(self.values[0])
  }
}

///|
/// Return the largest value.
pub fn IntegerSet::maximum(self : IntegerSet) -> Int? {
  if self.values.length() == 0 {
    None
  } else {
    Some(self.values[self.values.length() - 1])
  }
}

///|
/// Return whether all values form a contiguous interval.
pub fn IntegerSet::contiguous(self : IntegerSet) -> Bool {
  if self.values.length() < 2 {
    return true
  }
  for index in 1..<self.values.length() {
    if self.values[index] != self.values[index - 1] + 1 {
      return false
    }
  }
  true
}

///|
/// Return contiguous runs as inclusive pairs.
pub fn IntegerSet::runs(self : IntegerSet) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  if self.values.length() == 0 {
    return result
  }
  let mut start = self.values[0]
  let mut previous = start
  for index in 1..<self.values.length() {
    let value = self.values[index]
    if value != previous + 1 {
      result.push((start, previous))
      start = value
    }
    previous = value
  }
  result.push((start, previous))
  result
}

///|
/// Return whether two sets are equal.
pub fn integer_sets_equal(left : IntegerSet, right : IntegerSet) -> Bool {
  same_int_array(left.values, right.values)
}

///|
/// Return a stable set representation.
pub fn IntegerSet::describe(self : IntegerSet) -> String {
  let builder = StringBuilder()
  builder.write_char('{')
  for index, value in self.values {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string("\{value}")
  }
  builder.write_char('}')
  builder.to_string()
}

///|
/// A tuple in a finite relation.
pub struct RelationPair {
  left : Int
  right : Int
}

///|
/// Construct a relation pair.
pub fn relation_pair(left : Int, right : Int) -> RelationPair {
  { left, right }
}

///|
/// A finite binary relation.
pub struct FiniteRelation {
  left_size : Int
  right_size : Int
  pairs : Array[RelationPair]
}

///|
/// Create a relation.
pub fn finite_relation(left_size : Int, right_size : Int) -> FiniteRelation {
  if left_size < 0 || right_size < 0 {
    abort("relation dimensions must be non-negative")
  }
  { left_size, right_size, pairs: [] }
}

///|
/// Add a pair.
pub fn FiniteRelation::add(
  self : FiniteRelation,
  left : Int,
  right : Int,
) -> Bool {
  if left < 0 || left >= self.left_size || right < 0 || right >= self.right_size {
    return false
  }
  for pair in self.pairs {
    if pair.left == left && pair.right == right {
      return false
    }
  }
  self.pairs.push(relation_pair(left, right))
  true
}

///|
/// Return pair count.
pub fn FiniteRelation::length(self : FiniteRelation) -> Int {
  self.pairs.length()
}

///|
/// Return pairs.
pub fn FiniteRelation::pairs(self : FiniteRelation) -> Array[RelationPair] {
  self.pairs.copy()
}

///|
/// Return right values supported by a left value.
pub fn FiniteRelation::image(self : FiniteRelation, left : Int) -> IntegerSet {
  let result : Array[Int] = []
  for pair in self.pairs {
    if pair.left == left {
      result.push(pair.right)
    }
  }
  integer_set(result)
}

///|
/// Return left values that support a right value.
pub fn FiniteRelation::preimage(
  self : FiniteRelation,
  right : Int,
) -> IntegerSet {
  let result : Array[Int] = []
  for pair in self.pairs {
    if pair.right == right {
      result.push(pair.left)
    }
  }
  integer_set(result)
}

///|
/// Return whether the relation is functional.
pub fn FiniteRelation::functional(self : FiniteRelation) -> Bool {
  for left in 0..<self.left_size {
    if self.image(left).length() > 1 {
      return false
    }
  }
  true
}

///|
/// Return whether every left value has a support.
pub fn FiniteRelation::total(self : FiniteRelation) -> Bool {
  for left in 0..<self.left_size {
    if self.image(left).length() == 0 {
      return false
    }
  }
  true
}

///|
/// Return the inverse relation.
pub fn FiniteRelation::inverse(self : FiniteRelation) -> FiniteRelation {
  let result = finite_relation(self.right_size, self.left_size)
  for pair in self.pairs {
    ignore(result.add(pair.right, pair.left))
  }
  result
}

///|
/// Compose two relations.
pub fn compose_relations(
  left : FiniteRelation,
  right : FiniteRelation,
) -> FiniteRelation? {
  if left.right_size != right.left_size {
    return None
  }
  let result = finite_relation(left.left_size, right.right_size)
  for first in left.pairs {
    for second in right.pairs {
      if first.right == second.left {
        ignore(result.add(first.left, second.right))
      }
    }
  }
  Some(result)
}

///|
/// Restrict a relation to left and right sets.
pub fn FiniteRelation::restrict(
  self : FiniteRelation,
  left : IntegerSet,
  right : IntegerSet,
) -> FiniteRelation {
  let result = finite_relation(self.left_size, self.right_size)
  for pair in self.pairs {
    if left.contains(pair.left) && right.contains(pair.right) {
      ignore(result.add(pair.left, pair.right))
    }
  }
  result
}

///|
/// Return whether a pair is present.
pub fn FiniteRelation::contains(
  self : FiniteRelation,
  left : Int,
  right : Int,
) -> Bool {
  for pair in self.pairs {
    if pair.left == left && pair.right == right {
      return true
    }
  }
  false
}

///|
/// Return a table of supported pairs.
pub fn FiniteRelation::table(self : FiniteRelation) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for left in 0..<self.left_size {
    result.push(self.image(left).values())
  }
  result
}

///|
/// Return a stable relation fingerprint.
pub fn FiniteRelation::signature(self : FiniteRelation) -> Int {
  let mut result = self.left_size * 31 + self.right_size
  for pair in self.pairs {
    result = result * 37 + pair.left * 7 + pair.right
  }
  result
}

///|
/// Build an equality relation on a finite range.
pub fn equality_relation(size : Int) -> FiniteRelation {
  let result = finite_relation(size, size)
  for value in 0..<size {
    ignore(result.add(value, value))
  }
  result
}

///|
/// Build a less-than relation.
pub fn less_than_relation(left_size : Int, right_size : Int) -> FiniteRelation {
  let result = finite_relation(left_size, right_size)
  for left in 0..<left_size {
    for right in 0..<right_size {
      if left < right {
        ignore(result.add(left, right))
      }
    }
  }
  result
}
