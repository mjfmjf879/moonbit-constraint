///|
/// Return a solution as a copied integer array.
pub fn solution_values(solution : Solution) -> Array[Int] {
  solution.values.copy()
}

///|
/// Compare two solutions by all variable values.
pub fn solutions_equal(left : Solution, right : Solution) -> Bool {
  if left.values.length() != right.values.length() {
    return false
  }
  for index in 0..<left.values.length() {
    if left.values[index] != right.values[index] {
      return false
    }
  }
  true
}

///|
/// Count positions that differ between two solutions.
pub fn solution_distance(left : Solution, right : Solution) -> Int {
  let limit = if left.values.length() < right.values.length() {
    left.values.length()
  } else {
    right.values.length()
  }
  let mut distance = if left.values.length() == right.values.length() {
    0
  } else {
    1
  }
  for index in 0..<limit {
    if left.values[index] != right.values[index] {
      distance += 1
    }
  }
  distance
}

///|
/// A named difference between two complete assignments.
pub struct SolutionDelta {
  variable : Int
  before : Int
  after : Int
}

///|
/// Return all changed positions between two solutions.
pub fn solution_delta(
  left : Solution,
  right : Solution,
) -> Array[SolutionDelta] {
  let result : Array[SolutionDelta] = []
  let limit = if left.values.length() < right.values.length() {
    left.values.length()
  } else {
    right.values.length()
  }
  for index in 0..<limit {
    if left.values[index] != right.values[index] {
      result.push({
        variable: index,
        before: left.values[index],
        after: right.values[index],
      })
    }
  }
  result
}

///|
/// Return a readable delta line.
pub fn SolutionDelta::describe(self : SolutionDelta) -> String {
  "v\{self.variable}: \{self.before} -> \{self.after}"
}

///|
/// Read a delta variable id.
pub fn SolutionDelta::variable(self : SolutionDelta) -> Int {
  self.variable
}

///|
/// Read a delta's old value.
pub fn SolutionDelta::before(self : SolutionDelta) -> Int {
  self.before
}

///|
/// Read a delta's new value.
pub fn SolutionDelta::after(self : SolutionDelta) -> Int {
  self.after
}

///|
/// Render a solution as comma-separated values.
pub fn Solution::csv(self : Solution) -> String {
  let builder = StringBuilder()
  for index, value in self.values {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string("\{value}")
  }
  builder.to_string()
}

///|
/// Render a set of solutions as newline-separated CSV.
pub fn solutions_csv(solutions : Array[Solution]) -> String {
  let builder = StringBuilder()
  for index, solution in solutions {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(solution.csv())
  }
  builder.to_string()
}

///|
/// Render all variable names as a CSV header.
pub fn Solver::csv_header(self : Solver) -> String {
  let builder = StringBuilder()
  for index, variable in self.variables {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string(variable.name)
  }
  builder.to_string()
}

///|
/// Render a named solution as a two-line CSV document.
pub fn Solver::solution_csv(self : Solver, solution : Solution) -> String {
  self.csv_header() + "\n" + solution.csv()
}

///|
/// Parse a comma-separated integer list.
pub fn parse_integer_list(input : String) -> Array[Int]? {
  let result : Array[Int] = []
  let mut current = ""
  let flush = () => {
    if current != "" {
      match parse_small_int(current) {
        Some(value) => result.push(value)
        None => return false
      }
      current = ""
    }
    true
  }
  for character in input {
    if character == ',' || character.is_whitespace() {
      if !flush() {
        return None
      }
    } else {
      current += character.to_string()
    }
  }
  if !flush() {
    return None
  }
  Some(result)
}

///|
/// Parse a small signed decimal integer without a dependency on IO packages.
fn parse_small_int(input : String) -> Int? {
  if input == "" {
    return None
  }
  let mut sign = 1
  let mut start = 0
  if input.get_char(0) is Some('-') {
    sign = -1
    start = 1
  }
  let mut result = 0
  let mut seen = false
  for index in start..<input.length() {
    match input.get_char(index) {
      Some(character) => {
        if character < '0' || character > '9' {
          return None
        }
        result = result * 10 + character.to_int() - '0'.to_int()
        seen = true
      }
      None => return None
    }
  }
  if seen {
    Some(result * sign)
  } else {
    None
  }
}

///|
/// Parse a finite domain from a comma-separated integer list.
pub fn parse_domain(input : String) -> Domain? {
  match parse_integer_list(input) {
    Some(values) =>
      if values.length() == 0 {
        None
      } else {
        Some(domain_from_values(values))
      }
    None => None
  }
}

///|
/// Render domain intervals as a machine-readable string.
pub fn domain_csv(domain : Domain) -> String {
  let builder = StringBuilder()
  for index, interval in domain.intervals() {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string(interval.describe())
  }
  builder.to_string()
}

///|
/// Render a solver's structural report as CSV-like rows.
pub fn Solver::constraint_csv(self : Solver) -> String {
  let builder = StringBuilder()
  builder.write_string("index,label,arity,variables\n")
  for index, info in self.constraint_report() {
    builder.write_string(
      "\{index},\{info.label()},\{info.arity()},\{Repr(info.variables())}\n",
    )
  }
  builder.to_string()
}

///|
/// Return a copy of all current variable domains.
pub fn Solver::domains(self : Solver) -> Array[Domain] {
  self.variables.map(variable => variable.domain.clone())
}

///|
/// Return a compact domain report.
pub fn Solver::domain_csv(self : Solver) -> String {
  let builder = StringBuilder()
  for index, variable in self.variables {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string("\{variable.name},\{domain_csv(variable.domain)}")
  }
  builder.to_string()
}

///|
/// Return a solution delta report.
pub fn solution_delta_report(left : Solution, right : Solution) -> String {
  let builder = StringBuilder()
  for index, delta in solution_delta(left, right) {
    if index > 0 {
      builder.write_string(", ")
    }
    builder.write_string(delta.describe())
  }
  builder.to_string()
}
