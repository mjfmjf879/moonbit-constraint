///|
/// Lifecycle states used by long-running planning and validation jobs.
pub enum OperationalState {
  LedgerQueued
  LedgerRunning
  LedgerSucceeded
  LedgerFailed
  LedgerSkipped
}

///|
/// A compact, serializable record for one operational job.
pub struct OperationalRecord {
  key : String
  state : OperationalState
  started_at : Int
  finished_at : Int
  attempts : Int
  output_count : Int
  error_code : Int
}

///|
pub fn operational_record(
  key : String,
  state : OperationalState,
  started_at : Int,
  finished_at : Int,
  attempts : Int,
  output_count : Int,
  error_code : Int,
) -> OperationalRecord {
  { key, state, started_at, finished_at, attempts, output_count, error_code }
}

///|
pub fn operational_state_name(state : OperationalState) -> String {
  match state {
    LedgerQueued => "queued"
    LedgerRunning => "running"
    LedgerSucceeded => "succeeded"
    LedgerFailed => "failed"
    LedgerSkipped => "skipped"
  }
}

///|
pub fn operational_queued() -> OperationalState {
  LedgerQueued
}

///|
pub fn operational_running() -> OperationalState {
  LedgerRunning
}

///|
pub fn operational_succeeded() -> OperationalState {
  LedgerSucceeded
}

///|
pub fn operational_failed() -> OperationalState {
  LedgerFailed
}

///|
pub fn operational_skipped() -> OperationalState {
  LedgerSkipped
}

///|
pub fn operational_state_equal(
  left : OperationalState,
  right : OperationalState,
) -> Bool {
  match left {
    LedgerQueued =>
      match right {
        LedgerQueued => true
        _ => false
      }
    LedgerRunning =>
      match right {
        LedgerRunning => true
        _ => false
      }
    LedgerSucceeded =>
      match right {
        LedgerSucceeded => true
        _ => false
      }
    LedgerFailed =>
      match right {
        LedgerFailed => true
        _ => false
      }
    LedgerSkipped =>
      match right {
        LedgerSkipped => true
        _ => false
      }
  }
}

///|
pub fn operational_record_duration(record : OperationalRecord) -> Int {
  if record.finished_at < record.started_at {
    0
  } else {
    record.finished_at - record.started_at
  }
}

///|
pub fn operational_record_terminal(record : OperationalRecord) -> Bool {
  match record.state {
    LedgerSucceeded | LedgerFailed | LedgerSkipped => true
    LedgerQueued | LedgerRunning => false
  }
}

///|
pub fn operational_record_success(record : OperationalRecord) -> Bool {
  match record.state {
    LedgerSucceeded => true
    LedgerQueued | LedgerRunning | LedgerFailed | LedgerSkipped => false
  }
}

///|
pub fn operational_record_failure(record : OperationalRecord) -> Bool {
  match record.state {
    LedgerFailed => true
    LedgerQueued | LedgerRunning | LedgerSucceeded | LedgerSkipped => false
  }
}

///|
pub fn operational_record_retryable(record : OperationalRecord) -> Bool {
  operational_record_failure(record) && record.attempts < 3
}

///|
pub fn operational_record_valid(record : OperationalRecord) -> Bool {
  record.key.length() > 0 &&
  record.started_at >= 0 &&
  record.finished_at >= 0 &&
  record.attempts >= 0 &&
  record.output_count >= 0 &&
  (operational_record_success(record) || record.error_code >= 0)
}

///|
pub struct OperationalLedger {
  records : Array[OperationalRecord]
}

///|
pub fn operational_ledger() -> OperationalLedger {
  { records: [] }
}

///|
pub fn OperationalLedger::append(
  self : OperationalLedger,
  record : OperationalRecord,
) -> Bool {
  if !operational_record_valid(record) {
    false
  } else if self.contains(record.key) {
    false
  } else {
    self.records.push(record)
    true
  }
}

