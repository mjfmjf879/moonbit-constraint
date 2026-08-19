///|
/// A minimum-cost set-covering model.
pub struct SetCovering {
  solver : Solver
  selected : Array[Int]
  costs : Array[Int]
  total_cost : Int
  universe_size : Int
}

///|
/// Build a covering problem. Each row lists the universe elements covered by
/// one candidate set; every universe element must be covered at least once.
pub fn set_covering(
  universe_size : Int,
  covers : Array[Array[Int]],
  costs : Array[Int],
) -> SetCovering? {
  if universe_size < 1 ||
    covers.length() == 0 ||
    covers.length() != costs.length() {
    return None
  }
  let solver = new_solver()
  let selected : Array[Int] = []
  for index in 0..<covers.length() {
    if costs[index] < 0 {
      return None
    }
    for element in covers[index] {
      if element < 0 || element >= universe_size {
        return None
      }
    }
    selected.push(solver.add_variable(variable("set_\{index}", 0, 1)))
  }
  for element in 0..<universe_size {
    let candidates : Array[Int] = []
    for index, cover in covers {
      if cover.contains(element) {
        candidates.push(selected[index])
      }
    }
    if candidates.length() == 0 {
      return None
    }
    solver.add_constraint(at_least_value(candidates, 1, 1))
  }
  let terms : Array[(Int, Int)] = []
  let total_max = costs.fold(init=0, (total, value) => total + value)
  for index in 0..<selected.length() {
    terms.push((selected[index], costs[index]))
  }
  let total_cost = solver.add_variable(variable("cover_cost", 0, total_max))
  terms.push((total_cost, -1))
  solver.add_constraint(linear(terms, 0))
  Some({ solver, selected, costs: costs.copy(), total_cost, universe_size })
}

///|
/// Solve for a minimum-cost covering.
pub fn SetCovering::solve(self : SetCovering) -> OptimizationResult? {
  self.solver.optimize(self.total_cost, minimize())
}

///|
/// Return selected set indices.
pub fn SetCovering::selected_sets(
  self : SetCovering,
  solution : Solution,
) -> Array[Int] {
  let result : Array[Int] = []
  for index, variable in self.selected {
    if solution.get(variable) == 1 {
      result.push(index)
    }
  }
  result
}

///|
/// Return total covering cost.
pub fn SetCovering::cost(self : SetCovering, solution : Solution) -> Int {
  solution.get(self.total_cost)
}

///|
/// Return whether every universe element is covered.
pub fn SetCovering::covers_all(
  self : SetCovering,
  solution : Solution,
  covers : Array[Array[Int]],
) -> Bool {
  if !self.solver.is_valid_solution(solution) ||
    covers.length() != self.selected.length() {
    return false
  }
  let covered = Set([])
  for index, variable in self.selected {
    if solution.get(variable) == 1 {
      for element in covers[index] {
        covered.add(element)
      }
    }
  }
  covered.length() == self.universe_size
}

///|
/// Render a covering solution.
pub fn SetCovering::render(self : SetCovering, solution : Solution) -> String {
  "sets=\{Repr(self.selected_sets(solution))}, cost=\{self.cost(solution)}"
}

///|
/// Return solver statistics.
pub fn SetCovering::stats(self : SetCovering) -> SearchStats {
  self.solver.stats()
}

///|
/// A bin-packing assignment model using one-hot item/bin variables.
pub struct BinPacking {
  solver : Solver
  assignments : Array[Array[Int]]
  items : Int
  bins : Int
  weights : Array[Int]
  capacity : Int
}

///|
/// Build a fixed-bin packing problem.
pub fn bin_packing(
  weights : Array[Int],
  bins : Int,
  capacity : Int,
) -> BinPacking? {
  if weights.length() == 0 || bins < 1 || capacity < 1 {
    return None
  }
  let solver = new_solver()
  let assignments : Array[Array[Int]] = []
  for item, weight in weights {
    if weight < 0 || weight > capacity {
      return None
    }
    let row : Array[Int] = []
    for bin in 0..<bins {
      row.push(solver.add_variable(variable("item_\{item}_bin_\{bin}", 0, 1)))
    }
    post_exactly_one(solver, row)
    assignments.push(row)
  }
  for bin in 0..<bins {
    let terms : Array[(Int, Int)] = []
    for item in 0..<weights.length() {
      terms.push((assignments[item][bin], weights[item]))
    }
    solver.add_constraint(linear_less_equal(terms, capacity))
  }
  Some({
    solver,
    assignments,
    items: weights.length(),
    bins,
    weights: weights.copy(),
    capacity,
  })
}

///|
/// Solve the packing model.
pub fn BinPacking::solve(self : BinPacking) -> Solution? {
  self.solver.solve()
}

///|
/// Return the selected bin for an item.
pub fn BinPacking::bin_of(
  self : BinPacking,
  solution : Solution,
  item : Int,
) -> Int? {
  if item < 0 || item >= self.items {
    return None
  }
  for bin in 0..<self.bins {
    if solution.get(self.assignments[item][bin]) == 1 {
      return Some(bin)
    }
  }
  None
}

///|
/// Return the bin load vector.
pub fn BinPacking::loads(self : BinPacking, solution : Solution) -> Array[Int] {
  let loads = Array::make(self.bins, 0)
  for item in 0..<self.items {
    for bin in 0..<self.bins {
      if solution.get(self.assignments[item][bin]) == 1 {
        loads[bin] += self.weights[item]
      }
    }
  }
  loads
}

///|
/// Validate a packing solution.
pub fn BinPacking::is_valid(self : BinPacking, solution : Solution) -> Bool {
  if !self.solver.is_valid_solution(solution) {
    return false
  }
  for load in self.loads(solution) {
    if load > self.capacity {
      return false
    }
  }
  true
}

///|
/// Return solver statistics.
pub fn BinPacking::stats(self : BinPacking) -> SearchStats {
  self.solver.stats()
}

///|
/// Render bin loads and item assignments.
pub fn BinPacking::render(self : BinPacking, solution : Solution) -> String {
  "loads=\{Repr(self.loads(solution))}, valid=\{self.is_valid(solution)}"
}

///|
/// Build a partition model with two groups and an exact target sum.
pub fn two_way_partition(values : Array[Int], target : Int) -> BinPacking? {
  match bin_packing(values, 2, 2147483647) {
    None => None
    Some(problem) => {
      let terms : Array[(Int, Int)] = []
      for item in 0..<values.length() {
        terms.push((problem.assignments[item][0], values[item]))
      }
      problem.solver.add_constraint(linear(terms, target))
      Some(problem)
    }
  }
}

///|
/// Return a fixed cover model for the common interval-covering case.
pub fn interval_cover(
  universe_size : Int,
  intervals : Array[(Int, Int)],
) -> SetCovering? {
  let covers : Array[Array[Int]] = []
  let costs : Array[Int] = []
  for interval in intervals {
    let (lower, upper) = interval
    if lower < 0 || upper >= universe_size || lower > upper {
      return None
    }
    let elements : Array[Int] = []
    for element in lower..<=upper {
      elements.push(element)
    }
    covers.push(elements)
    costs.push(upper - lower + 1)
  }
  set_covering(universe_size, covers, costs)
}
