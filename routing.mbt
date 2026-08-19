///|
/// A finite-domain friendly vehicle-routing toolkit.
///
/// The routing layer deliberately keeps the data representation compact and
/// deterministic. It is useful before a full solver model is posted: a
/// planner can validate input, construct a feasible seed plan, measure it,
/// and then use the resulting route as a warm start for a richer model.
pub struct RoutingPoint {
  id : Int
  x : Int
  y : Int
  demand : Int
  service : Int
  ready : Int
  due : Int
}

///|
/// Create a customer or depot point with a wide time window.
pub fn routing_point(id : Int, x : Int, y : Int, demand : Int) -> RoutingPoint {
  { id, x, y, demand, service: 0, ready: 0, due: 2147483647 }
}

///|
/// Return a copy with a service duration.
pub fn RoutingPoint::with_service(
  self : RoutingPoint,
  service : Int,
) -> RoutingPoint {
  { ..self, service: if service < 0 { 0 } else { service } }
}

///|
/// Return a copy with a time window.
pub fn RoutingPoint::with_window(
  self : RoutingPoint,
  ready : Int,
  due : Int,
) -> RoutingPoint {
  { ..self, ready, due }
}

///|
/// Read the stable customer identifier.
pub fn RoutingPoint::id(self : RoutingPoint) -> Int {
  self.id
}

///|
/// Read the horizontal coordinate.
pub fn RoutingPoint::x(self : RoutingPoint) -> Int {
  self.x
}

///|
/// Read the vertical coordinate.
pub fn RoutingPoint::y(self : RoutingPoint) -> Int {
  self.y
}

///|
/// Read the demand.
pub fn RoutingPoint::demand(self : RoutingPoint) -> Int {
  self.demand
}

///|
/// Read the service duration.
pub fn RoutingPoint::service(self : RoutingPoint) -> Int {
  self.service
}

///|
/// Return whether a point has a valid time window.
pub fn RoutingPoint::valid_window(self : RoutingPoint) -> Bool {
  self.ready <= self.due
}

///|
/// A validated routing instance with an integer distance matrix.
pub struct RoutingInstance {
  points : Array[RoutingPoint]
  depot : Int
  vehicles : Int
  capacities : Array[Int]
  distances : Array[Array[Int]]
}

///|
/// Build a routing instance from customer points and vehicle capacities.
pub fn routing_instance(
  points : Array[RoutingPoint],
  depot : Int,
  capacities : Array[Int],
) -> RoutingInstance? {
  if points.length() < 2 || depot < 0 || depot >= points.length() {
    return None
  }
  if capacities.length() < 1 {
    return None
  }
  for point in points {
    if point.demand < 0 || !point.valid_window() {
      return None
    }
  }
  for capacity in capacities {
    if capacity < 0 {
      return None
    }
  }
  let distances : Array[Array[Int]] = []
  for left in points {
    let row : Array[Int] = []
    for right in points {
      row.push(abs_int(left.x - right.x) + abs_int(left.y - right.y))
    }
    distances.push(row)
  }
  Some({
    points: points.copy(),
    depot,
    vehicles: capacities.length(),
    capacities: capacities.copy(),
    distances,
  })
}

///|
/// Build a square instance with an explicit distance matrix.
pub fn routing_instance_with_distances(
  points : Array[RoutingPoint],
  depot : Int,
  capacities : Array[Int],
  distances : Array[Array[Int]],
) -> RoutingInstance? {
  if points.length() < 2 ||
    depot < 0 ||
    depot >= points.length() ||
    capacities.length() < 1 {
    return None
  }
  if distances.length() != points.length() {
    return None
  }
  for row in distances {
    if row.length() != points.length() {
      return None
    }
    for value in row {
      if value < 0 {
        return None
      }
    }
  }
  for point in points {
    if point.demand < 0 || !point.valid_window() {
      return None
    }
  }
  for capacity in capacities {
    if capacity < 0 {
      return None
    }
  }
  Some({
    points: points.copy(),
    depot,
    vehicles: capacities.length(),
    capacities: capacities.copy(),
    distances: distances.map(row => row.copy()),
  })
}