///|
pub fn OperationalLedger::upsert(
  self : OperationalLedger,
  record : OperationalRecord,
) -> Bool {
  if !operational_record_valid(record) {
    false
  } else {
    match self.index_of(record.key) {
      Some(index) => {
        self.records[index] = record
        true
      }
      None => {
        self.records.push(record)
        true
      }
    }
  }
}

///|
pub fn OperationalLedger::contains(
  self : OperationalLedger,
  key : String,
) -> Bool {
  self.index_of(key) is Some(_)
}

///|
pub fn OperationalLedger::index_of(
  self : OperationalLedger,
  key : String,
) -> Int? {
  for index, record in self.records {
    if record.key == key {
      return Some(index)
    }
  }
  None
}

///|
pub fn OperationalLedger::get(
  self : OperationalLedger,
  key : String,
) -> OperationalRecord? {
  match self.index_of(key) {
    Some(index) => Some(self.records[index])
    None => None
  }
}

///|
pub fn OperationalLedger::remove(
  self : OperationalLedger,
  key : String,
) -> Bool {
  match self.index_of(key) {
    Some(index) => {
      ignore(self.records.remove(index))
      true
    }
    None => false
  }
}

///|
pub fn OperationalLedger::clear(self : OperationalLedger) -> Unit {
  self.records.clear()
}

///|
pub fn OperationalLedger::len(self : OperationalLedger) -> Int {
  self.records.length()
}

///|
pub fn OperationalLedger::is_empty(self : OperationalLedger) -> Bool {
  self.records.length() == 0
}

///|
pub fn OperationalLedger::count_state(
  self : OperationalLedger,
  state : OperationalState,
) -> Int {
  let mut result = 0
  for record in self.records {
    if operational_state_equal(record.state, state) {
      result += 1
    }
  }
  result
}

///|
pub fn OperationalLedger::count_terminal(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    if operational_record_terminal(record) {
      result += 1
    }
  }
  result
}

///|
pub fn OperationalLedger::count_success(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    if operational_record_success(record) {
      result += 1
    }
  }
  result
}

///|
pub fn OperationalLedger::count_failure(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    if operational_record_failure(record) {
      result += 1
    }
  }
  result
}

///|
pub fn OperationalLedger::count_retryable(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    if operational_record_retryable(record) {
      result += 1
    }
  }
  result
}

///|
pub fn OperationalLedger::duration_sum(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    result += operational_record_duration(record)
  }
  result
}

///|
pub fn OperationalLedger::output_sum(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    result += record.output_count
  }
  result
}

///|
pub fn OperationalLedger::attempt_sum(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    result += record.attempts
  }
  result
}

///|
pub fn OperationalLedger::max_duration(self : OperationalLedger) -> Int {
  let mut result = 0
  for record in self.records {
    let duration = operational_record_duration(record)
    if duration > result {
      result = duration
    }
  }
  result
}

///|
pub fn OperationalLedger::min_duration(self : OperationalLedger) -> Int? {
  if self.is_empty() {
    None
  } else {
    let mut result = operational_record_duration(self.records[0])
    for record in self.records {
      let duration = operational_record_duration(record)
      if duration < result {
        result = duration
      }
    }
    Some(result)
  }
}

///|
pub fn OperationalLedger::success_rate(self : OperationalLedger) -> Int {
  let terminal = self.count_terminal()
  if terminal == 0 {
    0
  } else {
    self.count_success() * 100 / terminal
  }
}

///|
pub fn OperationalLedger::failure_rate(self : OperationalLedger) -> Int {
  let terminal = self.count_terminal()
  if terminal == 0 {
    0
  } else {
    self.count_failure() * 100 / terminal
  }
}

///|
pub fn OperationalLedger::throughput(self : OperationalLedger) -> Int {
  let duration = self.duration_sum()
  if duration == 0 {
    0
  } else {
    self.output_sum() * 1000 / duration
  }
}

///|
pub fn OperationalLedger::filter_state(
  self : OperationalLedger,
  state : OperationalState,
) -> Array[OperationalRecord] {
  let result : Array[OperationalRecord] = []
  for record in self.records {
    if operational_state_equal(record.state, state) {
      result.push(record)
    }
  }
  result
}

