///|
/// Capacity-aware allocation models for packing and resource assignment.
///
/// The model separates item data from a mutable candidate plan. This makes it
/// suitable for greedy seed construction, neighborhood improvement, and
/// validation before the assignment is handed to a finite-domain Solver.
pub struct AllocationItem {
  id : Int
  weight : Int
  value : Int
  group : Int
}

///|
/// Construct an allocation item.
pub fn allocation_item(
  id : Int,
  weight : Int,
  value : Int,
  group : Int,
) -> AllocationItem {
  { id, weight: if weight < 0 { 0 } else { weight }, value, group }
}

///|
/// Read the item identifier.
pub fn AllocationItem::id(self : AllocationItem) -> Int {
  self.id
}

///|
/// Read the item weight.
pub fn AllocationItem::weight(self : AllocationItem) -> Int {
  self.weight
}

///|
/// Read the item value.
pub fn AllocationItem::value(self : AllocationItem) -> Int {
  self.value
}

///|
/// Read the group identifier.
pub fn AllocationItem::group(self : AllocationItem) -> Int {
  self.group
}

///|
/// A validated collection of item and bin data.
pub struct AllocationInstance {
  items : Array[AllocationItem]
  capacities : Array[Int]
  group_limits : Array[(Int, Int, Int, Int)]
}

///|
/// Create an allocation instance with no group limits.
pub fn allocation_instance(
  items : Array[AllocationItem],
  capacities : Array[Int],
) -> AllocationInstance? {
  if capacities.length() == 0 {
    return None
  }
  for index, item in items {
    if item.id != index || item.weight < 0 {
      return None
    }
  }
  for capacity in capacities {
    if capacity < 0 {
      return None
    }
  }
  Some({ items: items.copy(), capacities: capacities.copy(), group_limits: [] })
}

///|
/// Add a lower and upper count for a group on one bin.
pub fn AllocationInstance::add_group_limit(
  self : AllocationInstance,
  bin : Int,
  group : Int,
  minimum : Int,
  maximum : Int,
) -> Bool {
  if bin < 0 ||
    bin >= self.capacities.length() ||
    minimum < 0 ||
    maximum < minimum {
    return false
  }
  self.group_limits.push((bin, group, minimum, maximum))
  true
}

///|
/// Return the number of items.
pub fn AllocationInstance::item_count(self : AllocationInstance) -> Int {
  self.items.length()
}

///|
/// Return the number of bins.
pub fn AllocationInstance::bin_count(self : AllocationInstance) -> Int {
  self.capacities.length()
}

///|
/// Read an item.
pub fn AllocationInstance::item(
  self : AllocationInstance,
  id : Int,
) -> AllocationItem {
  if id < 0 || id >= self.items.length() {
    abort("allocation item is outside the instance")
  }
  self.items[id]
}

///|
/// Read a bin capacity.
pub fn AllocationInstance::capacity(
  self : AllocationInstance,
  bin : Int,
) -> Int {
  if bin < 0 || bin >= self.capacities.length() {
    abort("allocation bin is outside the instance")
  }
  self.capacities[bin]
}

///|
/// A partial or complete item-to-bin assignment.
pub struct AllocationPlan {
  assignments : Array[Int]
}

///|
/// Create an unassigned plan.
pub fn allocation_plan(instance : AllocationInstance) -> AllocationPlan {
  let assignments : Array[Int] = []
  for _ in instance.items {
    assignments.push(-1)
  }
  { assignments, }
}

///|
/// Read the assigned bin, or -1 when unassigned.
pub fn AllocationPlan::assigned_bin(self : AllocationPlan, item : Int) -> Int {
  if item < 0 || item >= self.assignments.length() {
    return -1
  }
  self.assignments[item]
}

///|
/// Assign an item to a bin without checking capacity.
pub fn AllocationPlan::assign(
  self : AllocationPlan,
  item : Int,
  bin : Int,
) -> Bool {
  if item < 0 || item >= self.assignments.length() || bin < 0 {
    return false
  }
  self.assignments[item] = bin
  true
}

///|
/// Remove an assignment.
pub fn AllocationPlan::unassign(self : AllocationPlan, item : Int) -> Bool {
  if item < 0 || item >= self.assignments.length() {
    return false
  }
  self.assignments[item] = -1
  true
}