///|
/// Number of locations including the depot.
pub fn RoutingInstance::location_count(self : RoutingInstance) -> Int {
  self.points.length()
}

///|
/// Number of vehicles.
pub fn RoutingInstance::vehicle_count(self : RoutingInstance) -> Int {
  self.vehicles
}

///|
/// Return the depot location identifier.
pub fn RoutingInstance::depot(self : RoutingInstance) -> Int {
  self.depot
}

///|
/// Read one point.
pub fn RoutingInstance::point(self : RoutingInstance, id : Int) -> RoutingPoint {
  if id < 0 || id >= self.points.length() {
    abort("routing point is outside the instance")
  }
  self.points[id]
}

///|
/// Read one vehicle capacity.
pub fn RoutingInstance::capacity(self : RoutingInstance, vehicle : Int) -> Int {
  if vehicle < 0 || vehicle >= self.capacities.length() {
    abort("routing vehicle is outside the instance")
  }
  self.capacities[vehicle]
}

///|
/// Return the directed distance between two locations.
pub fn RoutingInstance::distance(
  self : RoutingInstance,
  from : Int,
  to : Int,
) -> Int {
  if from < 0 ||
    from >= self.points.length() ||
    to < 0 ||
    to >= self.points.length() {
    abort("routing distance endpoint is outside the instance")
  }
  self.distances[from][to]
}

///|
/// Return all customer identifiers, excluding the depot.
pub fn RoutingInstance::customers(self : RoutingInstance) -> Array[Int] {
  let result : Array[Int] = []
  for id in 0..<self.points.length() {
    if id != self.depot {
      result.push(id)
    }
  }
  result
}

///|
/// Return the total demand of all customers.
pub fn RoutingInstance::total_demand(self : RoutingInstance) -> Int {
  let mut result = 0
  for point in self.points {
    if point.id != self.points[self.depot].id {
      result += point.demand
    }
  }
  result
}

///|
/// A route is represented without an implicit depot in its stop list.
pub struct VehicleRoute {
  vehicle : Int
  stops : Array[Int]
}

///|
/// Create an empty route for a vehicle.
pub fn vehicle_route(vehicle : Int) -> VehicleRoute {
  { vehicle, stops: [] }
}

///|
/// Create a route from a stop sequence.
pub fn vehicle_route_from(vehicle : Int, stops : Array[Int]) -> VehicleRoute {
  { vehicle, stops: stops.copy() }
}

///|
/// Read the vehicle index.
pub fn VehicleRoute::vehicle(self : VehicleRoute) -> Int {
  self.vehicle
}

///|
/// Read a copied stop sequence.
pub fn VehicleRoute::stops(self : VehicleRoute) -> Array[Int] {
  self.stops.copy()
}

///|
/// Number of customer visits.
pub fn VehicleRoute::length(self : VehicleRoute) -> Int {
  self.stops.length()
}

///|
/// Append a customer when it has not already been used in this route.
pub fn VehicleRoute::push_unique(self : VehicleRoute, stop : Int) -> Bool {
  if self.stops.contains(stop) {
    return false
  }
  self.stops.push(stop)
  true
}

///|
/// Insert a customer at a bounded position.
pub fn VehicleRoute::insert(
  self : VehicleRoute,
  position : Int,
  stop : Int,
) -> Bool {
  if position < 0 || position > self.stops.length() || self.stops.contains(stop) {
    return false
  }
  self.stops.push(0)
  let mut index = self.stops.length() - 1
  while index > position {
    self.stops[index] = self.stops[index - 1]
    index -= 1
  }
  self.stops[position] = stop
  true
}

///|
/// Remove a stop and return whether it was found.
pub fn VehicleRoute::remove(self : VehicleRoute, stop : Int) -> Bool {
  let mut index = 0
  while index < self.stops.length() {
    if self.stops[index] == stop {
      while index + 1 < self.stops.length() {
        self.stops[index] = self.stops[index + 1]
        index += 1
      }
      ignore(self.stops.pop())
      return true
    }
    index += 1
  }
  false
}

