///|
/// A deterministic solver benchmark result.
pub struct BenchmarkResult {
  name : String
  solved : Bool
  solutions : Int
  nodes : Int
  propagations : Int
  checks : Int
  pruned : Int
  depth : Int
  repeat_count : Int
}

///|
/// Construct a benchmark result from solver counters.
pub fn benchmark_result(
  name : String,
  solved : Bool,
  solutions : Int,
  stats : SearchStats,
  repeat_count : Int,
) -> BenchmarkResult {
  {
    name,
    solved,
    solutions,
    nodes: stats.node_count(),
    propagations: stats.propagation_count(),
    checks: stats.check_count(),
    pruned: stats.pruned_count(),
    depth: stats.depth(),
    repeat_count,
  }
}

///|
/// Return the benchmark name.
pub fn BenchmarkResult::name(self : BenchmarkResult) -> String {
  self.name
}

///|
/// Return whether the case produced the expected satisfiability result.
pub fn BenchmarkResult::solved(self : BenchmarkResult) -> Bool {
  self.solved
}

///|
/// Return the number of collected solutions.
pub fn BenchmarkResult::solutions(self : BenchmarkResult) -> Int {
  self.solutions
}

///|
/// Return visited node count.
pub fn BenchmarkResult::nodes(self : BenchmarkResult) -> Int {
  self.nodes
}

///|
/// Return propagation count.
pub fn BenchmarkResult::propagations(self : BenchmarkResult) -> Int {
  self.propagations
}

///|
/// Return constraint-check count.
pub fn BenchmarkResult::checks(self : BenchmarkResult) -> Int {
  self.checks
}

///|
/// Return pruned-value count.
pub fn BenchmarkResult::pruned(self : BenchmarkResult) -> Int {
  self.pruned
}

///|
/// Return maximum depth.
pub fn BenchmarkResult::depth(self : BenchmarkResult) -> Int {
  self.depth
}

///|
/// Return number of repetitions.
pub fn BenchmarkResult::repeat_count(self : BenchmarkResult) -> Int {
  self.repeat_count
}

///|
/// Return a stable one-line benchmark record.
pub fn BenchmarkResult::describe(self : BenchmarkResult) -> String {
  "\{self.name}: solved=\{self.solved}, solutions=\{self.solutions}, nodes=\{self.nodes}, propagations=\{self.propagations}, checks=\{self.checks}, pruned=\{self.pruned}, depth=\{self.depth}, repeats=\{self.repeat_count}"
}

///|
/// Return the deterministic work score used when wall-clock noise is high.
pub fn BenchmarkResult::work(self : BenchmarkResult) -> Int {
  self.nodes + self.propagations + self.checks + self.pruned
}

///|
/// Aggregate counters across repeated deterministic runs.
pub fn repeat_benchmark(
  name : String,
  repeats : Int,
  run : () -> BenchmarkResult,
) -> BenchmarkResult {
  let count = if repeats < 1 { 1 } else { repeats }
  let first = run()
  let mut nodes = first.nodes
  let mut propagations = first.propagations
  let mut checks = first.checks
  let mut pruned = first.pruned
  let mut solutions = first.solutions
  let mut depth = first.depth
  let mut solved = first.solved
  for _ in 1..<count {
    let current = run()
    nodes += current.nodes
    propagations += current.propagations
    checks += current.checks
    pruned += current.pruned
    solutions += current.solutions
    if current.depth > depth {
      depth = current.depth
    }
    solved = solved && current.solved
  }
  {
    name,
    solved,
    solutions,
    nodes,
    propagations,
    checks,
    pruned,
    depth,
    repeat_count: count,
  }
}

///|
/// Run the canonical N-Queens benchmark.
pub fn benchmark_n_queens(size : Int) -> BenchmarkResult {
  match n_queens(size) {
    None =>
      benchmark_result("nqueens_\{size}", false, 0, empty_search_stats(), 1)
    Some(problem) => {
      let solutions = problem.solve_all(1)
      benchmark_result(
        "nqueens_\{size}",
        solutions.length() > 0,
        solutions.length(),
        problem.stats(),
        1,
      )
    }
  }
}