///|
/// Return copied assignments.
pub fn AllocationPlan::assignments(self : AllocationPlan) -> Array[Int] {
  self.assignments.copy()
}

///|
/// Return items in a bin.
pub fn AllocationPlan::items_in_bin(
  self : AllocationPlan,
  bin : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for item, assigned in self.assignments {
    if assigned == bin {
      result.push(item)
    }
  }
  result
}

///|
/// Return the total weight in a bin.
pub fn allocation_bin_weight(
  instance : AllocationInstance,
  plan : AllocationPlan,
  bin : Int,
) -> Int {
  let mut result = 0
  for item in plan.items_in_bin(bin) {
    result += instance.items[item].weight
  }
  result
}

///|
/// Return the total value in a bin.
pub fn allocation_bin_value(
  instance : AllocationInstance,
  plan : AllocationPlan,
  bin : Int,
) -> Int {
  let mut result = 0
  for item in plan.items_in_bin(bin) {
    result += instance.items[item].value
  }
  result
}

///|
/// Return all bin loads.
pub fn allocation_loads(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Array[Int] {
  let result : Array[Int] = []
  for bin in 0..<instance.capacities.length() {
    result.push(allocation_bin_weight(instance, plan, bin))
  }
  result
}

///|
/// Return all bin values.
pub fn allocation_values(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Array[Int] {
  let result : Array[Int] = []
  for bin in 0..<instance.capacities.length() {
    result.push(allocation_bin_value(instance, plan, bin))
  }
  result
}

///|
/// Return unassigned item ids.
pub fn unassigned_items(plan : AllocationPlan) -> Array[Int] {
  let result : Array[Int] = []
  for item, bin in plan.assignments {
    if bin < 0 {
      result.push(item)
    }
  }
  result
}

///|
/// Return a stable validation error list.
pub fn validate_allocation(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Array[String] {
  let errors : Array[String] = []
  if plan.assignments.length() != instance.items.length() {
    errors.push("item-count-mismatch")
    return errors
  }
  for item, bin in plan.assignments {
    if bin < 0 || bin >= instance.capacities.length() {
      errors.push("item-\{item}-unassigned-or-bin-out-of-range")
    }
  }
  for bin in 0..<instance.capacities.length() {
    if allocation_bin_weight(instance, plan, bin) > instance.capacities[bin] {
      errors.push("capacity-\{bin}")
    }
  }
  for pair in instance.group_limits {
    let bin = pair.0
    let group = pair.1
    let minimum = pair.2
    let maximum = pair.3
    let count = allocation_group_count(instance, plan, bin, group)
    if count < minimum {
      errors.push("group-min-\{bin}-\{group}")
    }
    if count > maximum {
      errors.push("group-max-\{bin}-\{group}")
    }
  }
  errors
}

///|
/// Count items from a group in a bin.
pub fn allocation_group_count(
  instance : AllocationInstance,
  plan : AllocationPlan,
  bin : Int,
  group : Int,
) -> Int {
  let mut result = 0
  for item in plan.items_in_bin(bin) {
    if instance.items[item].group == group {
      result += 1
    }
  }
  result
}

///|
/// Return whether every item is assigned and every rule holds.
pub fn allocation_feasible(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Bool {
  validate_allocation(instance, plan).length() == 0
}

///|
/// Return the first bin with enough residual capacity.
pub fn first_fit_bin(
  instance : AllocationInstance,
  plan : AllocationPlan,
  item : Int,
) -> Int? {
  if item < 0 || item >= instance.items.length() {
    return None
  }
  for bin in 0..<instance.capacities.length() {
    if allocation_bin_weight(instance, plan, bin) + instance.items[item].weight <=
      instance.capacities[bin] {
      return Some(bin)
    }
  }
  None
}

///|
/// Return the tightest bin that can receive an item.
pub fn best_fit_bin(
  instance : AllocationInstance,
  plan : AllocationPlan,
  item : Int,
) -> Int? {
  if item < 0 || item >= instance.items.length() {
    return None
  }
  let mut selected : Int? = None
  let mut best_slack = 2147483647
  for bin in 0..<instance.capacities.length() {
    let slack = instance.capacities[bin] -
      allocation_bin_weight(instance, plan, bin) -
      instance.items[item].weight
    if slack >= 0 && slack < best_slack {
      best_slack = slack
      selected = Some(bin)
    }
  }
  selected
}

///|
/// Allocate items in descending weight order using best fit.
pub fn best_fit_decreasing(instance : AllocationInstance) -> AllocationPlan {
  let plan = allocation_plan(instance)
  let order : Array[Int] = []
  for item in instance.items {
    order.push(item.id)
  }
  for left in 0..<order.length() {
    for right in (left + 1)..<order.length() {
      if instance.items[order[right]].weight >
        instance.items[order[left]].weight {
        let temporary = order[left]
        order[left] = order[right]
        order[right] = temporary
      }
    }
  }
  for item in order {
    match best_fit_bin(instance, plan, item) {
      Some(bin) => ignore(plan.assign(item, bin))
      None => ()
    }
  }
  plan
}

///|
/// Allocate items in descending value-density order.
pub fn value_density_plan(instance : AllocationInstance) -> AllocationPlan {
  let plan = allocation_plan(instance)
  let order : Array[Int] = []
  for item in instance.items {
    order.push(item.id)
  }
  for left in 0..<order.length() {
    for right in (left + 1)..<order.length() {
      let left_item = instance.items[order[left]]
      let right_item = instance.items[order[right]]
      let left_score = if left_item.weight == 0 {
        left_item.value
      } else {
        left_item.value / left_item.weight
      }
      let right_score = if right_item.weight == 0 {
        right_item.value
      } else {
        right_item.value / right_item.weight
      }
      if right_score > left_score {
        let temporary = order[left]
        order[left] = order[right]
        order[right] = temporary
      }
    }
  }
  for item in order {
    match best_fit_bin(instance, plan, item) {
      Some(bin) => ignore(plan.assign(item, bin))
      None => ()
    }
  }
  plan
}

///|
/// Return the least loaded bin that can receive an item.
pub fn least_loaded_bin(
  instance : AllocationInstance,
  plan : AllocationPlan,
  item : Int,
) -> Int? {
  if item < 0 || item >= instance.items.length() {
    return None
  }
  let mut selected : Int? = None
  let mut selected_load = 2147483647
  for bin in 0..<instance.capacities.length() {
    let load = allocation_bin_weight(instance, plan, bin)
    if load + instance.items[item].weight <= instance.capacities[bin] &&
      load < selected_load {
      selected_load = load
      selected = Some(bin)
    }
  }
  selected
}

///|
/// Balance all currently unassigned items onto the least loaded bins.
pub fn balance_unassigned(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  let mut assigned = 0
  for item in unassigned_items(plan) {
    match least_loaded_bin(instance, plan, item) {
      Some(bin) => {
        ignore(plan.assign(item, bin))
        assigned += 1
      }
      None => ()
    }
  }
  assigned
}

///|
/// Move one item from a heavier bin to a lighter feasible bin.
pub fn rebalance_once(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Bool {
  let loads = allocation_loads(instance, plan)
  let mut heavy = 0
  let mut light = 0
  for bin in 1..<loads.length() {
    if loads[bin] > loads[heavy] {
      heavy = bin
    }
    if loads[bin] < loads[light] {
      light = bin
    }
  }
  if heavy == light {
    return false
  }
  for item in plan.items_in_bin(heavy) {
    let weight = instance.items[item].weight
    if loads[heavy] - weight >= loads[light] + weight &&
      loads[light] + weight <= instance.capacities[light] {
      ignore(plan.assign(item, light))
      return true
    }
  }
  false
}

///|
/// Apply local balancing until no improving move remains.
pub fn rebalance(instance : AllocationInstance, plan : AllocationPlan) -> Int {
  let mut moves = 0
  let mut changed = true
  while changed {
    changed = rebalance_once(instance, plan)
    if changed {
      moves += 1
    }
  }
  moves
}

///|
/// Swap two items when it reduces the largest bin load.
pub fn improve_allocation_once(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Bool {
  let before = allocation_spread(instance, plan)
  for first in 0..<instance.items.length() {
    for second in (first + 1)..<instance.items.length() {
      let first_bin = plan.assigned_bin(first)
      let second_bin = plan.assigned_bin(second)
      if first_bin < 0 || second_bin < 0 || first_bin == second_bin {
        continue
      }
      ignore(plan.assign(first, second_bin))
      ignore(plan.assign(second, first_bin))
      if allocation_spread(instance, plan) < before &&
        allocation_feasible(instance, plan) {
        return true
      }
      ignore(plan.assign(first, first_bin))
      ignore(plan.assign(second, second_bin))
    }
  }
  false
}

///|
/// Improve bin balance through pair swaps.
pub fn improve_allocation(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  let mut moves = 0
  let mut changed = true
  while changed {
    changed = improve_allocation_once(instance, plan)
    if changed {
      moves += 1
    }
  }
  moves
}

///|
/// Return max load minus min load.
pub fn allocation_spread(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  let loads = allocation_loads(instance, plan)
  if loads.length() == 0 {
    return 0
  }
  let mut low = loads[0]
  let mut high = loads[0]
  for load in loads {
    if load < low {
      low = load
    }
    if load > high {
      high = load
    }
  }
  high - low
}

///|
/// Return the minimum residual capacity.
pub fn minimum_residual_capacity(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  let mut result = 2147483647
  for bin in 0..<instance.capacities.length() {
    let residual = instance.capacities[bin] -
      allocation_bin_weight(instance, plan, bin)
    if residual < result {
      result = residual
    }
  }
  if result == 2147483647 {
    0
  } else {
    result
  }
}

///|
/// Return total assigned weight.
pub fn total_allocated_weight(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  let mut result = 0
  for item, bin in plan.assignments {
    if bin >= 0 {
      result += instance.items[item].weight
    }
  }
  result
}

///|
/// Return total assigned value.
pub fn total_allocated_value(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  let mut result = 0
  for item, bin in plan.assignments {
    if bin >= 0 {
      result += instance.items[item].value
    }
  }
  result
}

///|
/// Return the fraction of items assigned as integer percentage points.
pub fn allocation_completion(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> Int {
  if instance.items.length() == 0 {
    return 100
  }
  (instance.items.length() - unassigned_items(plan).length()) *
  100 /
  instance.items.length()
}

///|
/// Return a stable one-line plan representation.
pub fn allocation_signature(plan : AllocationPlan) -> Int {
  let mut result = 19
  for item, bin in plan.assignments {
    result = result * 31 + item * 7 + bin
  }
  result
}

///|
/// Render assignments as comma-separated bin ids.
pub fn AllocationPlan::csv(self : AllocationPlan) -> String {
  let builder = StringBuilder()
  for item, bin in self.assignments {
    if item > 0 {
      builder.write_char(',')
    }
    builder.write_string("\{bin}")
  }
  builder.to_string()
}

///|
/// Return items ordered by descending value.
pub fn allocation_items_by_value(instance : AllocationInstance) -> Array[Int] {
  let result : Array[Int] = []
  for item in instance.items {
    result.push(item.id)
  }
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if instance.items[result[right]].value >
        instance.items[result[left]].value {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return the most valuable assigned item in a bin.
pub fn most_valuable_item(
  instance : AllocationInstance,
  plan : AllocationPlan,
  bin : Int,
) -> Int? {
  let items = plan.items_in_bin(bin)
  if items.length() == 0 {
    return None
  }
  let mut result = items[0]
  for item in items {
    if instance.items[item].value > instance.items[result].value {
      result = item
    }
  }
  Some(result)
}

///|
/// Return the heaviest assigned item in a bin.
pub fn heaviest_item(
  instance : AllocationInstance,
  plan : AllocationPlan,
  bin : Int,
) -> Int? {
  let items = plan.items_in_bin(bin)
  if items.length() == 0 {
    return None
  }
  let mut result = items[0]
  for item in items {
    if instance.items[item].weight > instance.items[result].weight {
      result = item
    }
  }
  Some(result)
}

///|
/// Return a stable allocation report.
pub fn allocation_report(
  instance : AllocationInstance,
  plan : AllocationPlan,
) -> String {
  "items=\{instance.items.length()}, completion=\{allocation_completion(instance, plan)}%, weight=\{total_allocated_weight(instance, plan)}, value=\{total_allocated_value(instance, plan)}, spread=\{allocation_spread(instance, plan)}, errors=\{validate_allocation(instance, plan).length()}"
}
