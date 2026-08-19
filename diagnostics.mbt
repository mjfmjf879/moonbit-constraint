///|
/// Classification of the supported constraint families.
pub enum ConstraintKind {
  BinaryConstraint
  GlobalConstraint
  ArithmeticConstraint
  ExtensionalConstraint
  SchedulingConstraint
} derive(Debug, Eq)

///|
/// Counted information about one constraint for diagnostics.
pub struct ConstraintInfo {
  kind : ConstraintKind
  arity : Int
  variables : Array[Int]
  label : String
}

///|
/// Return the semantic family of a constraint.
pub fn constraint_kind(constraint : Constraint) -> ConstraintKind {
  match constraint {
    Equal(_, _)
    | NotEqual(_, _)
    | LessThan(_, _)
    | LessEqual(_, _)
    | GreaterThan(_, _)
    | GreaterEqual(_, _)
    | Distance(_, _, _)
    | NotDistance(_, _, _) => BinaryConstraint
    AllDifferent(_)
    | CountValue(_, _, _)
    | AtMostValue(_, _, _)
    | AtLeastValue(_, _, _) => GlobalConstraint
    Sum(_, _)
    | Linear(_, _)
    | LinearLessEqual(_, _)
    | LinearGreaterEqual(_, _)
    | Between(_, _, _)
    | Minimum(_, _)
    | Maximum(_, _)
    | Absolute(_, _) => ArithmeticConstraint
    Element(_, _, _) | Member(_, _) | Table(_, _) => ExtensionalConstraint
    NoOverlap(_) | Cumulative(_, _) => SchedulingConstraint
  }
}

///|
/// Return all variable ids referenced by a constraint in stable order.
pub fn constraint_variables(constraint : Constraint) -> Array[Int] {
  match constraint {
    Equal(left, right)
    | NotEqual(left, right)
    | LessThan(left, right)
    | LessEqual(left, right)
    | GreaterThan(left, right)
    | GreaterEqual(left, right) => [left, right]
    AllDifferent(ids)
    | Sum(ids, _)
    | CountValue(ids, _, _)
    | AtMostValue(ids, _, _)
    | AtLeastValue(ids, _, _)
    | Minimum(ids, _)
    | Maximum(ids, _) => ids.copy()
    Element(index, _, result)
    | Distance(index, result, _)
    | NotDistance(index, result, _) => [index, result]
    Linear(terms, _)
    | LinearLessEqual(terms, _)
    | LinearGreaterEqual(terms, _) => {
      let result : Array[Int] = []
      for term in terms {
        let (id, _) = term
        result.push(id)
      }
      result
    }
    Between(id, _, _) | Member(id, _) | Absolute(id, _) => [id]
    Table(ids, _) => ids.copy()
    NoOverlap(tasks) => {
      let result : Array[Int] = []
      for task in tasks {
        let (id, _) = task
        result.push(id)
      }
      result
    }
    Cumulative(tasks, _) => {
      let result : Array[Int] = []
      for task in tasks {
        let (id, _, _) = task
        result.push(id)
      }
      result
    }
  }
}

///|
/// Return a stable public label for a constraint.
pub fn constraint_label(constraint : Constraint) -> String {
  match constraint {
    Equal(_, _) => "equal"
    NotEqual(_, _) => "not_equal"
    LessThan(_, _) => "less_than"
    LessEqual(_, _) => "less_equal"
    GreaterThan(_, _) => "greater_than"
    GreaterEqual(_, _) => "greater_equal"
    AllDifferent(_) => "all_different"
    Sum(_, _) => "sum"
    Element(_, _, _) => "element"
    Linear(_, _) => "linear"
    LinearLessEqual(_, _) => "linear_less_equal"
    LinearGreaterEqual(_, _) => "linear_greater_equal"
    Between(_, _, _) => "between"
    Member(_, _) => "allowed_values"
    CountValue(_, _, _) => "count_value"
    AtMostValue(_, _, _) => "at_most_value"
    AtLeastValue(_, _, _) => "at_least_value"
    Minimum(_, _) => "minimum"
    Maximum(_, _) => "maximum"
    Absolute(_, _) => "absolute"
    Distance(_, _, _) => "distance"
    NotDistance(_, _, _) => "not_distance"
    Table(_, _) => "table"
    NoOverlap(_) => "no_overlap"
    Cumulative(_, _) => "cumulative"
  }
}

///|
/// Build a structured diagnostic record.
pub fn constraint_info(constraint : Constraint) -> ConstraintInfo {
  let variables = constraint_variables(constraint)
  {
    kind: constraint_kind(constraint),
    arity: variables.length(),
    variables,
    label: constraint_label(constraint),
  }
}

///|
/// Read a diagnostic record's kind.
pub fn ConstraintInfo::kind(self : ConstraintInfo) -> ConstraintKind {
  self.kind
}

///|
/// Read a diagnostic record's arity.
pub fn ConstraintInfo::arity(self : ConstraintInfo) -> Int {
  self.arity
}

///|
/// Read a diagnostic record's variables.
pub fn ConstraintInfo::variables(self : ConstraintInfo) -> Array[Int] {
  self.variables.copy()
}

