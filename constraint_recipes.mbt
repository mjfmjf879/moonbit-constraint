///|
/// Constraint recipes for common operational rules.
pub struct RecipeResult {
  mut posted : Int
  mut rejected : Int
}

///|
/// Create an empty recipe result.
pub fn recipe_result() -> RecipeResult {
  { posted: 0, rejected: 0 }
}

///|
pub fn RecipeResult::posted(self : RecipeResult) -> Int {
  self.posted
}

///|
pub fn RecipeResult::rejected(self : RecipeResult) -> Int {
  self.rejected
}

///|
pub fn RecipeResult::ok(self : RecipeResult) -> Bool {
  self.rejected == 0
}

///|
pub fn RecipeResult::describe(self : RecipeResult) -> String {
  "posted=\{self.posted}, rejected=\{self.rejected}"
}

///|
/// A reusable recipe object.
pub struct ConstraintRecipe {
  builder : ConstraintBuilder
  result : RecipeResult
}

///|
/// Create a recipe around a builder.
pub fn constraint_recipe(builder : ConstraintBuilder) -> ConstraintRecipe {
  { builder, result: recipe_result() }
}

///|
pub fn ConstraintRecipe::builder(self : ConstraintRecipe) -> ConstraintBuilder {
  self.builder
}

///|
pub fn ConstraintRecipe::result(self : ConstraintRecipe) -> RecipeResult {
  self.result
}

///|
/// Post a constraint and update recipe accounting.
fn ConstraintRecipe::recipe_post(
  self : ConstraintRecipe,
  accepted : Bool,
) -> Bool {
  if accepted {
    self.result.posted += 1
  } else {
    self.result.rejected += 1
  }
  accepted
}

///|
/// Post a row of all-different variables.
pub fn ConstraintRecipe::post_all_different(
  self : ConstraintRecipe,
  variables : Array[Int],
) -> Bool {
  self.recipe_post(self.builder.all_different(variables))
}

///|
pub fn ConstraintRecipe::post_exact_sum(
  self : ConstraintRecipe,
  variables : Array[Int],
  target : Int,
) -> Bool {
  self.recipe_post(self.builder.exact_sum(variables, target))
}

