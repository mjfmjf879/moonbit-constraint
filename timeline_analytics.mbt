///|
/// Interval analytics for calendars, reservations, and resource timelines.
///
/// Timeline records are half-open intervals `[start, end)`. Keeping this
/// convention explicit makes boundary-touching reservations composable and
/// lets capacity checks share the same logic as scheduling constraints.
pub struct TimelineInterval {
  id : Int
  resource : Int
  start : Int
  end : Int
  weight : Int
  label : String
}

///|
/// Create an interval.
pub fn timeline_interval(
  id : Int,
  resource : Int,
  start : Int,
  end : Int,
  weight : Int,
  label : String,
) -> TimelineInterval {
  {
    id,
    resource,
    start,
    end,
    weight: if weight < 0 {
      0
    } else {
      weight
    },
    label,
  }
}

///|
/// Return interval duration.
pub fn TimelineInterval::duration(self : TimelineInterval) -> Int {
  if self.end > self.start {
    self.end - self.start
  } else {
    0
  }
}

///|
/// Return whether an interval is valid.
pub fn TimelineInterval::valid(self : TimelineInterval) -> Bool {
  self.resource >= 0 && self.start <= self.end && self.weight >= 0
}

///|
/// Return whether a time point is covered.
pub fn TimelineInterval::contains(self : TimelineInterval, time : Int) -> Bool {
  time >= self.start && time < self.end
}

///|
/// A collection of resource intervals.
pub struct ResourceTimeline {
  horizon : Int
  capacities : Array[Int]
  intervals : Array[TimelineInterval]
}

///|
/// Create an empty timeline.
pub fn resource_timeline(
  horizon : Int,
  capacities : Array[Int],
) -> ResourceTimeline? {
  if horizon < 0 || capacities.length() == 0 {
    return None
  }
  for capacity in capacities {
    if capacity < 0 {
      return None
    }
  }
  Some({ horizon, capacities: capacities.copy(), intervals: [] })
}

///|
/// Add an interval after bounds validation.
pub fn ResourceTimeline::add(
  self : ResourceTimeline,
  interval : TimelineInterval,
) -> Bool {
  if !interval.valid() ||
    interval.resource >= self.capacities.length() ||
    interval.start < 0 ||
    interval.end > self.horizon ||
    self.contains_id(interval.id) {
    return false
  }
  self.intervals.push(interval)
  true
}

///|
/// Return whether an id exists.
pub fn ResourceTimeline::contains_id(self : ResourceTimeline, id : Int) -> Bool {
  for interval in self.intervals {
    if interval.id == id {
      return true
    }
  }
  false
}

///|
/// Return interval count.
pub fn ResourceTimeline::length(self : ResourceTimeline) -> Int {
  self.intervals.length()
}

///|
/// Return intervals on one resource.
pub fn ResourceTimeline::on_resource(
  self : ResourceTimeline,
  resource : Int,
) -> Array[TimelineInterval] {
  let result : Array[TimelineInterval] = []
  for interval in self.intervals {
    if interval.resource == resource {
      result.push(interval)
    }
  }
  result
}

///|
/// Return the load at one resource and time.
pub fn ResourceTimeline::load_at(
  self : ResourceTimeline,
  resource : Int,
  time : Int,
) -> Int {
  let mut result = 0
  for interval in self.intervals {
    if interval.resource == resource && interval.contains(time) {
      result += interval.weight
    }
  }
  result
}

///|
/// Return a resource load profile.
pub fn ResourceTimeline::profile(
  self : ResourceTimeline,
  resource : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for time in 0..<self.horizon {
    result.push(self.load_at(resource, time))
  }
  result
}

///|
/// Return all overload time points on a resource.
pub fn ResourceTimeline::overloads(
  self : ResourceTimeline,
  resource : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  if resource < 0 || resource >= self.capacities.length() {
    return result
  }
  for time, load in self.profile(resource) {
    if load > self.capacities[resource] {
      result.push(time)
    }
  }
  result
}

///|
/// Return whether all capacity rules hold.
pub fn ResourceTimeline::feasible(self : ResourceTimeline) -> Bool {
  for resource in 0..<self.capacities.length() {
    if self.overloads(resource).length() > 0 {
      return false
    }
  }
  true
}

///|
/// Return interval overlap.
pub fn timeline_overlap(
  left : TimelineInterval,
  right : TimelineInterval,
) -> Bool {
  left.resource == right.resource &&
  left.start < right.end &&
  right.start < left.end
}

///|
/// Return all conflicting interval id pairs.
pub fn ResourceTimeline::conflicts(
  self : ResourceTimeline,
) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  for left in 0..<self.intervals.length() {
    for right in (left + 1)..<self.intervals.length() {
      if timeline_overlap(self.intervals[left], self.intervals[right]) {
        result.push((self.intervals[left].id, self.intervals[right].id))
      }
    }
  }
  result
}

