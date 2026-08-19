///|
/// Post a finite addition relation `result = left + right`.
pub fn post_addition(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([a, b, a + b])
    }
  }
  solver.add_constraint(table([left, right, result], rows))
}

///|
/// Post a finite subtraction relation `result = left - right`.
pub fn post_subtraction(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([a, b, a - b])
    }
  }
  solver.add_constraint(table([left, right, result], rows))
}

///|
/// Post a finite product relation.
pub fn post_product(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([a, b, a * b])
    }
  }
  solver.add_constraint(table([left, right, result], rows))
}

///|
/// Post an absolute-value relation.
pub fn post_absolute_table(
  solver : Solver,
  source : Int,
  result : Int,
  source_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for value in source_domain.values() {
    let absolute = if value < 0 { -value } else { value }
    rows.push([value, absolute])
  }
  solver.add_constraint(table([source, result], rows))
}

///|
/// Post a minimum relation for two input variables.
pub fn post_minimum_table(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([a, b, if a < b { a } else { b }])
    }
  }
  solver.add_constraint(table([left, right, result], rows))
}

///|
/// Post a maximum relation for two input variables.
pub fn post_maximum_table(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([a, b, if a > b { a } else { b }])
    }
  }
  solver.add_constraint(table([left, right, result], rows))
}

///|
/// Post a modulo relation for a positive divisor.
pub fn post_modulo_table(
  solver : Solver,
  dividend : Int,
  divisor : Int,
  result : Int,
  dividend_domain : Domain,
  divisor_domain : Domain,
) -> Bool {
  if divisor_domain.values().contains(0) {
    return false
  }
  let rows : Array[Array[Int]] = []
  for value in dividend_domain.values() {
    for divisor_value in divisor_domain.values() {
      rows.push([value, divisor_value, value % divisor_value])
    }
  }
  solver.add_constraint(table([dividend, divisor, result], rows))
  true
}

///|
/// Post an integer division relation for a non-zero divisor.
pub fn post_division_table(
  solver : Solver,
  dividend : Int,
  divisor : Int,
  result : Int,
  dividend_domain : Domain,
  divisor_domain : Domain,
) -> Bool {
  if divisor_domain.values().contains(0) {
    return false
  }
  let rows : Array[Array[Int]] = []
  for value in dividend_domain.values() {
    for divisor_value in divisor_domain.values() {
      rows.push([value, divisor_value, value / divisor_value])
    }
  }
  solver.add_constraint(table([dividend, divisor, result], rows))
  true
}

///|
/// Post a reified equality: `indicator=1` iff `left=right`.
pub fn post_reified_equal(
  solver : Solver,
  indicator : Int,
  left : Int,
  right : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([if a == b { 1 } else { 0 }, a, b])
    }
  }
  solver.add_constraint(table([indicator, left, right], rows))
}

///|
/// Post a reified ordering: `indicator=1` iff `left<right`.
pub fn post_reified_less_than(
  solver : Solver,
  indicator : Int,
  left : Int,
  right : Int,
  left_domain : Domain,
  right_domain : Domain,
) -> Unit {
  let rows : Array[Array[Int]] = []
  for a in left_domain.values() {
    for b in right_domain.values() {
      rows.push([if a < b { 1 } else { 0 }, a, b])
    }
  }
  solver.add_constraint(table([indicator, left, right], rows))
}

///|
/// Build a Cartesian arithmetic table for a custom pure function.
pub fn arithmetic_relation(
  left_domain : Domain,
  right_domain : Domain,
  operation : (Int, Int) -> Int,
) -> RelationTable? {
  let rows : Array[Array[Int]] = []
  for left in left_domain.values() {
    for right in right_domain.values() {
      rows.push([left, right, operation(left, right)])
    }
  }
  relation_table(rows)
}

///|
/// Post a finite custom arithmetic relation.
pub fn post_arithmetic_relation(
  solver : Solver,
  left : Int,
  right : Int,
  result : Int,
  left_domain : Domain,
  right_domain : Domain,
  operation : (Int, Int) -> Int,
) -> Bool {
  match arithmetic_relation(left_domain, right_domain, operation) {
    Some(relation) => relation.post(solver, [left, right, result])
    None => false
  }
}

///|
/// Return a finite domain containing all results of a binary operation.
pub fn arithmetic_result_domain(
  left : Domain,
  right : Domain,
  operation : (Int, Int) -> Int,
) -> Domain? {
  match arithmetic_relation(left, right, operation) {
    None => None
    Some(relation) => {
      let values : Array[Int] = []
      for row in relation.rows() {
        if !values.contains(row[2]) {
          values.push(row[2])
        }
      }
      if values.length() == 0 {
        None
      } else {
        Some(domain_from_values(values))
      }
    }
  }
}

///|
/// Return all finite pairs that satisfy a predicate.
pub fn relation_pairs(
  left : Domain,
  right : Domain,
  predicate : (Int, Int) -> Bool,
) -> Array[Array[Int]] {
  let rows : Array[Array[Int]] = []
  for a in left.values() {
    for b in right.values() {
      if predicate(a, b) {
        rows.push([a, b])
      }
    }
  }
  rows
}

///|
/// Post any binary finite relation supplied by the caller.
pub fn post_relation_pairs(
  solver : Solver,
  left : Int,
  right : Int,
  left_domain : Domain,
  right_domain : Domain,
  predicate : (Int, Int) -> Bool,
) -> Bool {
  let rows = relation_pairs(left_domain, right_domain, predicate)
  match relation_table(rows) {
    Some(relation) => relation.post(solver, [left, right])
    None => false
  }
}
