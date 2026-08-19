///|
/// An undirected graph-coloring model.
pub struct GraphColoring {
  solver : Solver
  colors : Array[Int]
  vertices : Int
  color_count : Int
  edges : Array[(Int, Int)]
}

///|
/// Create a graph-coloring problem and post one inequality per edge.
pub fn graph_coloring(
  vertices : Int,
  color_count : Int,
  edges : Array[(Int, Int)],
) -> GraphColoring? {
  if vertices < 1 || color_count < 1 {
    return None
  }
  let solver = new_solver()
  let colors : Array[Int] = []
  for vertex in 0..<vertices {
    colors.push(
      solver.add_variable(variable("vertex_\{vertex}", 0, color_count - 1)),
    )
  }
  for edge in edges {
    let (left, right) = edge
    if left < 0 ||
      left >= vertices ||
      right < 0 ||
      right >= vertices ||
      left == right {
      return None
    }
    solver.add_constraint(not_equal(colors[left], colors[right]))
  }
  Some({ solver, colors, vertices, color_count, edges: edges.copy() })
}

///|
/// Return the variable identifier for a vertex.
pub fn GraphColoring::color_of(self : GraphColoring, vertex : Int) -> Int {
  if vertex < 0 || vertex >= self.vertices {
    abort("graph vertex is outside the problem")
  }
  self.colors[vertex]
}

///|
/// Solve a coloring problem once.
pub fn GraphColoring::solve(self : GraphColoring) -> Solution? {
  self.solver.solve()
}

///|
/// Enumerate up to `limit` colorings.
pub fn GraphColoring::solve_all(
  self : GraphColoring,
  limit : Int,
) -> Array[Solution] {
  self.solver.limit(limit)
  self.solver.solve_all()
}

///|
/// Return the color vector in vertex order.
pub fn GraphColoring::colors(
  self : GraphColoring,
  solution : Solution,
) -> Array[Int] {
  self.colors.map(id => solution.get(id))
}

///|
/// Validate a complete coloring.
pub fn GraphColoring::is_valid(
  self : GraphColoring,
  solution : Solution,
) -> Bool {
  if !self.solver.is_valid_solution(solution) {
    return false
  }
  for edge in self.edges {
    let (left, right) = edge
    if solution.get(self.colors[left]) == solution.get(self.colors[right]) {
      return false
    }
  }
  true
}

///|
/// Return solver statistics.
pub fn GraphColoring::stats(self : GraphColoring) -> SearchStats {
  self.solver.stats()
}

///|
/// Return an adjacency matrix, useful for debugging imported graphs.
pub fn GraphColoring::adjacency(self : GraphColoring) -> Array[Array[Bool]] {
  let matrix : Array[Array[Bool]] = []
  for _ in 0..<self.vertices {
    matrix.push(Array::make(self.vertices, false))
  }
  for edge in self.edges {
    let (left, right) = edge
    matrix[left][right] = true
    matrix[right][left] = true
  }
  matrix
}

///|
/// Render a solution as `vertex:color` pairs.
pub fn GraphColoring::render(
  self : GraphColoring,
  solution : Solution,
) -> String {
  let builder = StringBuilder()
  for vertex in 0..<self.vertices {
    if vertex > 0 {
      builder.write_string(", ")
    }
    builder.write_string("\{vertex}:\{solution.get(self.colors[vertex])}")
  }
  builder.to_string()
}

///|
/// Build a cycle graph with `vertices` vertices.
pub fn cycle_coloring(vertices : Int, color_count : Int) -> GraphColoring? {
  if vertices < 3 {
    return None
  }
  let edges : Array[(Int, Int)] = []
  for vertex in 0..<vertices {
    edges.push((vertex, (vertex + 1) % vertices))
  }
  graph_coloring(vertices, color_count, edges)
}

///|
/// Build a complete graph where every pair must receive different colors.
pub fn complete_coloring(vertices : Int) -> GraphColoring? {
  let edges : Array[(Int, Int)] = []
  for left in 0..<vertices {
    for right in (left + 1)..<vertices {
      edges.push((left, right))
    }
  }
  graph_coloring(vertices, vertices, edges)
}

///|
/// Build a rectangular grid graph for map-coloring examples.
pub fn grid_coloring(
  rows : Int,
  columns : Int,
  color_count : Int,
) -> GraphColoring? {
  if rows < 1 || columns < 1 {
    return None
  }
  let edges : Array[(Int, Int)] = []
  let vertices = rows * columns
  for row in 0..<rows {
    for column in 0..<columns {
      let current = row * columns + column
      if column + 1 < columns {
        edges.push((current, current + 1))
      }
      if row + 1 < rows {
        edges.push((current, current + columns))
      }
    }
  }
  graph_coloring(vertices, color_count, edges)
}

///|
/// Return the chromatic lower bound from a clique supplied by the caller.
pub fn clique_lower_bound(clique : Array[Int]) -> Int {
  clique.length()
}
