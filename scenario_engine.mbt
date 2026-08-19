///|
/// Deterministic scenario generation for what-if model validation.
///
/// A scenario is a named vector of integer parameters. The engine supports
/// bounded Cartesian expansion, overrides, deltas, and reproducible scoring;
/// it is useful for capacity planning and regression matrices in CI.
pub struct ScenarioValue {
  name : String
  value : Int
}

///|
/// Create a named scenario value.
pub fn scenario_value(name : String, value : Int) -> ScenarioValue {
  { name, value }
}

///|
/// A named scenario.
pub struct WhatIfScenario {
  name : String
  values : Array[ScenarioValue]
}

///|
/// Create a scenario.
pub fn what_if_scenario(
  name : String,
  values : Array[ScenarioValue],
) -> WhatIfScenario {
  { name, values: values.copy() }
}

///|
/// Read a scenario parameter.
pub fn WhatIfScenario::get(self : WhatIfScenario, name : String) -> Int? {
  for value in self.values {
    if value.name == name {
      return Some(value.value)
    }
  }
  None
}

///|
/// Set or replace a scenario parameter.
pub fn WhatIfScenario::set(
  self : WhatIfScenario,
  name : String,
  value : Int,
) -> Bool {
  for index, current in self.values {
    if current.name == name {
      self.values[index] = scenario_value(name, value)
      return true
    }
  }
  self.values.push(scenario_value(name, value))
  true
}

///|
/// Return copied values.
pub fn WhatIfScenario::values(self : WhatIfScenario) -> Array[ScenarioValue] {
  self.values.copy()
}

///|
/// Return a scenario with a delta applied.
pub fn WhatIfScenario::delta(
  self : WhatIfScenario,
  name : String,
  amount : Int,
) -> WhatIfScenario {
  let result = what_if_scenario(self.name, self.values)
  match result.get(name) {
    Some(value) => ignore(result.set(name, value + amount))
    None => ignore(result.set(name, amount))
  }
  result
}

///|
/// Return a stable scenario key.
pub fn WhatIfScenario::signature(self : WhatIfScenario) -> Int {
  let mut result = 31
  for value in self.values {
    for character in value.name {
      result = result * 37 + character.to_int()
    }
    result = result * 41 + value.value
  }
  result
}

///|
/// A parameter axis for Cartesian scenario generation.
pub struct ScenarioAxis {
  name : String
  values : Array[Int]
}

///|
/// Create an axis.
pub fn scenario_axis(name : String, values : Array[Int]) -> ScenarioAxis {
  { name, values: values.copy() }
}

///|
/// Generate all combinations up to a hard limit.
pub fn scenario_product(
  axes : Array[ScenarioAxis],
  limit : Int,
) -> Array[WhatIfScenario] {
  let result : Array[WhatIfScenario] = []
  let cap = if limit < 1 { 1 } else { limit }
  scenario_product_rec(axes, 0, [], result, cap)
  result
}

///|
/// Cartesian expansion helper.
fn scenario_product_rec(
  axes : Array[ScenarioAxis],
  index : Int,
  values : Array[ScenarioValue],
  result : Array[WhatIfScenario],
  limit : Int,
) -> Unit {
  if result.length() >= limit {
    return
  }
  if index >= axes.length() {
    result.push(what_if_scenario("scenario_\{result.length()}", values))
    return
  }
  for value in axes[index].values {
    let next = values.copy()
    next.push(scenario_value(axes[index].name, value))
    scenario_product_rec(axes, index + 1, next, result, limit)
    if result.length() >= limit {
      return
    }
  }
}

///|
/// Return the number of combinations, capped at a limit.
pub fn scenario_product_size(axes : Array[ScenarioAxis], limit : Int) -> Int {
  let mut result = 1
  let cap = if limit < 1 { 1 } else { limit }
  for axis in axes {
    result *= axis.values.length()
    if result >= cap {
      return cap
    }
  }
  result
}

///|
/// A scenario evaluation.
pub struct ScenarioEvaluation {
  scenario : WhatIfScenario
  score : Int
  feasible : Bool
}

///|
/// Evaluate a scenario with a callback.
pub fn evaluate_scenario(
  scenario : WhatIfScenario,
  score : Int,
  feasible : Bool,
) -> ScenarioEvaluation {
  { scenario, score, feasible }
}

///|
/// Return whether evaluation is feasible.
pub fn ScenarioEvaluation::feasible(self : ScenarioEvaluation) -> Bool {
  self.feasible
}

///|
/// Return score.
pub fn ScenarioEvaluation::score(self : ScenarioEvaluation) -> Int {
  self.score
}

///|
/// Return scenario name.
pub fn ScenarioEvaluation::name(self : ScenarioEvaluation) -> String {
  self.scenario.name
}

///|
/// Select the best feasible evaluation.
pub fn best_scenario(
  evaluations : Array[ScenarioEvaluation],
  minimize : Bool,
) -> ScenarioEvaluation? {
  let mut result : ScenarioEvaluation? = None
  for evaluation in evaluations {
    if !evaluation.feasible {
      continue
    }
    match result {
      None => result = Some(evaluation)
      Some(current) => {
        let better = if minimize {
          evaluation.score < current.score
        } else {
          evaluation.score > current.score
        }
        if better {
          result = Some(evaluation)
        }
      }
    }
  }
  result
}

///|
/// Return the feasible evaluations ordered by score.
pub fn sort_scenario_evaluations(
  evaluations : Array[ScenarioEvaluation],
  minimize : Bool,
) -> Array[ScenarioEvaluation] {
  let result = evaluations.copy()
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      let better = if minimize {
        result[right].score < result[left].score
      } else {
        result[right].score > result[left].score
      }
      if better {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return the number of feasible evaluations.
pub fn feasible_scenario_count(evaluations : Array[ScenarioEvaluation]) -> Int {
  let mut result = 0
  for evaluation in evaluations {
    if evaluation.feasible {
      result += 1
    }
  }
  result
}

///|
/// Return score spread among evaluations.
pub fn scenario_score_spread(evaluations : Array[ScenarioEvaluation]) -> Int {
  if evaluations.length() == 0 {
    return 0
  }
  let mut low = evaluations[0].score
  let mut high = low
  for evaluation in evaluations {
    if evaluation.score < low {
      low = evaluation.score
    }
    if evaluation.score > high {
      high = evaluation.score
    }
  }
  high - low
}

///|
/// Return a stable evaluation fingerprint.
pub fn scenario_evaluation_signature(evaluation : ScenarioEvaluation) -> Int {
  evaluation.scenario.signature() * 37 +
  evaluation.score * 7 +
  (if evaluation.feasible { 1 } else { 0 })
}