///|
/// Reverse a bounded inclusive segment for 2-opt neighborhoods.
pub fn VehicleRoute::reverse_segment(
  self : VehicleRoute,
  left : Int,
  right : Int,
) -> Bool {
  if left < 0 || right >= self.stops.length() || left >= right {
    return false
  }
  let mut low = left
  let mut high = right
  while low < high {
    let temporary = self.stops[low]
    self.stops[low] = self.stops[high]
    self.stops[high] = temporary
    low += 1
    high -= 1
  }
  true
}

///|
/// A complete multi-vehicle plan.
pub struct RoutingPlan {
  routes : Array[VehicleRoute]
}

///|
/// Create an empty plan with one route per vehicle.
pub fn routing_plan(vehicle_count : Int) -> RoutingPlan {
  let routes : Array[VehicleRoute] = []
  for vehicle in 0..<vehicle_count {
    routes.push(vehicle_route(vehicle))
  }
  { routes, }
}

///|
/// Read the number of routes.
pub fn RoutingPlan::route_count(self : RoutingPlan) -> Int {
  self.routes.length()
}

///|
/// Read a route.
pub fn RoutingPlan::route(self : RoutingPlan, vehicle : Int) -> VehicleRoute {
  if vehicle < 0 || vehicle >= self.routes.length() {
    abort("routing plan vehicle is outside the plan")
  }
  self.routes[vehicle]
}

///|
/// Return copied routes.
pub fn RoutingPlan::routes(self : RoutingPlan) -> Array[VehicleRoute] {
  self.routes.map(route => vehicle_route_from(route.vehicle, route.stops))
}

///|
/// Append a stop to a vehicle route.
pub fn RoutingPlan::append(
  self : RoutingPlan,
  vehicle : Int,
  stop : Int,
) -> Bool {
  if vehicle < 0 || vehicle >= self.routes.length() {
    return false
  }
  self.routes[vehicle].push_unique(stop)
}

///|
/// Locate a customer in the plan, returning vehicle and position.
pub fn RoutingPlan::locate(self : RoutingPlan, stop : Int) -> (Int, Int)? {
  for vehicle, route in self.routes {
    for position, candidate in route.stops {
      if candidate == stop {
        return Some((vehicle, position))
      }
    }
  }
  None
}

///|
/// Return all visits in vehicle order.
pub fn RoutingPlan::visited(self : RoutingPlan) -> Array[Int] {
  let result : Array[Int] = []
  for route in self.routes {
    for stop in route.stops {
      result.push(stop)
    }
  }
  result
}

///|
/// Return a stable route string useful for logs and benchmark snapshots.
pub fn RoutingPlan::describe(self : RoutingPlan) -> String {
  let builder = StringBuilder()
  for vehicle, route in self.routes {
    if vehicle > 0 {
      builder.write_char('\n')
    }
    builder.write_string("vehicle \{vehicle}: depot")
    for stop in route.stops {
      builder.write_string(" -> \{stop}")
    }
    builder.write_string(" -> depot")
  }
  builder.to_string()
}

///|
/// Route distance including the depot departure and return.
pub fn route_distance(instance : RoutingInstance, route : VehicleRoute) -> Int {
  let mut result = 0
  let mut previous = instance.depot
  for stop in route.stops {
    result += instance.distance(previous, stop)
    previous = stop
  }
  result + instance.distance(previous, instance.depot)
}

///|
/// Sum customer demand on a route.
pub fn route_load(instance : RoutingInstance, route : VehicleRoute) -> Int {
  let mut result = 0
  for stop in route.stops {
    if stop >= 0 && stop < instance.points.length() {
      result += instance.points[stop].demand
    }
  }
  result
}

///|
/// Return the route's service time excluding travel.
pub fn route_service(instance : RoutingInstance, route : VehicleRoute) -> Int {
  let mut result = 0
  for stop in route.stops {
    if stop >= 0 && stop < instance.points.length() {
      result += instance.points[stop].service
    }
  }
  result
}

///|
/// Arrival and departure times for a route under its time windows.
pub fn route_arrivals(
  instance : RoutingInstance,
  route : VehicleRoute,
) -> Array[Int] {
  let result : Array[Int] = []
  let mut clock = 0
  let mut previous = instance.depot
  for stop in route.stops {
    clock += instance.distance(previous, stop)
    let point = instance.points[stop]
    if clock < point.ready {
      clock = point.ready
    }
    result.push(clock)
    clock += point.service
    previous = stop
  }
  result
}

