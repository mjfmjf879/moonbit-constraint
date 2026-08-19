///|
/// Service-level metrics for operational plans.
pub struct ServiceObservation {
  id : Int
  promised : Int
  actual : Int
  quantity : Int
  penalty : Int
}

///|
/// Create a service observation.
pub fn service_observation(
  id : Int,
  promised : Int,
  actual : Int,
  quantity : Int,
  penalty : Int,
) -> ServiceObservation {
  {
    id,
    promised,
    actual,
    quantity: if quantity < 0 {
      0
    } else {
      quantity
    },
    penalty: if penalty < 0 {
      0
    } else {
      penalty
    },
  }
}

///|
/// Return lateness.
pub fn ServiceObservation::lateness(self : ServiceObservation) -> Int {
  if self.actual > self.promised {
    self.actual - self.promised
  } else {
    0
  }
}

///|
/// Return earliness.
pub fn ServiceObservation::earliness(self : ServiceObservation) -> Int {
  if self.actual < self.promised {
    self.promised - self.actual
  } else {
    0
  }
}

///|
/// Return on-time status.
pub fn ServiceObservation::on_time(self : ServiceObservation) -> Bool {
  self.actual <= self.promised
}

///|
/// Return weighted lateness penalty.
pub fn ServiceObservation::cost(self : ServiceObservation) -> Int {
  self.lateness() * self.penalty
}

///|
/// Return a stable observation line.
pub fn ServiceObservation::describe(self : ServiceObservation) -> String {
  "\{self.id}: promised=\{self.promised}, actual=\{self.actual}, late=\{self.lateness()}, quantity=\{self.quantity}"
}

///|
/// A service-level aggregate.
pub struct ServiceMetrics {
  orders : Int
  on_time : Int
  late : Int
  total_lateness : Int
  maximum_lateness : Int
  quantity : Int
  cost : Int
}

///|
/// Aggregate observations.
pub fn service_metrics(
  observations : Array[ServiceObservation],
) -> ServiceMetrics {
  let mut on_time = 0
  let mut late = 0
  let mut total_lateness = 0
  let mut maximum_lateness = 0
  let mut quantity = 0
  let mut cost = 0
  for observation in observations {
    if observation.on_time() {
      on_time += 1
    } else {
      late += 1
    }
    total_lateness += observation.lateness()
    if observation.lateness() > maximum_lateness {
      maximum_lateness = observation.lateness()
    }
    quantity += observation.quantity
    cost += observation.cost()
  }
  {
    orders: observations.length(),
    on_time,
    late,
    total_lateness,
    maximum_lateness,
    quantity,
    cost,
  }
}

///|
/// Return on-time percentage.
pub fn ServiceMetrics::on_time_percent(self : ServiceMetrics) -> Int {
  if self.orders == 0 {
    0
  } else {
    self.on_time * 100 / self.orders
  }
}

///|
/// Return late percentage.
pub fn ServiceMetrics::late_percent(self : ServiceMetrics) -> Int {
  if self.orders == 0 {
    0
  } else {
    self.late * 100 / self.orders
  }
}

///|
/// Return average lateness.
pub fn ServiceMetrics::average_lateness(self : ServiceMetrics) -> Int {
  if self.orders == 0 {
    0
  } else {
    self.total_lateness / self.orders
  }
}

///|
/// Return whether a target service level is met.
pub fn ServiceMetrics::meets_target(
  self : ServiceMetrics,
  target_percent : Int,
) -> Bool {
  self.on_time_percent() >= target_percent
}

///|
/// Return a stable metrics line.
pub fn ServiceMetrics::describe(self : ServiceMetrics) -> String {
  "orders=\{self.orders}, on_time=\{self.on_time_percent()}%, average_late=\{self.average_lateness()}, max_late=\{self.maximum_lateness}, quantity=\{self.quantity}, cost=\{self.cost}"
}

///|
/// Return late observations.
pub fn late_observations(
  observations : Array[ServiceObservation],
) -> Array[Int] {
  let result : Array[Int] = []
  for observation in observations {
    if !observation.on_time() {
      result.push(observation.id)
    }
  }
  result
}

