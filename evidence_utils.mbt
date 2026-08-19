///|
/// Compact evidence records for local acceptance runs.
pub struct EvidenceRecord {
  name : String
  metric : String
  value : Int
  expected : Int
  passed : Bool
}

///|
/// Create an evidence record.
pub fn evidence_record(
  name : String,
  metric : String,
  value : Int,
  expected : Int,
  passed : Bool,
) -> EvidenceRecord {
  { name, metric, value, expected, passed }
}

///|
pub fn EvidenceRecord::passed(self : EvidenceRecord) -> Bool {
  self.passed
}

///|
pub fn EvidenceRecord::value(self : EvidenceRecord) -> Int {
  self.value
}

///|
pub fn EvidenceRecord::expected(self : EvidenceRecord) -> Int {
  self.expected
}

///|
pub fn EvidenceRecord::describe(self : EvidenceRecord) -> String {
  "\{self.name}:\{self.metric}=\{self.value}/\{self.expected} (\{self.passed})"
}

///|
/// A collection of evidence records.
pub struct EvidenceBundle {
  records : Array[EvidenceRecord]
}

///|
/// Create a bundle.
pub fn evidence_bundle() -> EvidenceBundle {
  { records: [] }
}

///|
pub fn EvidenceBundle::add(
  self : EvidenceBundle,
  record : EvidenceRecord,
) -> Bool {
  self.records.push(record)
  true
}

///|
pub fn EvidenceBundle::length(self : EvidenceBundle) -> Int {
  self.records.length()
}

///|
pub fn EvidenceBundle::passed(self : EvidenceBundle) -> Bool {
  for record in self.records {
    if !record.passed {
      return false
    }
  }
  true
}

///|
pub fn EvidenceBundle::failure_count(self : EvidenceBundle) -> Int {
  let mut result = 0
  for record in self.records {
    if !record.passed {
      result += 1
    }
  }
  result
}

///|
pub fn EvidenceBundle::values(self : EvidenceBundle) -> Array[Int] {
  self.records.map(record => record.value)
}

///|
pub fn EvidenceBundle::describe(self : EvidenceBundle) -> String {
  let builder = StringBuilder()
  for index, record in self.records {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(record.describe())
  }
  builder.to_string()
}

///|
pub fn EvidenceBundle::signature(self : EvidenceBundle) -> Int {
  let mut result = 31
  for record in self.records {
    result = result * 37 + record.value + record.expected
  }
  result
}

///|
/// Add a minimum evidence gate.
pub fn EvidenceBundle::minimum(
  self : EvidenceBundle,
  name : String,
  metric : String,
  value : Int,
  expected : Int,
) -> Unit {
  ignore(
    self.add(evidence_record(name, metric, value, expected, value >= expected)),
  )
}

///|
/// Add a maximum evidence gate.
pub fn EvidenceBundle::maximum(
  self : EvidenceBundle,
  name : String,
  metric : String,
  value : Int,
  expected : Int,
) -> Unit {
  ignore(
    self.add(evidence_record(name, metric, value, expected, value <= expected)),
  )
}

///|
/// Add an exact evidence gate.
pub fn EvidenceBundle::exact(
  self : EvidenceBundle,
  name : String,
  metric : String,
  value : Int,
  expected : Int,
) -> Unit {
  ignore(
    self.add(evidence_record(name, metric, value, expected, value == expected)),
  )
}

///|
/// Build source-scale evidence.
pub fn source_scale_evidence(lines : Int, target : Int) -> EvidenceBundle {
  let bundle = evidence_bundle()
  bundle.minimum(
    "production-source", "noncomment-nonblank-lines", lines, target,
  )
  bundle
}

///|
/// Build benchmark evidence.
pub fn benchmark_evidence(
  suite : BenchmarkArtifactSuite,
  minimum_cases : Int,
) -> EvidenceBundle {
  let bundle = evidence_bundle()
  bundle.minimum("benchmark-suite", "cases", suite.length(), minimum_cases)
  bundle.exact(
    "benchmark-suite",
    "all-solved",
    if suite.all_solved() {
      1
    } else {
      0
    },
    1,
  )
  bundle.minimum("benchmark-suite", "total-work", suite.total_work(), 0)
  bundle
}

///|
/// Build model evidence.
pub fn model_evidence(report : ModelReport) -> EvidenceBundle {
  let bundle = evidence_bundle()
  bundle.minimum(report.name, "variables", report.variables, 1)
  bundle.minimum(report.name, "constraints", report.constraints, 1)
  bundle.exact(report.name, "solved", if report.solved { 1 } else { 0 }, 1)
  bundle
}

///|
/// Compare two evidence bundles.
pub fn compare_evidence(left : EvidenceBundle, right : EvidenceBundle) -> Int {
  right.failure_count() - left.failure_count()
}

///|
/// Return the number of passing records.
pub fn evidence_pass_count(bundle : EvidenceBundle) -> Int {
  bundle.length() - bundle.failure_count()
}

///|
/// Return a stable evidence summary.
pub fn evidence_summary(bundle : EvidenceBundle) -> String {
  "records=\{bundle.length()}, passed=\{evidence_pass_count(bundle)}, failed=\{bundle.failure_count()}, status=\{bundle.passed()}"
}