///|
/// Validate a single route and return a stable error code.
pub fn validate_route(
  instance : RoutingInstance,
  route : VehicleRoute,
) -> String? {
  if route.vehicle < 0 || route.vehicle >= instance.vehicles {
    return Some("vehicle-out-of-range")
  }
  for stop in route.stops {
    if stop < 0 || stop >= instance.points.length() || stop == instance.depot {
      return Some("stop-out-of-range-or-depot")
    }
  }
  for left, stop in route.stops {
    for right in 0..<left {
      if route.stops[right] == stop {
        return Some("duplicate-stop")
      }
    }
  }
  if route_load(instance, route) > instance.capacity(route.vehicle) {
    return Some("capacity-exceeded")
  }
  let arrivals = route_arrivals(instance, route)
  for index, stop in route.stops {
    if arrivals[index] > instance.points[stop].due {
      return Some("time-window-exceeded")
    }
  }
  None
}

///|
/// Validate that every customer appears exactly once.
pub fn validate_plan(
  instance : RoutingInstance,
  plan : RoutingPlan,
) -> Array[String] {
  let errors : Array[String] = []
  if plan.routes.length() != instance.vehicles {
    errors.push("vehicle-count-mismatch")
  }
  let seen : Array[Int] = []
  for route in plan.routes {
    match validate_route(instance, route) {
      Some(error) => errors.push("vehicle_\{route.vehicle}:\{error}")
      None => ()
    }
    for stop in route.stops {
      if seen.contains(stop) {
        errors.push("duplicate-stop-global")
      } else {
        seen.push(stop)
      }
    }
  }
  for customer in instance.customers() {
    if !seen.contains(customer) {
      errors.push("missing-stop-\{customer}")
    }
  }
  errors
}

///|
/// Return a plan's total travel distance.
pub fn plan_distance(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut result = 0
  for route in plan.routes {
    result += route_distance(instance, route)
  }
  result
}

///|
/// Return a plan's largest route distance.
pub fn plan_makespan(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut result = 0
  for route in plan.routes {
    let distance = route_distance(instance, route) +
      route_service(instance, route)
    if distance > result {
      result = distance
    }
  }
  result
}

///|
/// Return a plan's total load.
pub fn plan_load(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut result = 0
  for route in plan.routes {
    result += route_load(instance, route)
  }
  result
}

///|
/// Return the number of customers served by a plan.
pub fn plan_visit_count(plan : RoutingPlan) -> Int {
  plan.visited().length()
}

///|
/// Pick the nearest feasible unserved customer.
fn nearest_feasible(
  instance : RoutingInstance,
  current : Int,
  vehicle : Int,
  route : VehicleRoute,
  remaining : Array[Int],
) -> Int? {
  let mut selected : Int? = None
  let mut selected_distance = 2147483647
  let current_load = route_load(instance, route)
  for candidate in remaining {
    let point = instance.points[candidate]
    if current_load + point.demand <= instance.capacity(vehicle) {
      let distance = instance.distance(current, candidate)
      let better_tie = match selected {
        Some(value) => candidate < value
        None => true
      }
      if distance < selected_distance ||
        (distance == selected_distance && better_tie) {
        selected = Some(candidate)
        selected_distance = distance
      }
    }
  }
  selected
}

///|
/// Remove the first matching integer from an array.
fn remove_first_value(values : Array[Int], target : Int) -> Bool {
  let mut index = 0
  while index < values.length() {
    if values[index] == target {
      while index + 1 < values.length() {
        values[index] = values[index + 1]
        index += 1
      }
      ignore(values.pop())
      return true
    }
    index += 1
  }
  false
}

