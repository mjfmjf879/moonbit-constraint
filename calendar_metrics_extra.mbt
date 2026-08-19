///|
/// Calendar window metrics for service and scheduling reports.
pub struct CalendarWindow {
  start : Int
  end : Int
}

///|
/// Create a calendar window.
pub fn calendar_window(start : Int, end : Int) -> CalendarWindow {
  { start, end }
}

///|
pub fn CalendarWindow::duration(self : CalendarWindow) -> Int {
  if self.end > self.start {
    self.end - self.start
  } else {
    0
  }
}

///|
pub fn CalendarWindow::valid(self : CalendarWindow) -> Bool {
  self.start <= self.end
}

///|
pub fn CalendarWindow::contains(self : CalendarWindow, time : Int) -> Bool {
  time >= self.start && time < self.end
}

///|
pub fn CalendarWindow::overlaps(
  self : CalendarWindow,
  other : CalendarWindow,
) -> Bool {
  self.start < other.end && other.start < self.end
}

///|
pub fn CalendarWindow::touches(
  self : CalendarWindow,
  other : CalendarWindow,
) -> Bool {
  self.end == other.start || other.end == self.start
}

///|
pub fn CalendarWindow::intersection(
  self : CalendarWindow,
  other : CalendarWindow,
) -> CalendarWindow? {
  if !self.overlaps(other) {
    None
  } else {
    Some(
      calendar_window(
        fm_max(self.start, other.start),
        fm_min(self.end, other.end),
      ),
    )
  }
}

///|
pub fn CalendarWindow::shift(
  self : CalendarWindow,
  offset : Int,
) -> CalendarWindow {
  calendar_window(self.start + offset, self.end + offset)
}

///|
pub fn CalendarWindow::expand(
  self : CalendarWindow,
  amount : Int,
) -> CalendarWindow {
  calendar_window(self.start - amount, self.end + amount)
}

///|
pub fn CalendarWindow::describe(self : CalendarWindow) -> String {
  "[\{self.start},\{self.end})"
}

///|
/// Merge overlapping and touching windows.
pub fn merge_calendar_windows(
  windows : Array[CalendarWindow],
) -> Array[CalendarWindow] {
  let ordered = windows.copy()
  for left in 0..<ordered.length() {
    for right in (left + 1)..<ordered.length() {
      if ordered[right].start < ordered[left].start {
        let temporary = ordered[left]
        ordered[left] = ordered[right]
        ordered[right] = temporary
      }
    }
  }
  let result : Array[CalendarWindow] = []
  for window in ordered {
    if result.length() > 0 {
      let previous = result[result.length() - 1]
      if previous.end >= window.start {
        result[result.length() - 1] = calendar_window(
          previous.start,
          fm_max(previous.end, window.end),
        )
        continue
      }
    }
    result.push(window)
  }
  result
}

///|
/// Return total covered duration.
pub fn calendar_covered_duration(windows : Array[CalendarWindow]) -> Int {
  let mut result = 0
  for window in merge_calendar_windows(windows) {
    result += window.duration()
  }
  result
}

///|
/// Return total gap duration between windows.
pub fn calendar_gap_duration(windows : Array[CalendarWindow]) -> Int {
  let merged = merge_calendar_windows(windows)
  let mut result = 0
  for index in 1..<merged.length() {
    result += merged[index].start - merged[index - 1].end
  }
  result
}

///|
/// Return the first free start for a duration after a time.
pub fn calendar_first_free(
  windows : Array[CalendarWindow],
  after : Int,
  duration : Int,
) -> Int {
  let ordered = merge_calendar_windows(windows)
  let mut candidate = after
  for window in ordered {
    if candidate + duration <= window.start {
      return candidate
    }
    if candidate < window.end {
      candidate = window.end
    }
  }
  candidate
}

///|
/// Return all windows that contain a time.
pub fn calendar_active(windows : Array[CalendarWindow], time : Int) -> Int {
  let mut result = 0
  for window in windows {
    if window.contains(time) {
      result += 1
    }
  }
  result
}

///|
/// Return the maximum concurrency.
pub fn calendar_peak_concurrency(windows : Array[CalendarWindow]) -> Int {
  let mut result = 0
  for window in windows {
    let current = calendar_active(windows, window.start)
    if current > result {
      result = current
    }
  }
  result
}

///|
/// Return whether windows are non-overlapping.
pub fn calendar_non_overlapping(windows : Array[CalendarWindow]) -> Bool {
  let mut original = 0
  for window in windows {
    original += window.duration()
  }
  original == calendar_covered_duration(windows)
}

///|
/// Return a window set fingerprint.
pub fn calendar_window_signature(windows : Array[CalendarWindow]) -> Int {
  let mut result = 31
  for window in windows {
    result = result * 37 + window.start * 3 + window.end * 5
  }
  result
}

///|
/// Return windows within a horizon.
pub fn calendar_clip(
  windows : Array[CalendarWindow],
  lower : Int,
  upper : Int,
) -> Array[CalendarWindow] {
  let result : Array[CalendarWindow] = []
  for window in windows {
    let start = fm_max(window.start, lower)
    let end = fm_min(window.end, upper)
    if start < end {
      result.push(calendar_window(start, end))
    }
  }
  result
}

///|
/// Return a regular slot grid.
pub fn calendar_slots(
  start : Int,
  end : Int,
  step : Int,
) -> Array[CalendarWindow] {
  let result : Array[CalendarWindow] = []
  if step <= 0 {
    return result
  }
  let mut current = start
  while current < end {
    result.push(calendar_window(current, fm_min(current + step, end)))
    current += step
  }
  result
}

///|
/// Return slots occupied by any window.
pub fn occupied_slots(
  windows : Array[CalendarWindow],
  slots : Array[CalendarWindow],
) -> Array[Int] {
  let result : Array[Int] = []
  for index, slot in slots {
    for window in windows {
      if slot.overlaps(window) {
        result.push(index)
        break
      }
    }
  }
  result
}

///|
/// Return free slots.
pub fn free_slots(
  windows : Array[CalendarWindow],
  slots : Array[CalendarWindow],
) -> Array[Int] {
  let occupied = occupied_slots(windows, slots)
  let result : Array[Int] = []
  for index in 0..<slots.length() {
    if !occupied.contains(index) {
      result.push(index)
    }
  }
  result
}

///|
/// Return total duration of free slots.
pub fn free_slot_duration(
  windows : Array[CalendarWindow],
  slots : Array[CalendarWindow],
) -> Int {
  let free = free_slots(windows, slots)
  let mut result = 0
  for index in free {
    result += slots[index].duration()
  }
  result
}

///|
/// Return a calendar summary.
pub fn calendar_summary(windows : Array[CalendarWindow]) -> String {
  "windows=\{windows.length()}, covered=\{calendar_covered_duration(windows)}, gaps=\{calendar_gap_duration(windows)}, peak=\{calendar_peak_concurrency(windows)}"
}
