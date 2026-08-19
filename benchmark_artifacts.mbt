///|
/// Benchmark artifact aggregation and reproducibility checks.
///
/// The core benchmark command emits deterministic solver counters. This layer
/// packages several runs into a suite, checks repeat consistency, and produces
/// machine-readable evidence for local acceptance and CI summaries.
pub struct ArtifactBenchmark {
  name : String
  work : Int
  solved : Bool
  signature : Int
}

///|
/// Create a benchmark artifact.
pub fn artifact_benchmark(
  name : String,
  work : Int,
  solved : Bool,
  signature : Int,
) -> ArtifactBenchmark {
  { name, work, solved, signature }
}

///|
/// Return artifact work.
pub fn ArtifactBenchmark::work(self : ArtifactBenchmark) -> Int {
  self.work
}

///|
/// Return solved state.
pub fn ArtifactBenchmark::solved(self : ArtifactBenchmark) -> Bool {
  self.solved
}

///|
/// Return a stable line.
pub fn ArtifactBenchmark::describe(self : ArtifactBenchmark) -> String {
  "\{self.name}: solved=\{self.solved}, work=\{self.work}, signature=\{self.signature}"
}

///|
/// A benchmark suite.
pub struct BenchmarkArtifactSuite {
  name : String
  cases : Array[ArtifactBenchmark]
}

///|
/// Create a suite.
pub fn benchmark_artifact_suite(name : String) -> BenchmarkArtifactSuite {
  { name, cases: [] }
}

///|
/// Add a case with a unique name.
pub fn BenchmarkArtifactSuite::add(
  self : BenchmarkArtifactSuite,
  benchmark : ArtifactBenchmark,
) -> Bool {
  for current in self.cases {
    if current.name == benchmark.name {
      return false
    }
  }
  self.cases.push(benchmark)
  true
}

///|
/// Return case count.
pub fn BenchmarkArtifactSuite::length(self : BenchmarkArtifactSuite) -> Int {
  self.cases.length()
}

///|
/// Return total work.
pub fn BenchmarkArtifactSuite::total_work(self : BenchmarkArtifactSuite) -> Int {
  integer_sum(self.cases.map(case => case.work))
}

///|
/// Return unsolved case count.
pub fn BenchmarkArtifactSuite::unsolved(self : BenchmarkArtifactSuite) -> Int {
  let mut result = 0
  for case in self.cases {
    if !case.solved {
      result += 1
    }
  }
  result
}

///|
/// Return whether all cases are solved.
pub fn BenchmarkArtifactSuite::all_solved(
  self : BenchmarkArtifactSuite,
) -> Bool {
  self.unsolved() == 0
}

///|
/// Return whether signatures are unique.
pub fn BenchmarkArtifactSuite::unique_signatures(
  self : BenchmarkArtifactSuite,
) -> Bool {
  for left in 0..<self.cases.length() {
    for right in 0..<left {
      if self.cases[left].signature == self.cases[right].signature {
        return false
      }
    }
  }
  true
}

///|
/// Return the heaviest case.
pub fn BenchmarkArtifactSuite::heaviest(
  self : BenchmarkArtifactSuite,
) -> ArtifactBenchmark? {
  if self.cases.length() == 0 {
    return None
  }
  let mut result = self.cases[0]
  for case in self.cases {
    if case.work > result.work {
      result = case
    }
  }
  Some(result)
}

///|
/// Compare two suites by case name and work.
pub fn compare_benchmark_suites(
  baseline : BenchmarkArtifactSuite,
  candidate : BenchmarkArtifactSuite,
) -> Array[(String, Int, Int)] {
  let result : Array[(String, Int, Int)] = []
  for current in candidate.cases {
    for previous in baseline.cases {
      if current.name == previous.name {
        result.push((current.name, previous.work, current.work))
      }
    }
  }
  result
}

///|
/// Return cases whose work regressed beyond tolerance.
pub fn benchmark_regressions(
  baseline : BenchmarkArtifactSuite,
  candidate : BenchmarkArtifactSuite,
  tolerance : Int,
) -> Array[String] {
  let result : Array[String] = []
  for pair in compare_benchmark_suites(baseline, candidate) {
    if regressed(pair.1, pair.2, tolerance) {
      result.push(pair.0)
    }
  }
  result
}

///|
/// Render a suite as markdown.
pub fn BenchmarkArtifactSuite::markdown(
  self : BenchmarkArtifactSuite,
) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "case | solved | work | signature\n--- | --- | ---: | ---:",
  )
  for case in self.cases {
    builder.write_string(
      "\n\{case.name} | \{case.solved} | \{case.work} | \{case.signature}",
    )
  }
  builder.to_string()
}

///|
/// Return a suite signature.
pub fn BenchmarkArtifactSuite::signature(self : BenchmarkArtifactSuite) -> Int {
  let mut result = 31
  for case in self.cases {
    result = result * 37 + case.signature + case.work
  }
  result
}

///|
/// Return a stable suite report.
pub fn BenchmarkArtifactSuite::describe(
  self : BenchmarkArtifactSuite,
) -> String {
  "\{self.name}: cases=\{self.length()}, total_work=\{self.total_work()}, unsolved=\{self.unsolved()}, unique=\{self.unique_signatures()}"
}

///|
/// Return the work values in case order.
pub fn BenchmarkArtifactSuite::work_values(
  self : BenchmarkArtifactSuite,
) -> Array[Int] {
  self.cases.map(case => case.work)
}

///|
/// Return a summary statistic.
pub fn BenchmarkArtifactSuite::summary(
  self : BenchmarkArtifactSuite,
) -> IntegerSummary {
  integer_summary(self.work_values())
}