///|
/// Construct a deterministic nearest-neighbor seed plan.
pub fn nearest_neighbor_plan(instance : RoutingInstance) -> RoutingPlan {
  let plan = routing_plan(instance.vehicles)
  let remaining = instance.customers()
  for vehicle in 0..<instance.vehicles {
    let mut current = instance.depot
    let mut searching = true
    while searching {
      match
        nearest_feasible(
          instance,
          current,
          vehicle,
          plan.routes[vehicle],
          remaining,
        ) {
        Some(stop) => {
          ignore(remove_first_value(remaining, stop))
          ignore(plan.append(vehicle, stop))
          current = stop
        }
        None => searching = false
      }
    }
  }
  plan
}

///|
/// Move one customer from an overloaded route to the best insertion point.
pub fn repair_capacity(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut moved = 0
  for source in 0..<plan.routes.length() {
    while route_load(instance, plan.routes[source]) > instance.capacity(source) {
      if plan.routes[source].stops.length() == 0 {
        break
      }
      let stop = plan.routes[source].stops[plan.routes[source].stops.length() -
        1]
      let mut target : Int? = None
      for vehicle in 0..<plan.routes.length() {
        if vehicle != source &&
          route_load(instance, plan.routes[vehicle]) +
          instance.points[stop].demand <=
          instance.capacity(vehicle) {
          target = Some(vehicle)
          break
        }
      }
      match target {
        Some(vehicle) => {
          ignore(plan.routes[source].stops.pop())
          ignore(plan.append(vehicle, stop))
          moved += 1
        }
        None => break
      }
    }
  }
  moved
}

///|
/// Apply the first improving 2-opt reversal found across all routes.
pub fn improve_two_opt(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut improvements = 0
  let mut changed = true
  while changed {
    changed = false
    for route in plan.routes {
      if route.stops.length() < 3 {
        continue
      }
      let current_distance = route_distance(instance, route)
      for left in 0..<route.stops.length() {
        for right in (left + 1)..<route.stops.length() {
          let first = if left == 0 {
            instance.depot
          } else {
            route.stops[left - 1]
          }
          let second = route.stops[left]
          let third = route.stops[right]
          let fourth = if right + 1 >= route.stops.length() {
            instance.depot
          } else {
            route.stops[right + 1]
          }
          let old_edges = instance.distance(first, second) +
            instance.distance(third, fourth)
          let new_edges = instance.distance(first, third) +
            instance.distance(second, fourth)
          if new_edges < old_edges && new_edges < current_distance {
            ignore(route.reverse_segment(left, right))
            improvements += 1
            changed = true
            break
          }
        }
        if changed {
          break
        }
      }
      if changed {
        break
      }
    }
  }
  improvements
}

///|
/// Return a plan with customers ordered by descending demand.
pub fn demand_first_plan(instance : RoutingInstance) -> RoutingPlan {
  let plan = routing_plan(instance.vehicles)
  let remaining = instance.customers()
  for left in 0..<remaining.length() {
    for right in (left + 1)..<remaining.length() {
      if instance.points[remaining[right]].demand >
        instance.points[remaining[left]].demand {
        let temporary = remaining[left]
        remaining[left] = remaining[right]
        remaining[right] = temporary
      }
    }
  }
  for stop in remaining {
    let mut chosen : Int? = None
    let mut best_slack = 2147483647
    for vehicle in 0..<instance.vehicles {
      let slack = instance.capacity(vehicle) -
        route_load(instance, plan.routes[vehicle])
      if slack >= instance.points[stop].demand && slack < best_slack {
        chosen = Some(vehicle)
        best_slack = slack
      }
    }
    match chosen {
      Some(vehicle) => ignore(plan.append(vehicle, stop))
      None => ()
    }
  }
  plan
}

///|
/// A scalar score useful for comparing heuristic plans.
pub fn routing_score(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let errors = validate_plan(instance, plan)
  plan_distance(instance, plan) +
  errors.length() * 1000000 +
  plan_makespan(instance, plan)
}

///|
/// Compact quality report for a routing plan.
pub struct RoutingReport {
  distance : Int
  makespan : Int
  load : Int
  visits : Int
  errors : Array[String]
}

///|
/// Produce a report without mutating the plan.
pub fn routing_report(
  instance : RoutingInstance,
  plan : RoutingPlan,
) -> RoutingReport {
  {
    distance: plan_distance(instance, plan),
    makespan: plan_makespan(instance, plan),
    load: plan_load(instance, plan),
    visits: plan_visit_count(plan),
    errors: validate_plan(instance, plan),
  }
}

