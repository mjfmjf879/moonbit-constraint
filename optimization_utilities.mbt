///|
/// Integer optimization utilities for candidate plans.
pub struct IntegerObjective {
  values : Array[Int]
  directions : Array[PortfolioDirection]
}

///|
/// Create an objective vector.
pub fn integer_objective(
  values : Array[Int],
  directions : Array[PortfolioDirection],
) -> IntegerObjective {
  { values: values.copy(), directions: directions.copy() }
}

///|
/// Return objective dimension.
pub fn IntegerObjective::length(self : IntegerObjective) -> Int {
  self.values.length()
}

///|
/// Return whether this vector dominates another.
pub fn IntegerObjective::dominates(
  self : IntegerObjective,
  other : IntegerObjective,
) -> Bool {
  if self.values.length() != other.values.length() {
    return false
  }
  let mut strict = false
  for index in 0..<self.values.length() {
    let direction = if index < self.directions.length() {
      self.directions[index]
    } else {
      Minimize
    }
    let better = if direction is Minimize {
      self.values[index] <= other.values[index]
    } else {
      self.values[index] >= other.values[index]
    }
    if !better {
      return false
    }
    if self.values[index] != other.values[index] {
      strict = true
    }
  }
  strict
}

///|
/// Compare vectors lexicographically.
pub fn IntegerObjective::compare(
  self : IntegerObjective,
  other : IntegerObjective,
) -> Int {
  let limit = if self.values.length() < other.values.length() {
    self.values.length()
  } else {
    other.values.length()
  }
  for index in 0..<limit {
    if self.values[index] == other.values[index] {
      continue
    }
    let direction = if index < self.directions.length() {
      self.directions[index]
    } else {
      Minimize
    }
    let better = if direction is Minimize {
      self.values[index] < other.values[index]
    } else {
      self.values[index] > other.values[index]
    }
    return if better { -1 } else { 1 }
  }
  if self.values.length() == other.values.length() {
    0
  } else if self.values.length() < other.values.length() {
    -1
  } else {
    1
  }
}

///|
/// Return copied objective values.
pub fn IntegerObjective::values(self : IntegerObjective) -> Array[Int] {
  self.values.copy()
}

///|
/// A weighted item used by integer knapsack helpers.
pub struct UtilityItem {
  id : Int
  weight : Int
  value : Int
}

///|
/// Create a utility item.
pub fn utility_item(id : Int, weight : Int, value : Int) -> UtilityItem {
  { id, weight: if weight < 0 { 0 } else { weight }, value }
}

///|
/// Return value density using a scale factor.
pub fn UtilityItem::density(self : UtilityItem, scale : Int) -> Int {
  if self.weight == 0 {
    return self.value * scale
  }
  self.value * scale / self.weight
}

///|
/// Select a greedy value-density subset.
pub fn greedy_utility_subset(
  items : Array[UtilityItem],
  capacity : Int,
) -> Array[Int] {
  let order = items.copy()
  for left in 0..<order.length() {
    for right in (left + 1)..<order.length() {
      if order[right].density(1000) > order[left].density(1000) {
        let temporary = order[left]
        order[left] = order[right]
        order[right] = temporary
      }
    }
  }
  let result : Array[Int] = []
  let mut load = 0
  for item in order {
    if load + item.weight <= capacity {
      result.push(item.id)
      load += item.weight
    }
  }
  result
}

///|
/// Return total weight of selected items.
pub fn utility_subset_weight(
  items : Array[UtilityItem],
  selected : Array[Int],
) -> Int {
  let mut result = 0
  for item in items {
    if selected.contains(item.id) {
      result += item.weight
    }
  }
  result
}

///|
/// Return total value of selected items.
pub fn utility_subset_value(
  items : Array[UtilityItem],
  selected : Array[Int],
) -> Int {
  let mut result = 0
  for item in items {
    if selected.contains(item.id) {
      result += item.value
    }
  }
  result
}

///|
/// Validate a selected subset.
pub fn validate_utility_subset(
  items : Array[UtilityItem],
  selected : Array[Int],
  capacity : Int,
) -> Bool {
  if utility_subset_weight(items, selected) > capacity {
    return false
  }
  for left in 0..<selected.length() {
    for right in 0..<left {
      if selected[left] == selected[right] {
        return false
      }
    }
  }
  true
}

///|
/// Return the best single-item replacement for a selected subset.
pub fn utility_best_swap(
  items : Array[UtilityItem],
  selected : Array[Int],
  capacity : Int,
) -> (Array[Int], Bool) {
  let result = selected.copy()
  let before = utility_subset_value(items, result)
  for item in items {
    if result.contains(item.id) {
      continue
    }
    for index in 0..<result.length() {
      let removed = result[index]
      result[index] = item.id
      if validate_utility_subset(items, result, capacity) &&
        utility_subset_value(items, result) > before {
        return (result, true)
      }
      result[index] = removed
    }
  }
  (result, false)
}

///|
/// Improve a subset through repeated swaps.
pub fn improve_utility_subset(
  items : Array[UtilityItem],
  selected : Array[Int],
  capacity : Int,
) -> Array[Int] {
  let result = selected.copy()
  let mut changed = true
  while changed {
    let replacement = utility_best_swap(items, result, capacity)
    if replacement.1 {
      for index in 0..<result.length() {
        result[index] = replacement.0[index]
      }
    } else {
      changed = false
    }
  }
  result
}

///|
/// Return a scaled weighted score.
pub fn weighted_score(values : Array[Int], weights : Array[Int]) -> Int {
  let limit = if values.length() < weights.length() {
    values.length()
  } else {
    weights.length()
  }
  let mut result = 0
  for index in 0..<limit {
    result += values[index] * weights[index]
  }
  result
}

///|
/// Return a lexicographically best row.
pub fn best_objective_row(
  rows : Array[Array[Int]],
  directions : Array[PortfolioDirection],
) -> Array[Int]? {
  if rows.length() == 0 {
    return None
  }
  let mut result = rows[0]
  for row in rows {
    let candidate = integer_objective(row, directions)
    let incumbent = integer_objective(result, directions)
    if candidate.compare(incumbent) < 0 {
      result = row
    }
  }
  Some(result.copy())
}

///|
/// Return nondominated rows.
pub fn pareto_rows(
  rows : Array[Array[Int]],
  directions : Array[PortfolioDirection],
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for row in rows {
    let candidate = integer_objective(row, directions)
    let mut dominated = false
    for other in rows {
      if !same_int_array(row, other) &&
        integer_objective(other, directions).dominates(candidate) {
        dominated = true
      }
    }
    if !dominated {
      result.push(row.copy())
    }
  }
  result
}

///|
/// Return an objective row signature.
pub fn objective_row_signature(row : Array[Int]) -> Int {
  let mut result = 23
  for value in row {
    result = result * 37 + value
  }
  result
}

///|
/// Return a min/max normalized score.
pub fn normalize_objective(value : Int, lower : Int, upper : Int) -> Int {
  if upper <= lower {
    return 0
  }
  (value - lower) * 1000 / (upper - lower)
}

///|
/// Return whether an objective value meets a bound.
pub fn objective_meets(
  direction : PortfolioDirection,
  value : Int,
  bound : Int,
) -> Bool {
  if direction is Minimize {
    value <= bound
  } else {
    value >= bound
  }
}