///|
pub fn OperationalLedger::keys(self : OperationalLedger) -> Array[String] {
  let result : Array[String] = []
  for record in self.records {
    result.push(record.key)
  }
  result
}

///|
pub fn OperationalLedger::error_codes(self : OperationalLedger) -> Array[Int] {
  let result : Array[Int] = []
  for record in self.records {
    if operational_record_failure(record) {
      result.push(record.error_code)
    }
  }
  result
}

///|
pub fn OperationalLedger::validate(self : OperationalLedger) -> Bool {
  for index, record in self.records {
    if !operational_record_valid(record) {
      return false
    }
    for other_index in 0..<index {
      if self.records[other_index].key == record.key {
        return false
      }
    }
  }
  true
}

///|
pub fn OperationalLedger::signature(self : OperationalLedger) -> Int {
  let mut result = 23
  for record in self.records {
    result = result * 31 + record.key.length()
    result = result * 31 + record.started_at
    result = result * 31 + record.finished_at
    result = result * 31 + record.attempts
    result = result * 31 + record.output_count
    result = result * 31 + record.error_code
  }
  result
}

///|
pub struct OperationalSummary {
  total : Int
  queued : Int
  running : Int
  succeeded : Int
  failed : Int
  skipped : Int
  duration : Int
  outputs : Int
  attempts : Int
  success_rate : Int
  failure_rate : Int
  throughput : Int
}

///|
pub fn OperationalLedger::summary(
  self : OperationalLedger,
) -> OperationalSummary {
  {
    total: self.len(),
    queued: self.count_state(LedgerQueued),
    running: self.count_state(LedgerRunning),
    succeeded: self.count_state(LedgerSucceeded),
    failed: self.count_state(LedgerFailed),
    skipped: self.count_state(LedgerSkipped),
    duration: self.duration_sum(),
    outputs: self.output_sum(),
    attempts: self.attempt_sum(),
    success_rate: self.success_rate(),
    failure_rate: self.failure_rate(),
    throughput: self.throughput(),
  }
}

///|
pub fn operational_summary_valid(summary : OperationalSummary) -> Bool {
  summary.total >= 0 &&
  summary.queued >= 0 &&
  summary.running >= 0 &&
  summary.succeeded >= 0 &&
  summary.failed >= 0 &&
  summary.skipped >= 0 &&
  summary.duration >= 0 &&
  summary.outputs >= 0 &&
  summary.attempts >= 0 &&
  summary.success_rate >= 0 &&
  summary.success_rate <= 100 &&
  summary.failure_rate >= 0 &&
  summary.failure_rate <= 100 &&
  summary.throughput >= 0
}

///|
pub fn operational_summary_balance(summary : OperationalSummary) -> Bool {
  summary.total ==
  summary.queued +
  summary.running +
  summary.succeeded +
  summary.failed +
  summary.skipped
}

///|
pub fn operational_summary_report(summary : OperationalSummary) -> String {
  "total=\{summary.total}, succeeded=\{summary.succeeded}, failed=\{summary.failed}, outputs=\{summary.outputs}, throughput=\{summary.throughput}"
}

///|
pub fn operational_state_terminal(state : OperationalState) -> Bool {
  match state {
    LedgerSucceeded | LedgerFailed | LedgerSkipped => true
    LedgerQueued | LedgerRunning => false
  }
}

///|
pub fn operational_next_state(
  current : OperationalState,
  success : Bool,
) -> OperationalState {
  match current {
    LedgerQueued => LedgerRunning
    LedgerRunning => if success { LedgerSucceeded } else { LedgerFailed }
    LedgerSucceeded => LedgerSucceeded
    LedgerFailed => if success { LedgerSucceeded } else { LedgerFailed }
    LedgerSkipped => LedgerSkipped
  }
}

///|
pub fn operational_retry_state(record : OperationalRecord) -> OperationalState {
  if operational_record_retryable(record) {
    LedgerQueued
  } else {
    record.state
  }
}