///|
/// Read a diagnostic record's label.
pub fn ConstraintInfo::label(self : ConstraintInfo) -> String {
  self.label
}

///|
/// Render a constraint diagnostic in one line.
pub fn ConstraintInfo::describe(self : ConstraintInfo) -> String {
  "\{self.label}(arity=\{self.arity}, variables=\{Repr(self.variables)})"
}

///|
/// Verify a complete solution against variable domains and constraints.
pub fn Solver::is_valid_solution(self : Solver, solution : Solution) -> Bool {
  if solution.values.length() != self.variables.length() {
    return false
  }
  for id, variable in self.variables {
    if !variable.domain.contains(solution.values[id]) {
      return false
    }
  }
  let values : Array[Int?] = solution.values.map(value => Some(value))
  for constraint in self.constraints {
    if !check_constraint(constraint, values) {
      return false
    }
  }
  true
}

///|
/// Return labels for every constraint violated by a complete solution.
pub fn Solver::violations(self : Solver, solution : Solution) -> Array[String] {
  let result : Array[String] = []
  if solution.values.length() != self.variables.length() {
    result.push("solution_arity")
    return result
  }
  for id, variable in self.variables {
    if !variable.domain.contains(solution.values[id]) {
      result.push("domain[\{id}]")
    }
  }
  let values : Array[Int?] = solution.values.map(value => Some(value))
  for constraint in self.constraints {
    if !check_constraint(constraint, values) {
      result.push(constraint_label(constraint))
    }
  }
  result
}

///|
/// Return one diagnostic line for each posted constraint.
pub fn Solver::constraint_report(self : Solver) -> Array[ConstraintInfo] {
  self.constraints.map(constraint => constraint_info(constraint))
}

///|
/// Count constraints by semantic family.
pub fn Solver::constraint_kind_counts(self : Solver) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for constraint in self.constraints {
    let label = match constraint_kind(constraint) {
      BinaryConstraint => "binary"
      GlobalConstraint => "global"
      ArithmeticConstraint => "arithmetic"
      ExtensionalConstraint => "extensional"
      SchedulingConstraint => "scheduling"
    }
    counts.update_or_default(label, 1, value => value + 1)
  }
  counts
}

///|
/// Produce a complete model report suitable for a CLI or issue template.
pub fn Solver::diagnostic_report(self : Solver) -> String {
  let builder = StringBuilder()
  builder.write_string("model\n")
  builder.write_string(self.summary())
  builder.write_string("\nconstraints\n")
  for index, info in self.constraint_report() {
    builder.write_string("  [\{index}] \{info.describe()}\n")
  }
  builder.write_string("kinds=\{Repr(self.constraint_kind_counts())}")
  builder.to_string()
}

///|
/// Return a compact domain histogram for model review.
pub fn Solver::domain_histogram(self : Solver) -> Map[Int, Int] {
  let histogram : Map[Int, Int] = Map([])
  for variable in self.variables {
    let size = variable.domain.size()
    histogram.update_or_default(size, 1, count => count + 1)
  }
  histogram
}

///|
/// Return whether every variable has at least one candidate.
pub fn Solver::has_nonempty_domains(self : Solver) -> Bool {
  for variable in self.variables {
    if variable.domain.is_empty() {
      return false
    }
  }
  true
}

///|
/// Validate the model's static shape without running search.
pub fn Solver::validate(self : Solver) -> Bool {
  if !self.has_nonempty_domains() {
    return false
  }
  for constraint in self.constraints {
    for id in constraint_variables(constraint) {
      if id < 0 || id >= self.variables.length() {
        return false
      }
    }
  }
  true
}

///|
/// Add a pairwise inequality chain to a model.
pub fn post_chain_not_equal(solver : Solver, variables : Array[Int]) -> Unit {
  if variables.length() < 2 {
    return
  }
  for index in 0..<(variables.length() - 1) {
    solver.add_constraint(not_equal(variables[index], variables[index + 1]))
  }
}

///|
/// Add all pairwise inequality constraints for small models.
pub fn post_pairwise_different(solver : Solver, variables : Array[Int]) -> Unit {
  for left in 0..<variables.length() {
    for right in (left + 1)..<variables.length() {
      solver.add_constraint(not_equal(variables[left], variables[right]))
    }
  }
}

///|
/// Add a sequence of fixed assignments to a model.
pub fn post_assignments(
  solver : Solver,
  variables : Array[Int],
  values : Array[Int],
) -> Bool {
  if variables.length() != values.length() {
    return false
  }
  for index in 0..<variables.length() {
    if !solver.assign(variables[index], values[index]) {
      return false
    }
  }
  true
}

///|
/// Return a stable textual statistic for a model's structure.
pub fn Solver::structural_fingerprint(self : Solver) -> String {
  let builder = StringBuilder()
  builder.write_string("v\{self.variable_count()}-c\{self.constraint_count()}")
  for constraint in self.constraints {
    builder.write_char('|')
    builder.write_string(constraint_label(constraint))
    builder.write_char(':')
    builder.write_string("\{constraint_variables(constraint).length()}")
  }
  builder.to_string()
}
