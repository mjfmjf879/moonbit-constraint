///|
/// Boolean relation helpers built on extensional finite-domain tables.
pub fn boolean_domain() -> Domain {
  domain(0, 1)
}

///|
/// Create a Boolean variable.
pub fn boolean_variable(solver : Solver, name : String) -> Int {
  solver.add_variable(variable(name, 0, 1))
}

///|
/// Post a unary Boolean negation relation: `result = !input`.
pub fn post_boolean_not(solver : Solver, input : Int, result : Int) -> Unit {
  solver.add_constraint(table([input, result], [[0, 1], [1, 0]]))
}

///|
/// Post Boolean conjunction.
pub fn post_boolean_and(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
) -> Unit {
  solver.add_constraint(
    table([left, right, result], [[0, 0, 0], [0, 1, 0], [1, 0, 0], [1, 1, 1]]),
  )
}

///|
/// Post Boolean disjunction.
pub fn post_boolean_or(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
) -> Unit {
  solver.add_constraint(
    table([left, right, result], [[0, 0, 0], [0, 1, 1], [1, 0, 1], [1, 1, 1]]),
  )
}

///|
/// Post exclusive-or.
pub fn post_boolean_xor(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
) -> Unit {
  solver.add_constraint(
    table([left, right, result], [[0, 0, 0], [0, 1, 1], [1, 0, 1], [1, 1, 0]]),
  )
}

///|
/// Post implication `left -> right`.
pub fn post_boolean_implies(solver : Solver, left : Int, right : Int) -> Unit {
  solver.add_constraint(table([left, right], [[0, 0], [0, 1], [1, 1]]))
}

///|
/// Post Boolean equivalence.
pub fn post_boolean_equivalent(
  solver : Solver,
  left : Int,
  right : Int,
) -> Unit {
  solver.add_constraint(table([left, right], [[0, 0], [1, 1]]))
}

///|
/// Post a disjunctive clause over positive or negative literals.
/// A literal is encoded as `(variable, polarity)`, where polarity `true`
/// means the variable itself and `false` means its negation.
pub fn post_clause(solver : Solver, literals : Array[(Int, Bool)]) -> Bool {
  if literals.length() == 0 {
    return false
  }
  let rows : Array[Array[Int]] = []
  let combinations = 1 << literals.length()
  for mask in 0..<combinations {
    let row : Array[Int] = []
    let mut satisfied = false
    for index, literal in literals {
      let (variable, polarity) = literal
      let bit = (mask >> index) & 1
      row.push(bit)
      if (polarity && bit == 1) || (!polarity && bit == 0) {
        satisfied = true
      }
      ignore(variable)
    }
    if satisfied {
      rows.push(row)
    }
  }
  solver.add_constraint(
    table(
      literals.map(literal => {
        let (variable, _) = literal
        variable
      }),
      rows,
    ),
  )
  true
}

///|
/// A small Boolean circuit builder that exposes intermediate variables.
pub struct BooleanCircuit {
  solver : Solver
  outputs : Array[Int]
}

///|
/// Create a Boolean circuit.
pub fn boolean_circuit() -> BooleanCircuit {
  { solver: new_solver(), outputs: [] }
}

///|
/// Add a named input to a circuit.
pub fn BooleanCircuit::input(self : BooleanCircuit, name : String) -> Int {
  self.solver.add_variable(variable(name, 0, 1))
}

///|
/// Add a constant Boolean variable.
pub fn BooleanCircuit::constant(
  self : BooleanCircuit,
  name : String,
  value : Int,
) -> Int {
  if value < 0 || value > 1 {
    abort("Boolean constants must be zero or one")
  }
  let id = self.solver.add_variable(variable(name, value, value))
  id
}

///|
/// Add an AND gate and return its result variable.
pub fn BooleanCircuit::and_gate(
  self : BooleanCircuit,
  left : Int,
  right : Int,
) -> Int {
  let result = self.solver.add_variable(
    variable("and_\{self.outputs.length()}", 0, 1),
  )
  post_boolean_and(self.solver, left, right, result)
  self.outputs.push(result)
  result
}

///|
/// Add an OR gate.
pub fn BooleanCircuit::or_gate(
  self : BooleanCircuit,
  left : Int,
  right : Int,
) -> Int {
  let result = self.solver.add_variable(
    variable("or_\{self.outputs.length()}", 0, 1),
  )
  post_boolean_or(self.solver, left, right, result)
  self.outputs.push(result)
  result
}

///|
/// Add an XOR gate.
pub fn BooleanCircuit::xor_gate(
  self : BooleanCircuit,
  left : Int,
  right : Int,
) -> Int {
  let result = self.solver.add_variable(
    variable("xor_\{self.outputs.length()}", 0, 1),
  )
  post_boolean_xor(self.solver, left, right, result)
  self.outputs.push(result)
  result
}

///|
/// Add a NOT gate.
pub fn BooleanCircuit::not_gate(self : BooleanCircuit, input : Int) -> Int {
  let result = self.solver.add_variable(
    variable("not_\{self.outputs.length()}", 0, 1),
  )
  post_boolean_not(self.solver, input, result)
  self.outputs.push(result)
  result
}

///|
/// Solve the circuit.
pub fn BooleanCircuit::solve(self : BooleanCircuit) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate circuit assignments.
pub fn BooleanCircuit::solve_all(
  self : BooleanCircuit,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return the circuit solver.
pub fn BooleanCircuit::solver(self : BooleanCircuit) -> Solver {
  self.solver
}

///|
/// Return circuit output identifiers.
pub fn BooleanCircuit::outputs(self : BooleanCircuit) -> Array[Int] {
  self.outputs.copy()
}

///|
/// Return output values from a solution.
pub fn BooleanCircuit::output_values(
  self : BooleanCircuit,
  solution : Solution,
) -> Array[Int] {
  self.outputs.map(id => solution.get(id))
}

///|
/// Return a Boolean truth table for a binary operation.
pub fn boolean_truth_table(operation : String) -> Array[Array[Int]]? {
  match operation {
    "and" => Some([[0, 0, 0], [0, 1, 0], [1, 0, 0], [1, 1, 1]])
    "or" => Some([[0, 0, 0], [0, 1, 1], [1, 0, 1], [1, 1, 1]])
    "xor" => Some([[0, 0, 0], [0, 1, 1], [1, 0, 1], [1, 1, 0]])
    _ => None
  }
}
