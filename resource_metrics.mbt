///|
/// Resource utilization and bottleneck metrics.
pub struct ResourceMetric {
  resource : Int
  capacity : Int
  total_load : Int
  peak_load : Int
  busy_slots : Int
  horizon : Int
}

///|
/// Build a metric from a profile.
pub fn resource_metric(
  resource : Int,
  capacity : Int,
  profile : Array[Int],
) -> ResourceMetric {
  let mut peak = 0
  let mut busy = 0
  for load in profile {
    if load > peak {
      peak = load
    }
    if load > 0 {
      busy += 1
    }
  }
  {
    resource,
    capacity,
    total_load: integer_sum(profile),
    peak_load: peak,
    busy_slots: busy,
    horizon: profile.length(),
  }
}

///|
/// Return peak utilization percentage.
pub fn ResourceMetric::peak_percent(self : ResourceMetric) -> Int {
  if self.capacity <= 0 {
    0
  } else {
    self.peak_load * 100 / self.capacity
  }
}

///|
/// Return average utilization percentage.
pub fn ResourceMetric::average_percent(self : ResourceMetric) -> Int {
  if self.capacity <= 0 || self.horizon == 0 {
    0
  } else {
    self.total_load * 100 / (self.capacity * self.horizon)
  }
}

///|
/// Return idle slot count.
pub fn ResourceMetric::idle_slots(self : ResourceMetric) -> Int {
  self.horizon - self.busy_slots
}

///|
/// Return whether capacity is exceeded.
pub fn ResourceMetric::overloaded(self : ResourceMetric) -> Bool {
  self.peak_load > self.capacity
}

///|
/// Return a bottleneck score.
pub fn ResourceMetric::bottleneck_score(self : ResourceMetric) -> Int {
  self.peak_percent() * 1000 + self.average_percent()
}

///|
/// Return a stable metric line.
pub fn ResourceMetric::describe(self : ResourceMetric) -> String {
  "resource=\{self.resource}, peak=\{self.peak_load}(\{self.peak_percent()}%), average=\{self.average_percent()}%, busy=\{self.busy_slots}, overloaded=\{self.overloaded()}"
}

///|
/// Build metrics for every resource of a timeline.
pub fn timeline_resource_metrics(
  timeline : ResourceTimeline,
) -> Array[ResourceMetric] {
  let result : Array[ResourceMetric] = []
  for resource in 0..<timeline.capacities.length() {
    result.push(
      resource_metric(
        resource,
        timeline.capacities[resource],
        timeline.profile(resource),
      ),
    )
  }
  result
}

///|
/// Return resource ids sorted by bottleneck score.
pub fn bottleneck_order(metrics : Array[ResourceMetric]) -> Array[Int] {
  let result : Array[Int] = []
  for metric in metrics {
    result.push(metric.resource)
  }
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if metrics[result[right]].bottleneck_score() >
        metrics[result[left]].bottleneck_score() {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return total capacity across metrics.
pub fn total_resource_capacity(metrics : Array[ResourceMetric]) -> Int {
  let mut result = 0
  for metric in metrics {
    result += metric.capacity
  }
  result
}

///|
/// Return total load across metrics.
pub fn total_resource_load(metrics : Array[ResourceMetric]) -> Int {
  let mut result = 0
  for metric in metrics {
    result += metric.total_load
  }
  result
}

///|
/// Return overloaded resource ids.
pub fn overloaded_resources(metrics : Array[ResourceMetric]) -> Array[Int] {
  let result : Array[Int] = []
  for metric in metrics {
    if metric.overloaded() {
      result.push(metric.resource)
    }
  }
  result
}

///|
/// Return the resource with minimum idle time.
pub fn tightest_resource(metrics : Array[ResourceMetric]) -> Int? {
  if metrics.length() == 0 {
    return None
  }
  let mut result = metrics[0]
  for metric in metrics {
    if metric.idle_slots() < result.idle_slots() {
      result = metric
    }
  }
  Some(result.resource)
}

///|
/// Return the resource with maximum idle time.
pub fn loosest_resource(metrics : Array[ResourceMetric]) -> Int? {
  if metrics.length() == 0 {
    return None
  }
  let mut result = metrics[0]
  for metric in metrics {
    if metric.idle_slots() > result.idle_slots() {
      result = metric
    }
  }
  Some(result.resource)
}

///|
/// Return whether all resources stay below a utilization limit.
pub fn within_resource_limit(
  metrics : Array[ResourceMetric],
  limit_percent : Int,
) -> Bool {
  for metric in metrics {
    if metric.peak_percent() > limit_percent {
      return false
    }
  }
  true
}

///|
/// Return a scaled load balance score.
pub fn resource_balance_score(metrics : Array[ResourceMetric]) -> Int {
  if metrics.length() == 0 {
    return 0
  }
  let mut low = metrics[0].average_percent()
  let mut high = low
  for metric in metrics {
    if metric.average_percent() < low {
      low = metric.average_percent()
    }
    if metric.average_percent() > high {
      high = metric.average_percent()
    }
  }
  high - low
}

///|
/// Return a report of metrics.
pub fn resource_metrics_report(metrics : Array[ResourceMetric]) -> String {
  let builder = StringBuilder()
  for index, metric in metrics {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(metric.describe())
  }
  builder.to_string()
}

///|
/// Return a stable metrics fingerprint.
pub fn resource_metrics_signature(metrics : Array[ResourceMetric]) -> Int {
  let mut result = 31
  for metric in metrics {
    result = result * 37 +
      metric.resource * 3 +
      metric.capacity * 5 +
      metric.total_load * 7 +
      metric.peak_load
  }
  result
}

///|
/// Return a capacity recommendation for a target utilization percentage.
pub fn recommended_capacity(
  metric : ResourceMetric,
  target_percent : Int,
) -> Int {
  if target_percent <= 0 {
    return metric.peak_load
  }
  (metric.peak_load * 100 + target_percent - 1) / target_percent
}