///|
/// Return free time slots on one resource.
pub fn ResourceTimeline::free_slots(
  self : ResourceTimeline,
  resource : Int,
) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  if resource < 0 || resource >= self.capacities.length() {
    return result
  }
  let profile = self.profile(resource)
  let mut open = -1
  for time, load in profile {
    if load == 0 && open < 0 {
      open = time
    } else if load > 0 && open >= 0 {
      result.push((open, time))
      open = -1
    }
  }
  if open >= 0 {
    result.push((open, self.horizon))
  }
  result
}

///|
/// Return the earliest free slot of a requested duration.
pub fn ResourceTimeline::find_slot(
  self : ResourceTimeline,
  resource : Int,
  duration : Int,
) -> Int? {
  if duration < 0 || resource < 0 || resource >= self.capacities.length() {
    return None
  }
  for slot in self.free_slots(resource) {
    if slot.1 - slot.0 >= duration {
      return Some(slot.0)
    }
  }
  None
}

///|
/// Return weighted utilization in integer percentage points.
pub fn ResourceTimeline::utilization(
  self : ResourceTimeline,
  resource : Int,
) -> Int {
  if resource < 0 ||
    resource >= self.capacities.length() ||
    self.horizon == 0 ||
    self.capacities[resource] == 0 {
    return 0
  }
  integer_sum(self.profile(resource)) *
  100 /
  (self.horizon * self.capacities[resource])
}

///|
/// Return the latest occupied time.
pub fn ResourceTimeline::makespan(self : ResourceTimeline) -> Int {
  let mut result = 0
  for interval in self.intervals {
    if interval.end > result {
      result = interval.end
    }
  }
  result
}

///|
/// Return total work.
pub fn ResourceTimeline::total_work(self : ResourceTimeline) -> Int {
  let mut result = 0
  for interval in self.intervals {
    result += interval.duration() * interval.weight
  }
  result
}

///|
/// Return intervals sorted by start time.
pub fn ResourceTimeline::ordered(
  self : ResourceTimeline,
  resource : Int,
) -> Array[TimelineInterval] {
  let result = self.on_resource(resource)
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if result[right].start < result[left].start {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Merge adjacent intervals with the same resource and label.
pub fn merge_timeline_intervals(
  intervals : Array[TimelineInterval],
) -> Array[TimelineInterval] {
  let ordered = intervals.copy()
  for left in 0..<ordered.length() {
    for right in (left + 1)..<ordered.length() {
      if ordered[right].start < ordered[left].start {
        let temporary = ordered[left]
        ordered[left] = ordered[right]
        ordered[right] = temporary
      }
    }
  }
  let result : Array[TimelineInterval] = []
  for interval in ordered {
    if result.length() > 0 {
      let previous = result[result.length() - 1]
      if previous.resource == interval.resource &&
        previous.label == interval.label &&
        previous.end >= interval.start {
        result[result.length() - 1] = {
          ..previous,
          end: if previous.end > interval.end {
            previous.end
          } else {
            interval.end
          },
        }
        continue
      }
    }
    result.push(interval)
  }
  result
}

///|
/// Return the total covered duration after merging intervals.
pub fn covered_duration(intervals : Array[TimelineInterval]) -> Int {
  let merged = merge_timeline_intervals(intervals)
  let mut result = 0
  for interval in merged {
    result += interval.duration()
  }
  result
}

///|
/// Shift all intervals by an offset.
pub fn shift_timeline(
  intervals : Array[TimelineInterval],
  offset : Int,
) -> Array[TimelineInterval] {
  intervals.map(interval => {
    ..interval,
    start: interval.start + offset,
    end: interval.end + offset,
  })
}

///|
/// Return intervals that contain a time point.
pub fn intervals_at(
  intervals : Array[TimelineInterval],
  time : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for interval in intervals {
    if interval.contains(time) {
      result.push(interval.id)
    }
  }
  result
}

///|
/// Return a stable timeline fingerprint.
pub fn ResourceTimeline::signature(self : ResourceTimeline) -> Int {
  let mut result = self.horizon * 31
  for interval in self.intervals {
    result = result * 37 +
      interval.id * 3 +
      interval.resource * 5 +
      interval.start * 7 +
      interval.end * 11 +
      interval.weight
  }
  result
}

///|
/// Render resource intervals.
pub fn ResourceTimeline::render(self : ResourceTimeline) -> String {
  let builder = StringBuilder()
  for resource in 0..<self.capacities.length() {
    if resource > 0 {
      builder.write_char('\n')
    }
    builder.write_string("resource \{resource}:")
    for interval in self.ordered(resource) {
      builder.write_string(
        " \{interval.label}@\{interval.start}-\{interval.end}",
      )
    }
  }
  builder.to_string()
}

///|
/// Return the number of active resources at a time.
pub fn active_resource_count(timeline : ResourceTimeline, time : Int) -> Int {
  let result : Array[Int] = []
  for interval in timeline.intervals {
    if interval.contains(time) && !result.contains(interval.resource) {
      result.push(interval.resource)
    }
  }
  result.length()
}

///|
/// Return a timeline quality score.
pub fn timeline_objective(timeline : ResourceTimeline) -> Int {
  timeline.makespan() +
  timeline.conflicts().length() * 1000000 +
  timeline.overloads(0).length() * 1000
}