///|
/// Return whether a report is feasible.
pub fn RoutingReport::feasible(self : RoutingReport) -> Bool {
  self.errors.length() == 0
}

///|
/// Read the travel distance.
pub fn RoutingReport::distance(self : RoutingReport) -> Int {
  self.distance
}

///|
/// Read the route makespan.
pub fn RoutingReport::makespan(self : RoutingReport) -> Int {
  self.makespan
}

///|
/// Read the served load.
pub fn RoutingReport::load(self : RoutingReport) -> Int {
  self.load
}

///|
/// Read the visit count.
pub fn RoutingReport::visits(self : RoutingReport) -> Int {
  self.visits
}

///|
/// Return a stable summary string.
pub fn RoutingReport::describe(self : RoutingReport) -> String {
  "distance=\{self.distance}, makespan=\{self.makespan}, load=\{self.load}, visits=\{self.visits}, errors=\{self.errors.length()}"
}

///|
/// Return the absolute value of an integer.
fn abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
/// Return an integer route signature for caching and regression tests.
pub fn routing_signature(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut signature = 17
  for route in plan.routes {
    signature = signature * 31 + route.vehicle
    for stop in route.stops {
      signature = signature * 31 +
        stop +
        instance.distance(instance.depot, stop)
    }
  }
  signature
}

///|
/// Return a route's cumulative arrival slack values.
pub fn route_slacks(
  instance : RoutingInstance,
  route : VehicleRoute,
) -> Array[Int] {
  let arrivals = route_arrivals(instance, route)
  let result : Array[Int] = []
  for index, stop in route.stops {
    result.push(instance.points[stop].due - arrivals[index])
  }
  result
}

///|
/// Return the first route position violating a time window.
pub fn first_late_stop(
  instance : RoutingInstance,
  route : VehicleRoute,
) -> Int? {
  let arrivals = route_arrivals(instance, route)
  for index, stop in route.stops {
    if arrivals[index] > instance.points[stop].due {
      return Some(stop)
    }
  }
  None
}

///|
/// Return the largest capacity residual among routes.
pub fn capacity_slack(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut result = 0
  for route in plan.routes {
    let slack = instance.capacity(route.vehicle) - route_load(instance, route)
    if slack > result {
      result = slack
    }
  }
  result
}

///|
/// Return the smallest non-negative capacity residual, or -1 when infeasible.
pub fn minimum_capacity_slack(
  instance : RoutingInstance,
  plan : RoutingPlan,
) -> Int {
  let mut result = 2147483647
  for route in plan.routes {
    let slack = instance.capacity(route.vehicle) - route_load(instance, route)
    if slack < 0 {
      return slack
    }
    if slack < result {
      result = slack
    }
  }
  if result == 2147483647 {
    0
  } else {
    result
  }
}

///|
/// Create a linearly spaced point set for deterministic examples.
pub fn grid_routing_points(width : Int, height : Int) -> Array[RoutingPoint] {
  let result : Array[RoutingPoint] = []
  if width <= 0 || height <= 0 {
    return result
  }
  let mut id = 0
  for y in 0..<height {
    for x in 0..<width {
      result.push(routing_point(id, x, y, if id == 0 { 0 } else { 1 }))
      id += 1
    }
  }
  result
}

///|
/// Return a plan's visit sequence grouped by vehicle.
pub fn routing_matrix(plan : RoutingPlan) -> Array[Array[Int]] {
  plan.routes.map(route => route.stops.copy())
}

///|
/// Return whether a route uses every stop in strictly increasing order.
pub fn is_monotone_route(route : VehicleRoute) -> Bool {
  for index in 1..<route.stops.length() {
    if route.stops[index] <= route.stops[index - 1] {
      return false
    }
  }
  true
}

