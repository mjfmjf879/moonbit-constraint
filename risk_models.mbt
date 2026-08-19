///|
/// Integer risk and sensitivity models for planning decisions.
///
/// Risk scores are explicit integer products of likelihood and impact. The
/// model is small enough for CI scenario checks and structured enough to feed
/// objective terms or an acceptance report.
pub enum RiskBand {
  LowRisk
  MediumRisk
  HighRisk
  CriticalRisk
}

///|
/// A risk item.
pub struct RiskItem {
  id : Int
  name : String
  likelihood : Int
  impact : Int
  mitigation : Int
}

///|
/// Create a risk item with values in 0..100.
pub fn risk_item(
  id : Int,
  name : String,
  likelihood : Int,
  impact : Int,
  mitigation : Int,
) -> RiskItem {
  {
    id,
    name,
    likelihood: risk_clamp(likelihood),
    impact: risk_clamp(impact),
    mitigation: risk_clamp(mitigation),
  }
}

///|
/// Clamp a risk percentage.
fn risk_clamp(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 100 {
    100
  } else {
    value
  }
}

///|
/// Return gross risk score.
pub fn RiskItem::gross_score(self : RiskItem) -> Int {
  self.likelihood * self.impact / 100
}

///|
/// Return residual risk after mitigation.
pub fn RiskItem::residual_score(self : RiskItem) -> Int {
  self.gross_score() * (100 - self.mitigation) / 100
}

///|
/// Classify a score.
pub fn risk_band(score : Int) -> RiskBand {
  if score >= 75 {
    CriticalRisk
  } else if score >= 50 {
    HighRisk
  } else if score >= 25 {
    MediumRisk
  } else {
    LowRisk
  }
}

///|
/// Return a stable band label.
pub fn risk_band_name(band : RiskBand) -> String {
  match band {
    LowRisk => "low"
    MediumRisk => "medium"
    HighRisk => "high"
    CriticalRisk => "critical"
  }
}

///|
/// A scenario with risk items and a resource budget.
pub struct RiskScenario {
  items : Array[RiskItem]
  budget : Int
}

///|
/// Create a risk scenario.
pub fn risk_scenario(items : Array[RiskItem], budget : Int) -> RiskScenario {
  { items: items.copy(), budget: if budget < 0 { 0 } else { budget } }
}

///|
/// Return total gross risk.
pub fn RiskScenario::gross_score(self : RiskScenario) -> Int {
  let mut result = 0
  for item in self.items {
    result += item.gross_score()
  }
  result
}

///|
/// Return total residual risk.
pub fn RiskScenario::residual_score(self : RiskScenario) -> Int {
  let mut result = 0
  for item in self.items {
    result += item.residual_score()
  }
  result
}

///|
/// Return highest residual risk.
pub fn RiskScenario::maximum_residual(self : RiskScenario) -> Int {
  let mut result = 0
  for item in self.items {
    if item.residual_score() > result {
      result = item.residual_score()
    }
  }
  result
}

///|
/// Return items above a threshold.
pub fn RiskScenario::above(self : RiskScenario, threshold : Int) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.items {
    if item.residual_score() >= threshold {
      result.push(item.id)
    }
  }
  result
}

///|
/// Return a priority order by residual risk.
pub fn RiskScenario::priority_order(self : RiskScenario) -> Array[Int] {
  let result : Array[Int] = []
  for item in self.items {
    result.push(item.id)
  }
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if self.items[result[right]].residual_score() >
        self.items[result[left]].residual_score() {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return the band distribution.
pub fn RiskScenario::band_counts(self : RiskScenario) -> Array[Int] {
  let result : Array[Int] = [0, 0, 0, 0]
  for item in self.items {
    match risk_band(item.residual_score()) {
      LowRisk => result[0] += 1
      MediumRisk => result[1] += 1
      HighRisk => result[2] += 1
      CriticalRisk => result[3] += 1
    }
  }
  result
}

///|
/// Apply extra mitigation to one item.
pub fn RiskScenario::mitigate(
  self : RiskScenario,
  id : Int,
  amount : Int,
) -> Bool {
  for index, item in self.items {
    if item.id == id {
      self.items[index] = {
        ..item,
        mitigation: risk_clamp(item.mitigation + amount),
      }
      return true
    }
  }
  false
}

///|
/// Return marginal score reduction for mitigation.
pub fn RiskScenario::mitigation_value(
  self : RiskScenario,
  id : Int,
  amount : Int,
) -> Int {
  for item in self.items {
    if item.id == id {
      let before = item.residual_score()
      let after = { ..item, mitigation: risk_clamp(item.mitigation + amount) }.residual_score()
      return before - after
    }
  }
  0
}

///|
/// Return a stable scenario summary.
pub fn RiskScenario::describe(self : RiskScenario) -> String {
  "items=\{self.items.length()}, gross=\{self.gross_score()}, residual=\{self.residual_score()}, max=\{self.maximum_residual()}"
}

///|
/// Return a scenario fingerprint.
pub fn RiskScenario::signature(self : RiskScenario) -> Int {
  let mut result = self.budget * 31
  for item in self.items {
    result = result * 37 +
      item.id * 3 +
      item.likelihood * 5 +
      item.impact * 7 +
      item.mitigation
  }
  result
}

///|
/// Return sensitivity of residual risk to a likelihood change.
pub fn risk_sensitivity(item : RiskItem, likelihood_delta : Int) -> Int {
  let before = item.residual_score()
  let after = {
    ..item,
    likelihood: risk_clamp(item.likelihood + likelihood_delta),
  }.residual_score()
  after - before
}

///|
/// Return whether residual risk meets a target.
pub fn risk_meets_target(item : RiskItem, target : Int) -> Bool {
  item.residual_score() <= target
}

///|
/// Return the risk-weighted mitigation priority.
pub fn risk_priority(item : RiskItem) -> Int {
  item.residual_score() * (100 - item.mitigation)
}
