///|
/// A finite-domain constraint model.
pub struct Solver {
  variables : Array[Variable]
  constraints : Array[Constraint]
  mut max_solutions : Int
}

///|
/// Create an empty solver model.
pub fn new_solver() -> Solver {
  { variables: [], constraints: [], max_solutions: 1 }
}

///|
/// Add a variable and return its zero-based identifier.
pub fn Solver::add_variable(self : Solver, variable : Variable) -> Int {
  let id = self.variables.length()
  self.variables.push(variable)
  id
}

///|
/// Add a constraint to the model.
pub fn Solver::add_constraint(self : Solver, constraint : Constraint) -> Unit {
  self.constraints.push(constraint)
}

///|
/// Set the maximum number of solutions collected by `solve_all`.
pub fn Solver::limit(self : Solver, count : Int) -> Unit {
  self.max_solutions = if count < 1 { 1 } else { count }
}

///|
fn check_constraint(constraint : Constraint, values : Array[Int?]) -> Bool {
  match constraint {
    Equal(a, b) =>
      match (values[a], values[b]) {
        (Some(x), Some(y)) => x == y
        _ => true
      }
    NotEqual(a, b) =>
      match (values[a], values[b]) {
        (Some(x), Some(y)) => x != y
        _ => true
      }
    LessThan(a, b) =>
      match (values[a], values[b]) {
        (Some(x), Some(y)) => x < y
        _ => true
      }
    LessEqual(a, b) =>
      match (values[a], values[b]) {
        (Some(x), Some(y)) => x <= y
        _ => true
      }
    GreaterThan(a, b) =>
      match (values[a], values[b]) {
        (Some(x), Some(y)) => x > y
        _ => true
      }
    GreaterEqual(a, b) =>
      match (values[a], values[b]) {
        (Some(x), Some(y)) => x >= y
        _ => true
      }
    AllDifferent(ids) => {
      let seen = Set([])
      for id in ids {
        match values[id] {
          Some(value) =>
            if seen.contains(value) {
              return false
            } else {
              seen.add(value)
            }
          None => ()
        }
      }
      true
    }
    Sum(ids, target) => {
      let mut total = 0
      let mut complete = true
      for id in ids {
        match values[id] {
          Some(value) => total += value
          None => complete = false
        }
      }
      !complete || total == target
    }
    Element(index, table, result) =>
      match (values[index], values[result]) {
        (Some(i), Some(value)) =>
          i >= 0 && i < table.length() && table[i] == value
        _ => true
      }
  }
}

///|
fn relation_possible(
  constraint : Constraint,
  left_domain : Domain,
  right_domain : Domain,
  left : Int?,
  right : Int?,
) -> Bool {
  let left_values : Array[Int] = match left {
    Some(value) => [value]
    None => left_domain.values()
  }
  let right_values : Array[Int] = match right {
    Some(value) => [value]
    None => right_domain.values()
  }
  for a in left_values {
    for b in right_values {
      let holds = match constraint {
        Equal(_, _) => a == b
        NotEqual(_, _) => a != b
        LessThan(_, _) => a < b
        LessEqual(_, _) => a <= b
        GreaterThan(_, _) => a > b
        GreaterEqual(_, _) => a >= b
        _ => true
      }
      if holds {
        return true
      }
    }
  }
  false
}

///|
/// Forward-check domains before descending into the search tree.
fn Solver::possible(
  self : Solver,
  constraint : Constraint,
  values : Array[Int?],
) -> Bool {
  match constraint {
    Equal(a, b) =>
      relation_possible(
        constraint,
        self.variables[a].domain,
        self.variables[b].domain,
        values[a],
        values[b],
      )
    NotEqual(a, b) =>
      relation_possible(
        constraint,
        self.variables[a].domain,
        self.variables[b].domain,
        values[a],
        values[b],
      )
    LessThan(a, b) =>
      relation_possible(
        constraint,
        self.variables[a].domain,
        self.variables[b].domain,
        values[a],
        values[b],
      )
    LessEqual(a, b) =>
      relation_possible(
        constraint,
        self.variables[a].domain,
        self.variables[b].domain,
        values[a],
        values[b],
      )
    GreaterThan(a, b) =>
      relation_possible(
        constraint,
        self.variables[a].domain,
        self.variables[b].domain,
        values[a],
        values[b],
      )
    GreaterEqual(a, b) =>
      relation_possible(
        constraint,
        self.variables[a].domain,
        self.variables[b].domain,
        values[a],
        values[b],
      )
    AllDifferent(_) => true
    Sum(ids, target) => {
      let mut minimum = 0
      let mut maximum = 0
      for id in ids {
        match values[id] {
          Some(value) => {
            minimum += value
            maximum += value
          }
          None =>
            match
              (self.variables[id].domain.min(), self.variables[id].domain.max()) {
              (Some(low), Some(high)) => {
                minimum += low
                maximum += high
              }
              _ => return false
            }
        }
      }
      target >= minimum && target <= maximum
    }
    Element(index, table, result) => {
      let indices : Array[Int] = match values[index] {
        Some(value) => [value]
        None => self.variables[index].domain.values()
      }
      for position in indices {
        if position >= 0 && position < table.length() {
          let candidate = table[position]
          if values[result] is None ||
            self.variables[result].domain.contains(candidate) {
            return true
          }
        }
      }
      false
    }
  }
}

///|
fn Solver::consistent(self : Solver, values : Array[Int?]) -> Bool {
  for constraint in self.constraints {
    if !check_constraint(constraint, values) ||
      !self.possible(constraint, values) {
      return false
    }
  }
  true
}

///|
fn Solver::choose_variable(self : Solver, values : Array[Int?]) -> Int? {
  let mut selected : Int? = None
  let mut selected_size = 2147483647
  for id, variable in self.variables {
    if values[id] is None {
      let size = variable.domain.size()
      if size < selected_size {
        selected = Some(id)
        selected_size = size
      }
    }
  }
  selected
}

///|
fn Solver::search(
  self : Solver,
  values : Array[Int?],
  output : Array[Solution],
) -> Unit {
  if output.length() >= self.max_solutions || !self.consistent(values) {
    return
  }
  match self.choose_variable(values) {
    None => {
      let result = values.map(v => {
        match v {
          Some(x) => x
          None => 0
        }
      })
      output.push({ values: result })
    }
    Some(id) =>
      for candidate in self.variables[id].domain.values() {
        if output.length() >= self.max_solutions {
          break
        }
        values[id] = Some(candidate)
        self.search(values, output)
        values[id] = None
      }
  }
}

///|
/// Find up to the configured number of solutions using MRV branching.
pub fn Solver::solve_all(self : Solver) -> Array[Solution] {
  let values : Array[Int?] = Array::make(self.variables.length(), None)
  let output = []
  self.search(values, output)
  output
}

///|
/// Find one solution, if the model is satisfiable.
pub fn Solver::solve(self : Solver) -> Solution? {
  self.limit(1)
  let solutions = self.solve_all()
  solutions.get(0)
}