///|
pub fn operational_backlog(ledger : OperationalLedger) -> Int {
  ledger.count_state(LedgerQueued) + ledger.count_state(LedgerRunning)
}

///|
pub fn operational_health_score(ledger : OperationalLedger) -> Int {
  let summary = ledger.summary()
  if !operational_summary_valid(summary) ||
    !operational_summary_balance(summary) {
    0
  } else {
    let reliability = if summary.failure_rate > 0 {
      100 - summary.failure_rate
    } else {
      100
    }
    let score = summary.success_rate * 10 + reliability
    if score > 1000 {
      1000
    } else {
      score
    }
  }
}

///|
pub fn operational_capacity_ok(
  ledger : OperationalLedger,
  maximum_backlog : Int,
) -> Bool {
  maximum_backlog >= 0 && operational_backlog(ledger) <= maximum_backlog
}

///|
pub fn operational_window(
  ledger : OperationalLedger,
  start : Int,
  finish : Int,
) -> Array[OperationalRecord] {
  let result : Array[OperationalRecord] = []
  if finish < start {
    return result
  }
  for record in ledger.records {
    if record.finished_at >= start && record.started_at <= finish {
      result.push(record)
    }
  }
  result
}

///|
pub fn operational_window_output(
  ledger : OperationalLedger,
  start : Int,
  finish : Int,
) -> Int {
  let mut result = 0
  for record in operational_window(ledger, start, finish) {
    result += record.output_count
  }
  result
}

///|
pub fn operational_merge(
  left : OperationalLedger,
  right : OperationalLedger,
) -> OperationalLedger {
  let result = operational_ledger()
  for record in left.records {
    ignore(result.upsert(record))
  }
  for record in right.records {
    ignore(result.upsert(record))
  }
  result
}

///|
pub fn operational_delta(
  left : OperationalSummary,
  right : OperationalSummary,
) -> OperationalSummary {
  {
    total: right.total - left.total,
    queued: right.queued - left.queued,
    running: right.running - left.running,
    succeeded: right.succeeded - left.succeeded,
    failed: right.failed - left.failed,
    skipped: right.skipped - left.skipped,
    duration: right.duration - left.duration,
    outputs: right.outputs - left.outputs,
    attempts: right.attempts - left.attempts,
    success_rate: right.success_rate - left.success_rate,
    failure_rate: right.failure_rate - left.failure_rate,
    throughput: right.throughput - left.throughput,
  }
}

///|
pub fn operational_record_repair(
  record : OperationalRecord,
) -> OperationalRecord {
  let safe_started = if record.started_at < 0 { 0 } else { record.started_at }
  let safe_finished = if record.finished_at < safe_started {
    safe_started
  } else {
    record.finished_at
  }
  {
    key: record.key,
    state: record.state,
    started_at: safe_started,
    finished_at: safe_finished,
    attempts: if record.attempts < 0 {
      0
    } else {
      record.attempts
    },
    output_count: if record.output_count < 0 {
      0
    } else {
      record.output_count
    },
    error_code: if record.error_code < 0 {
      0
    } else {
      record.error_code
    },
  }
}

///|
pub fn operational_records_sorted_by_finish(
  records : Array[OperationalRecord],
) -> Array[OperationalRecord] {
  let result = records.copy()
  for index in 0..<result.length() {
    let mut best = index
    for candidate in (index + 1)..<result.length() {
      if result[candidate].finished_at < result[best].finished_at {
        best = candidate
      }
    }
    if best != index {
      let temporary = result[index]
      result[index] = result[best]
      result[best] = temporary
    }
  }
  result
}

///|
pub fn operational_records_total_output(
  records : Array[OperationalRecord],
) -> Int {
  let mut result = 0
  for record in records {
    result += record.output_count
  }
  result
}

///|
pub fn operational_records_terminal(records : Array[OperationalRecord]) -> Bool {
  for record in records {
    if !operational_record_terminal(record) {
      return false
    }
  }
  true
}