///|
/// Run the canonical Sudoku benchmark.
pub fn benchmark_sudoku() -> BenchmarkResult {
  match classic_sudoku() {
    None =>
      benchmark_result("sudoku_classic", false, 0, empty_search_stats(), 1)
    Some(problem) => {
      let solutions = problem.solve_all(1)
      benchmark_result(
        "sudoku_classic",
        solutions.length() > 0,
        solutions.length(),
        problem.stats(),
        1,
      )
    }
  }
}

///|
/// Run a small Latin-square benchmark.
pub fn benchmark_latin(size : Int) -> BenchmarkResult {
  match latin_square(size) {
    None => benchmark_result("latin_\{size}", false, 0, empty_search_stats(), 1)
    Some(problem) => {
      problem.fix_first_row()
      let solutions = problem.solve()
      benchmark_result(
        "latin_\{size}",
        solutions is Some(_),
        if solutions is Some(_) {
          1
        } else {
          0
        },
        problem.stats(),
        1,
      )
    }
  }
}

///|
/// Run a grid coloring benchmark.
pub fn benchmark_coloring(rows : Int, columns : Int) -> BenchmarkResult {
  match grid_coloring(rows, columns, 3) {
    None => benchmark_result("grid_coloring", false, 0, empty_search_stats(), 1)
    Some(problem) => {
      let solutions = problem.solve_all(1)
      benchmark_result(
        "grid_coloring_\{rows}x\{columns}",
        solutions.length() > 0,
        solutions.length(),
        problem.stats(),
        1,
      )
    }
  }
}

///|
/// Run a small balanced-schedule benchmark.
pub fn benchmark_schedule() -> BenchmarkResult {
  match balanced_schedule(4, 4, 2) {
    None =>
      benchmark_result("schedule_4x4x2", false, 0, empty_search_stats(), 1)
    Some(problem) => {
      ignore(problem.avoid_same_shift(0))
      let solutions = problem.solve_all(1)
      benchmark_result(
        "schedule_4x4x2",
        solutions.length() > 0,
        solutions.length(),
        problem.stats(),
        1,
      )
    }
  }
}

///|
/// Run a small knapsack benchmark.
pub fn benchmark_knapsack() -> BenchmarkResult {
  match
    knapsack(
      ["camera", "tripod", "lens", "battery"],
      [4, 3, 2, 1],
      [9, 5, 7, 3],
      6,
    ) {
    None =>
      benchmark_result("knapsack_4_items", false, 0, empty_search_stats(), 1)
    Some(problem) => {
      let result = problem.solve()
      benchmark_result(
        "knapsack_4_items",
        result is Some(_),
        if result is Some(_) {
          1
        } else {
          0
        },
        problem.stats(),
        1,
      )
    }
  }
}

///|
/// Return the canonical benchmark set.
pub fn benchmark_suite() -> Array[BenchmarkResult] {
  [
    benchmark_n_queens(8),
    benchmark_sudoku(),
    benchmark_latin(4),
    benchmark_coloring(3, 3),
    benchmark_schedule(),
    benchmark_knapsack(),
  ]
}

///|
/// Render benchmark records as Markdown table rows.
pub fn benchmark_markdown(results : Array[BenchmarkResult]) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "| Case | Solved | Solutions | Nodes | Propagations | Checks | Pruned | Depth |\n",
  )
  builder.write_string(
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n",
  )
  for result in results {
    builder.write_string(
      "| \{result.name} | \{result.solved} | \{result.solutions} | \{result.nodes} | \{result.propagations} | \{result.checks} | \{result.pruned} | \{result.depth} |\n",
    )
  }
  builder.to_string()
}

///|
/// Render the suite as plain text for CI logs.
pub fn benchmark_report(results : Array[BenchmarkResult]) -> String {
  let builder = StringBuilder()
  for index, result in results {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(result.describe())
  }
  builder.to_string()
}

///|
/// Return whether every benchmark in a suite solved successfully.
pub fn benchmarks_pass(results : Array[BenchmarkResult]) -> Bool {
  for result in results {
    if !result.solved {
      return false
    }
  }
  true
}

///|
/// Return total deterministic work across a suite.
pub fn benchmark_work(results : Array[BenchmarkResult]) -> Int {
  results.fold(init=0, (total, result) => total + result.work())
}

///|
/// Return a stable fingerprint useful for regression tests.
pub fn benchmark_fingerprint(results : Array[BenchmarkResult]) -> String {
  let builder = StringBuilder()
  for result in results {
    builder.write_string("\{result.name}:\{result.nodes}:\{result.pruned};")
  }
  builder.to_string()
}