///|
/// Return on-time observations.
pub fn on_time_observations(
  observations : Array[ServiceObservation],
) -> Array[Int] {
  let result : Array[Int] = []
  for observation in observations {
    if observation.on_time() {
      result.push(observation.id)
    }
  }
  result
}

///|
/// Return total promised time.
pub fn total_promised(observations : Array[ServiceObservation]) -> Int {
  let mut result = 0
  for observation in observations {
    result += observation.promised
  }
  result
}

///|
/// Return total actual time.
pub fn total_actual(observations : Array[ServiceObservation]) -> Int {
  let mut result = 0
  for observation in observations {
    result += observation.actual
  }
  result
}

///|
/// Return weighted service score.
pub fn service_score(
  observations : Array[ServiceObservation],
  lateness_weight : Int,
  quantity_weight : Int,
) -> Int {
  let metrics = service_metrics(observations)
  metrics.on_time * quantity_weight -
  metrics.total_lateness * lateness_weight +
  metrics.quantity
}

///|
/// Return a service-level gap.
pub fn service_gap(metrics : ServiceMetrics, target_percent : Int) -> Int {
  target_percent - metrics.on_time_percent()
}

///|
/// Return whether all observations are ordered by id.
pub fn service_ids_ordered(observations : Array[ServiceObservation]) -> Bool {
  for index in 1..<observations.length() {
    if observations[index].id <= observations[index - 1].id {
      return false
    }
  }
  true
}

///|
/// Return whether ids are dense.
pub fn service_ids_dense(observations : Array[ServiceObservation]) -> Bool {
  for index, observation in observations {
    if observation.id != index {
      return false
    }
  }
  true
}

///|
/// Return the largest quantity observation.
pub fn largest_service_order(observations : Array[ServiceObservation]) -> Int? {
  if observations.length() == 0 {
    return None
  }
  let mut result = observations[0]
  for observation in observations {
    if observation.quantity > result.quantity {
      result = observation
    }
  }
  Some(result.id)
}

///|
/// Return the most late observation.
pub fn latest_service_order(observations : Array[ServiceObservation]) -> Int? {
  if observations.length() == 0 {
    return None
  }
  let mut result = observations[0]
  for observation in observations {
    if observation.lateness() > result.lateness() {
      result = observation
    }
  }
  Some(result.id)
}

///|
/// Return a sorted lateness vector.
pub fn service_lateness_values(
  observations : Array[ServiceObservation],
) -> Array[Int] {
  let result : Array[Int] = []
  for observation in observations {
    result.push(observation.lateness())
  }
  sort_integers(result)
  result
}

///|
/// Return the lateness percentile.
pub fn service_lateness_percentile(
  observations : Array[ServiceObservation],
  percent : Int,
) -> Int? {
  integer_percentile(service_lateness_values(observations), percent)
}

///|
/// Return a stable aggregate signature.
pub fn service_metrics_signature(
  observations : Array[ServiceObservation],
) -> Int {
  let mut result = 31
  for observation in observations {
    result = result * 37 +
      observation.id * 3 +
      observation.promised * 5 +
      observation.actual * 7 +
      observation.quantity
  }
  result
}

///|
/// Create observations from promised and actual sequences.
pub fn observations_from_times(
  promised : Array[Int],
  actual : Array[Int],
  penalty : Int,
) -> Array[ServiceObservation] {
  let result : Array[ServiceObservation] = []
  let limit = if promised.length() < actual.length() {
    promised.length()
  } else {
    actual.length()
  }
  for index in 0..<limit {
    result.push(
      service_observation(index, promised[index], actual[index], 1, penalty),
    )
  }
  result
}

///|
/// Return a report comparing two observation sets.
pub fn compare_service_sets(
  baseline : Array[ServiceObservation],
  candidate : Array[ServiceObservation],
) -> String {
  let left = service_metrics(baseline)
  let right = service_metrics(candidate)
  "on_time_delta=\{right.on_time_percent() - left.on_time_percent()}, lateness_delta=\{right.total_lateness - left.total_lateness}, cost_delta=\{right.cost - left.cost}"
}