///|
pub fn ConstraintRecipe::post_exact_count(
  self : ConstraintRecipe,
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Bool {
  self.recipe_post(self.builder.exact_count(variables, value, count))
}

///|
pub fn ConstraintRecipe::post_at_most(
  self : ConstraintRecipe,
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Bool {
  self.recipe_post(self.builder.at_most_count(variables, value, count))
}

///|
pub fn ConstraintRecipe::post_at_least(
  self : ConstraintRecipe,
  variables : Array[Int],
  value : Int,
  count : Int,
) -> Bool {
  self.recipe_post(self.builder.at_least_count(variables, value, count))
}

///|
pub fn ConstraintRecipe::post_chain(
  self : ConstraintRecipe,
  variables : Array[Int],
) -> Bool {
  self.recipe_post(self.builder.strict_chain(variables))
}

///|
pub fn ConstraintRecipe::post_non_decreasing(
  self : ConstraintRecipe,
  variables : Array[Int],
) -> Bool {
  self.recipe_post(self.builder.nondecreasing_chain(variables))
}

///|
pub fn ConstraintRecipe::post_adjacent_change(
  self : ConstraintRecipe,
  variables : Array[Int],
) -> Bool {
  self.recipe_post(self.builder.adjacent_different(variables))
}

///|
pub fn ConstraintRecipe::post_minimum_distance(
  self : ConstraintRecipe,
  variables : Array[Int],
  distance : Int,
) -> Bool {
  self.recipe_post(self.builder.minimum_distance(variables, distance))
}

///|
pub fn ConstraintRecipe::post_transition(
  self : ConstraintRecipe,
  variables : Array[Int],
  transitions : Array[Array[Int]],
) -> Bool {
  self.recipe_post(self.builder.transition_table(variables, transitions))
}

///|
/// Post a grid's row and column rules.
pub fn ConstraintRecipe::post_grid_rules(
  self : ConstraintRecipe,
  grid : Array[Int],
  rows : Int,
  columns : Int,
) -> Bool {
  let rows_ok = self.builder.grid_rows(grid, rows, columns)
  let columns_ok = self.builder.grid_columns(grid, rows, columns)
  self.recipe_post(rows_ok && columns_ok)
}

///|
/// Post bounded weighted rules.
pub fn ConstraintRecipe::post_upper(
  self : ConstraintRecipe,
  terms : Array[(Int, Int)],
  target : Int,
) -> Bool {
  self.recipe_post(self.builder.weighted_at_most(terms, target))
}

///|
pub fn ConstraintRecipe::post_lower(
  self : ConstraintRecipe,
  terms : Array[(Int, Int)],
  target : Int,
) -> Bool {
  self.recipe_post(self.builder.weighted_at_least(terms, target))
}

///|
pub fn ConstraintRecipe::post_no_overlap(
  self : ConstraintRecipe,
  starts : Array[Int],
  durations : Array[Int],
) -> Bool {
  self.recipe_post(self.builder.no_overlap(starts, durations))
}

///|
pub fn ConstraintRecipe::post_cumulative(
  self : ConstraintRecipe,
  starts : Array[Int],
  durations : Array[Int],
  heights : Array[Int],
  capacity : Int,
) -> Bool {
  self.recipe_post(
    self.builder.cumulative(starts, durations, heights, capacity),
  )
}

///|
/// Post a fixed assignment.
pub fn ConstraintRecipe::post_fix(
  self : ConstraintRecipe,
  variable_id : Int,
  value : Int,
) -> Bool {
  self.recipe_post(self.builder.fix(variable_id, value))
}

///|
/// Build a binary selection vector.
pub fn ConstraintRecipe::recipe_binary_vector(
  self : ConstraintRecipe,
  variables : Array[Int],
) -> Bool {
  self.recipe_post(post_binary_vector(self.builder, variables))
}

///|
pub fn ConstraintRecipe::recipe_one_hot(
  self : ConstraintRecipe,
  variables : Array[Int],
) -> Bool {
  self.recipe_post(post_one_hot(self.builder, variables))
}

///|
/// Return whether all posted recipes succeeded.
pub fn ConstraintRecipe::valid(self : ConstraintRecipe) -> Bool {
  self.result.ok()
}

///|
/// Return a recipe model summary.
pub fn ConstraintRecipe::describe(self : ConstraintRecipe) -> String {
  "\{self.result.describe()}, \{self.builder.describe()}"
}

///|
/// Add a bounded sequence with adjacent changes.
pub fn recipe_sequence(
  recipe : ConstraintRecipe,
  name : String,
  length : Int,
  lower : Int,
  upper : Int,
) -> Array[Int] {
  let variables = recipe.builder.grid(name, 1, length, lower, upper)
  ignore(recipe.post_adjacent_change(variables))
  variables
}

///|
/// Add a balanced binary vector.
pub fn recipe_balanced_binary(
  recipe : ConstraintRecipe,
  name : String,
  length : Int,
  ones : Int,
) -> Array[Int] {
  let variables : Array[Int] = []
  for index in 0..<length {
    variables.push(recipe.builder.add_bool("\{name}_\{index}"))
  }
  ignore(recipe.recipe_binary_vector(variables))
  ignore(recipe.post_exact_sum(variables, ones))
  variables
}

///|
/// Add a finite-domain permutation.
pub fn recipe_permutation(
  recipe : ConstraintRecipe,
  name : String,
  size : Int,
) -> Array[Int] {
  let variables = recipe.builder.grid(name, 1, size, 0, size - 1)
  ignore(recipe.post_all_different(variables))
  variables
}

///|
/// Add a Latin square.
pub fn recipe_latin(
  recipe : ConstraintRecipe,
  name : String,
  size : Int,
) -> Array[Int] {
  let grid = recipe.builder.grid(name, size, size, 0, size - 1)
  ignore(recipe.post_grid_rules(grid, size, size))
  grid
}

///|
/// Add a magic-square sum model.
pub fn recipe_magic_square(
  recipe : ConstraintRecipe,
  name : String,
  size : Int,
) -> Array[Int] {
  let grid = recipe_latin(recipe, name, size)
  let target = size * (size * size - 1) / 2
  for row in 0..<size {
    let values : Array[Int] = []
    for column in 0..<size {
      values.push(grid[row * size + column])
    }
    ignore(recipe.post_exact_sum(values, target))
  }
  for column in 0..<size {
    let values : Array[Int] = []
    for row in 0..<size {
      values.push(grid[row * size + column])
    }
    ignore(recipe.post_exact_sum(values, target))
  }
  grid
}

///|
/// Add an interval chain.
pub fn recipe_interval_chain(
  recipe : ConstraintRecipe,
  name : String,
  count : Int,
  horizon : Int,
  duration : Int,
) -> Array[Int] {
  let starts : Array[Int] = []
  let durations : Array[Int] = []
  for index in 0..<count {
    starts.push(recipe.builder.add_int("\{name}_\{index}", 0, horizon))
    durations.push(duration)
  }
  ignore(recipe.post_no_overlap(starts, durations))
  starts
}

///|
/// Add a cumulative resource chain.
pub fn recipe_resource_chain(
  recipe : ConstraintRecipe,
  name : String,
  count : Int,
  horizon : Int,
  duration : Int,
  height : Int,
  capacity : Int,
) -> Array[Int] {
  let starts : Array[Int] = []
  let durations : Array[Int] = []
  let heights : Array[Int] = []
  for index in 0..<count {
    starts.push(recipe.builder.add_int("\{name}_\{index}", 0, horizon))
    durations.push(duration)
    heights.push(height)
  }
  ignore(recipe.post_cumulative(starts, durations, heights, capacity))
  starts
}

///|
/// Add a worker coverage vector.
pub fn recipe_coverage(
  recipe : ConstraintRecipe,
  name : String,
  slots : Int,
  workers : Int,
  per_worker : Int,
) -> Array[Int] {
  let assignments = recipe.builder.grid(name, 1, slots, 0, workers - 1)
  for worker in 0..<workers {
    ignore(recipe.post_exact_count(assignments, worker, per_worker))
  }
  assignments
}

///|
/// Add a roster with no adjacent repeated worker.
pub fn recipe_rotating_roster(
  recipe : ConstraintRecipe,
  name : String,
  slots : Int,
  workers : Int,
) -> Array[Int] {
  let assignments = recipe.builder.grid(name, 1, slots, 0, workers - 1)
  ignore(recipe.post_adjacent_change(assignments))
  assignments
}

///|
/// Add a bounded knapsack selection vector.
pub fn recipe_knapsack(
  recipe : ConstraintRecipe,
  name : String,
  weights : Array[Int],
  capacity : Int,
) -> Array[Int] {
  let variables : Array[Int] = []
  let terms : Array[(Int, Int)] = []
  for index, weight in weights {
    let variable_id = recipe.builder.add_bool("\{name}_\{index}")
    variables.push(variable_id)
    terms.push((variable_id, weight))
  }
  ignore(recipe.post_upper(terms, capacity))
  variables
}

///|
/// Add a graph coloring vector.
pub fn recipe_coloring(
  recipe : ConstraintRecipe,
  name : String,
  vertices : Int,
  colors : Int,
  edges : Array[(Int, Int)],
) -> Array[Int] {
  let variables = recipe.builder.grid(name, 1, vertices, 0, colors - 1)
  for edge in edges {
    if edge.0 >= 0 && edge.1 >= 0 && edge.0 < vertices && edge.1 < vertices {
      recipe.builder.solver.add_constraint(
        not_equal(variables[edge.0], variables[edge.1]),
      )
    }
  }
  variables
}

///|
/// Solve a recipe.
pub fn ConstraintRecipe::solve(self : ConstraintRecipe) -> Solution? {
  self.builder.solve()
}

///|
pub fn ConstraintRecipe::solve_all(
  self : ConstraintRecipe,
  limit : Int,
) -> Array[Solution] {
  self.builder.solve_all(limit)
}

///|
pub fn ConstraintRecipe::signature(self : ConstraintRecipe) -> Int {
  self.builder.signature() * 37 + self.result.posted * 7 + self.result.rejected
}