///|
/// Return the number of route crossings in a coordinate instance.
pub fn route_crossings(instance : RoutingInstance, route : VehicleRoute) -> Int {
  let mut result = 0
  for left in 0..<route.stops.length() {
    for right in (left + 1)..<route.stops.length() {
      let a = if left == 0 { instance.depot } else { route.stops[left - 1] }
      let b = route.stops[left]
      let c = route.stops[right]
      let d = if right + 1 >= route.stops.length() {
        instance.depot
      } else {
        route.stops[right + 1]
      }
      let first = instance.distance(a, b) + instance.distance(c, d)
      let second = instance.distance(a, c) + instance.distance(b, d)
      if second < first {
        result += 1
      }
    }
  }
  result
}

///|
/// Return a route-level objective combining distance, lateness, and crossings.
pub fn route_objective(instance : RoutingInstance, route : VehicleRoute) -> Int {
  let mut lateness = 0
  let arrivals = route_arrivals(instance, route)
  for index, stop in route.stops {
    let late = arrivals[index] - instance.points[stop].due
    if late > 0 {
      lateness += late
    }
  }
  route_distance(instance, route) +
  route_service(instance, route) +
  lateness * 1000 +
  route_crossings(instance, route) * 10
}

///|
/// Return a plan-level objective with deterministic penalties.
pub fn plan_objective(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut result = 0
  for route in plan.routes {
    result += route_objective(instance, route)
  }
  result + validate_plan(instance, plan).length() * 1000000
}

///|
/// Return a compact CSV row for a route.
pub fn route_csv(route : VehicleRoute) -> String {
  let builder = StringBuilder()
  builder.write_string("\{route.vehicle}")
  for stop in route.stops {
    builder.write_string(",\{stop}")
  }
  builder.to_string()
}

///|
/// Render all routes as CSV rows.
pub fn plan_csv(plan : RoutingPlan) -> String {
  let builder = StringBuilder()
  for index, route in plan.routes {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(route_csv(route))
  }
  builder.to_string()
}

///|
/// Return a plan created by assigning each customer round-robin.
pub fn round_robin_plan(instance : RoutingInstance) -> RoutingPlan {
  let plan = routing_plan(instance.vehicles)
  let mut vehicle = 0
  for stop in instance.customers() {
    ignore(plan.append(vehicle, stop))
    vehicle = (vehicle + 1) % instance.vehicles
  }
  plan
}

///|
/// Return the most distant customer from the depot.
pub fn farthest_customer(instance : RoutingInstance) -> Int? {
  let mut result : Int? = None
  let mut distance = -1
  for customer in instance.customers() {
    let current = instance.distance(instance.depot, customer)
    if current > distance {
      result = Some(customer)
      distance = current
    }
  }
  result
}

///|
/// Return customers sorted by distance from the depot.
pub fn customers_by_depot_distance(instance : RoutingInstance) -> Array[Int] {
  let result = instance.customers()
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      let first = instance.distance(instance.depot, result[left])
      let second = instance.distance(instance.depot, result[right])
      if second < first {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return the number of unserved customers.
pub fn unserved_count(instance : RoutingInstance, plan : RoutingPlan) -> Int {
  let mut result = 0
  for customer in instance.customers() {
    if plan.locate(customer) is None {
      result += 1
    }
  }
  result
}

///|
/// Return whether every route has a distinct vehicle identifier.
pub fn distinct_route_vehicles(plan : RoutingPlan) -> Bool {
  for left, route in plan.routes {
    for right in 0..<left {
      if plan.routes[right].vehicle == route.vehicle {
        return false
      }
    }
  }
  true
}

///|
/// Return the average route distance using integer division.
pub fn average_route_distance(
  instance : RoutingInstance,
  plan : RoutingPlan,
) -> Int {
  if plan.routes.length() == 0 {
    return 0
  }
  plan_distance(instance, plan) / plan.routes.length()
}

///|
/// Return the average customer demand using integer division.
pub fn average_customer_demand(instance : RoutingInstance) -> Int {
  let customers = instance.customers()
  if customers.length() == 0 {
    return 0
  }
  instance.total_demand() / customers.length()
}

///|
/// Return whether every point identifier matches its array position.
pub fn routing_ids_are_dense(instance : RoutingInstance) -> Bool {
  for index, point in instance.points {
    if point.id != index {
      return false
    }
  }
  true
}
