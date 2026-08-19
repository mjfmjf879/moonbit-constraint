///|
/// Run the deterministic application benchmark suite and emit a CI-friendly
/// report.  The command exits with a failure when a canonical case is not
/// solved, so it can be used as a regression gate.
fn main {
  let results = @constraint.benchmark_suite()
  println(@constraint.benchmark_report(results))
  let work = @constraint.benchmark_work(results)
  println("benchmark_work: \{work}")
  println("")
  println(@constraint.benchmark_markdown(results))
  if !@constraint.benchmarks_pass(results) {
    abort("benchmark suite contains an unsolved case")
  }
}
