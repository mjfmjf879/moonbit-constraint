///|
/// Deterministic graph algorithms for constraint-model preprocessing.
///
/// Graphs use a dense integer matrix because finite-domain applications often
/// already have a bounded set of resources, machines, or locations. A value
/// of `-1` means that an edge is absent; zero-weight edges are supported.
pub struct GraphEdge {
  from : Int
  to : Int
  weight : Int
}

///|
/// Construct an edge record.
pub fn graph_edge(from : Int, to : Int, weight : Int) -> GraphEdge {
  { from, to, weight }
}

///|
/// Read an edge source.
pub fn GraphEdge::from(self : GraphEdge) -> Int {
  self.from
}

///|
/// Read an edge destination.
pub fn GraphEdge::to(self : GraphEdge) -> Int {
  self.to
}

///|
/// Read an edge weight.
pub fn GraphEdge::weight(self : GraphEdge) -> Int {
  self.weight
}

///|
/// A bounded weighted graph.
pub struct WeightedGraph {
  vertices : Int
  directed : Bool
  weights : Array[Array[Int]]
}

///|
/// Create an empty graph.
pub fn weighted_graph(vertices : Int, directed : Bool) -> WeightedGraph {
  if vertices < 0 {
    abort("graph vertex count must be non-negative")
  }
  { vertices, directed, weights: graph_matrix(vertices, -1) }
}

///|
/// Create a graph from an edge list.
pub fn weighted_graph_from_edges(
  vertices : Int,
  directed : Bool,
  edges : Array[GraphEdge],
) -> WeightedGraph? {
  if vertices < 0 {
    return None
  }
  let graph = weighted_graph(vertices, directed)
  for edge in edges {
    if !graph.add_edge(edge.from, edge.to, edge.weight) {
      return None
    }
  }
  Some(graph)
}

///|
/// Return a fresh square matrix.
fn graph_matrix(size : Int, initial : Int) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for _ in 0..<size {
    let row : Array[Int] = []
    for _ in 0..<size {
      row.push(initial)
    }
    result.push(row)
  }
  result
}

///|
/// Return the vertex count.
pub fn WeightedGraph::vertex_count(self : WeightedGraph) -> Int {
  self.vertices
}

///|
/// Return whether edges are directed.
pub fn WeightedGraph::is_directed(self : WeightedGraph) -> Bool {
  self.directed
}

///|
/// Validate a vertex identifier.
pub fn WeightedGraph::valid_vertex(self : WeightedGraph, vertex : Int) -> Bool {
  vertex >= 0 && vertex < self.vertices
}

///|
/// Add or replace an edge.
pub fn WeightedGraph::add_edge(
  self : WeightedGraph,
  from : Int,
  to : Int,
  weight : Int,
) -> Bool {
  if !self.valid_vertex(from) || !self.valid_vertex(to) || weight < 0 {
    return false
  }
  self.weights[from][to] = weight
  if !self.directed {
    self.weights[to][from] = weight
  }
  true
}

///|
/// Remove an edge.
pub fn WeightedGraph::remove_edge(
  self : WeightedGraph,
  from : Int,
  to : Int,
) -> Bool {
  if !self.valid_vertex(from) ||
    !self.valid_vertex(to) ||
    self.weights[from][to] < 0 {
    return false
  }
  self.weights[from][to] = -1
  if !self.directed {
    self.weights[to][from] = -1
  }
  true
}

///|
/// Return whether an edge exists.
pub fn WeightedGraph::has_edge(
  self : WeightedGraph,
  from : Int,
  to : Int,
) -> Bool {
  self.valid_vertex(from) &&
  self.valid_vertex(to) &&
  self.weights[from][to] >= 0
}

///|
/// Return an edge weight.
pub fn WeightedGraph::edge_weight(
  self : WeightedGraph,
  from : Int,
  to : Int,
) -> Int? {
  if !self.valid_vertex(from) || !self.valid_vertex(to) {
    return None
  }
  let weight = self.weights[from][to]
  if weight < 0 {
    None
  } else {
    Some(weight)
  }
}

///|
/// Return all graph edges in stable row-major order.
pub fn WeightedGraph::edges(self : WeightedGraph) -> Array[GraphEdge] {
  let result : Array[GraphEdge] = []
  for from in 0..<self.vertices {
    for to in 0..<self.vertices {
      if self.weights[from][to] >= 0 && (self.directed || from <= to) {
        result.push(graph_edge(from, to, self.weights[from][to]))
      }
    }
  }
  result
}

///|
/// Return outgoing neighbors in ascending vertex order.
pub fn WeightedGraph::neighbors(
  self : WeightedGraph,
  vertex : Int,
) -> Array[Int] {
  if !self.valid_vertex(vertex) {
    return []
  }
  let result : Array[Int] = []
  for candidate in 0..<self.vertices {
    if self.weights[vertex][candidate] >= 0 {
      result.push(candidate)
    }
  }
  result
}

///|
/// Return the out-degree.
pub fn WeightedGraph::degree(self : WeightedGraph, vertex : Int) -> Int {
  self.neighbors(vertex).length()
}

///|
/// Return the total edge count.
pub fn WeightedGraph::edge_count(self : WeightedGraph) -> Int {
  self.edges().length()
}

///|
/// Return a copied adjacency matrix using -1 for absent edges.
pub fn WeightedGraph::matrix(self : WeightedGraph) -> Array[Array[Int]] {
  self.weights.map(row => row.copy())
}

///|
/// Breadth-first traversal from a source.
pub fn WeightedGraph::breadth_first_order(
  self : WeightedGraph,
  source : Int,
) -> Array[Int] {
  if !self.valid_vertex(source) {
    return []
  }
  let seen : Array[Bool] = []
  for _ in 0..<self.vertices {
    seen.push(false)
  }
  let queue : Array[Int] = [source]
  let result : Array[Int] = []
  seen[source] = true
  let mut head = 0
  while head < queue.length() {
    let vertex = queue[head]
    head += 1
    result.push(vertex)
    for neighbor in self.neighbors(vertex) {
      if !seen[neighbor] {
        seen[neighbor] = true
        queue.push(neighbor)
      }
    }
  }
  result
}

///|
/// Depth-first traversal from a source.
pub fn WeightedGraph::depth_first_order(
  self : WeightedGraph,
  source : Int,
) -> Array[Int] {
  if !self.valid_vertex(source) {
    return []
  }
  let seen : Array[Bool] = []
  for _ in 0..<self.vertices {
    seen.push(false)
  }
  let result : Array[Int] = []
  graph_dfs(self, source, seen, result)
  result
}

///|
/// Recursive DFS helper.
fn graph_dfs(
  graph : WeightedGraph,
  vertex : Int,
  seen : Array[Bool],
  result : Array[Int],
) -> Unit {
  if seen[vertex] {
    return
  }
  seen[vertex] = true
  result.push(vertex)
  for neighbor in graph.neighbors(vertex) {
    graph_dfs(graph, neighbor, seen, result)
  }
}

///|
/// Return connected components, treating directed edges as undirected links.
pub fn WeightedGraph::connected_components(
  self : WeightedGraph,
) -> Array[Array[Int]] {
  let seen : Array[Bool] = []
  for _ in 0..<self.vertices {
    seen.push(false)
  }
  let result : Array[Array[Int]] = []
  for source in 0..<self.vertices {
    if seen[source] {
      continue
    }
    let component : Array[Int] = []
    let queue : Array[Int] = [source]
    seen[source] = true
    let mut head = 0
    while head < queue.length() {
      let vertex = queue[head]
      head += 1
      component.push(vertex)
      for neighbor in 0..<self.vertices {
        if !seen[neighbor] &&
          (
            self.weights[vertex][neighbor] >= 0 ||
            self.weights[neighbor][vertex] >= 0
          ) {
          seen[neighbor] = true
          queue.push(neighbor)
        }
      }
    }
    result.push(component)
  }
  result
}

///|
/// Compute non-negative shortest distances from a source with Dijkstra.
pub fn WeightedGraph::dijkstra_distances(
  self : WeightedGraph,
  source : Int,
) -> Array[Int] {
  let distances : Array[Int] = []
  let used : Array[Bool] = []
  for _ in 0..<self.vertices {
    distances.push(2147483647)
    used.push(false)
  }
  if !self.valid_vertex(source) {
    return distances
  }
  distances[source] = 0
  for _ in 0..<self.vertices {
    let mut selected = -1
    let mut best = 2147483647
    for vertex in 0..<self.vertices {
      if !used[vertex] && distances[vertex] < best {
        selected = vertex
        best = distances[vertex]
      }
    }
    if selected < 0 {
      break
    }
    used[selected] = true
    for neighbor in self.neighbors(selected) {
      let candidate = distances[selected] + self.weights[selected][neighbor]
      if candidate < distances[neighbor] {
        distances[neighbor] = candidate
      }
    }
  }
  distances
}

///|
/// Compute shortest-path predecessors from a source.
pub fn WeightedGraph::dijkstra_predecessors(
  self : WeightedGraph,
  source : Int,
) -> Array[Int] {
  let distances : Array[Int] = []
  let predecessors : Array[Int] = []
  let used : Array[Bool] = []
  for _ in 0..<self.vertices {
    distances.push(2147483647)
    predecessors.push(-1)
    used.push(false)
  }
  if !self.valid_vertex(source) {
    return predecessors
  }
  distances[source] = 0
  for _ in 0..<self.vertices {
    let mut selected = -1
    let mut best = 2147483647
    for vertex in 0..<self.vertices {
      if !used[vertex] && distances[vertex] < best {
        selected = vertex
        best = distances[vertex]
      }
    }
    if selected < 0 {
      break
    }
    used[selected] = true
    for neighbor in self.neighbors(selected) {
      let candidate = distances[selected] + self.weights[selected][neighbor]
      if candidate < distances[neighbor] {
        distances[neighbor] = candidate
        predecessors[neighbor] = selected
      }
    }
  }
  predecessors
}

///|
/// Reconstruct a shortest path from source to destination.
pub fn WeightedGraph::shortest_path(
  self : WeightedGraph,
  source : Int,
  destination : Int,
) -> Array[Int]? {
  if !self.valid_vertex(source) || !self.valid_vertex(destination) {
    return None
  }
  let predecessors = self.dijkstra_predecessors(source)
  if source != destination && predecessors[destination] < 0 {
    return None
  }
  let reversed : Array[Int] = []
  let mut current = destination
  reversed.push(current)
  while current != source {
    current = predecessors[current]
    if current < 0 {
      return None
    }
    reversed.push(current)
  }
  let result : Array[Int] = []
  let last = reversed.length() - 1
  for index in last>=..0 {
    result.push(reversed[index])
  }
  Some(result)
}

///|
/// Compute all-pairs shortest distances.
pub fn WeightedGraph::floyd_warshall(self : WeightedGraph) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for from in 0..<self.vertices {
    let row : Array[Int] = []
    for to in 0..<self.vertices {
      if from == to {
        row.push(0)
      } else {
        row.push(self.weights[from][to])
      }
    }
    result.push(row)
  }
  for middle in 0..<self.vertices {
    for from in 0..<self.vertices {
      if result[from][middle] < 0 {
        continue
      }
      for to in 0..<self.vertices {
        if result[middle][to] < 0 {
          continue
        }
        let candidate = result[from][middle] + result[middle][to]
        if result[from][to] < 0 || candidate < result[from][to] {
          result[from][to] = candidate
        }
      }
    }
  }
  result
}

///|
/// Return whether all vertices are reachable from a source.
pub fn WeightedGraph::reaches_all(self : WeightedGraph, source : Int) -> Bool {
  self.breadth_first_order(source).length() == self.vertices
}

///|
/// Return an ordering for a directed acyclic graph, or None for a cycle.
pub fn WeightedGraph::topological_order(self : WeightedGraph) -> Array[Int]? {
  let indegree : Array[Int] = []
  for _ in 0..<self.vertices {
    indegree.push(0)
  }
  for from in 0..<self.vertices {
    for to in self.neighbors(from) {
      indegree[to] += 1
    }
  }
  let ready : Array[Int] = []
  for vertex in 0..<self.vertices {
    if indegree[vertex] == 0 {
      ready.push(vertex)
    }
  }
  let result : Array[Int] = []
  let mut head = 0
  while head < ready.length() {
    let vertex = ready[head]
    head += 1
    result.push(vertex)
    for neighbor in self.neighbors(vertex) {
      indegree[neighbor] -= 1
      if indegree[neighbor] == 0 {
        ready.push(neighbor)
      }
    }
  }
  if result.length() == self.vertices {
    Some(result)
  } else {
    None
  }
}

///|
/// Return whether the directed graph contains a cycle.
pub fn WeightedGraph::has_directed_cycle(self : WeightedGraph) -> Bool {
  self.topological_order() is None
}

///|
/// Compute transitive reachability using boolean closure.
pub fn WeightedGraph::transitive_closure(
  self : WeightedGraph,
) -> Array[Array[Bool]] {
  let result : Array[Array[Bool]] = []
  for from in 0..<self.vertices {
    let row : Array[Bool] = []
    for to in 0..<self.vertices {
      row.push(self.weights[from][to] >= 0)
    }
    result.push(row)
  }
  for vertex in 0..<self.vertices {
    result[vertex][vertex] = true
  }
  for middle in 0..<self.vertices {
    for from in 0..<self.vertices {
      if result[from][middle] {
        for to in 0..<self.vertices {
          result[from][to] = result[from][to] || result[middle][to]
        }
      }
    }
  }
  result
}

///|
/// Greedily color vertices in order.
pub fn WeightedGraph::greedy_coloring(self : WeightedGraph) -> Array[Int] {
  let colors : Array[Int] = []
  for _ in 0..<self.vertices {
    colors.push(-1)
  }
  for vertex in 0..<self.vertices {
    let forbidden : Array[Bool] = []
    for _ in 0..<self.vertices {
      forbidden.push(false)
    }
    for neighbor in self.neighbors(vertex) {
      if colors[neighbor] >= 0 {
        forbidden[colors[neighbor]] = true
      }
    }
    let mut color = 0
    while color < self.vertices && forbidden[color] {
      color += 1
    }
    colors[vertex] = color
  }
  colors
}

///|
/// Validate a vertex coloring.
pub fn WeightedGraph::valid_coloring(
  self : WeightedGraph,
  colors : Array[Int],
) -> Bool {
  if colors.length() != self.vertices {
    return false
  }
  for color in colors {
    if color < 0 {
      return false
    }
  }
  for from in 0..<self.vertices {
    for to in self.neighbors(from) {
      if colors[from] == colors[to] {
        return false
      }
    }
  }
  true
}

///|
/// Return the number of colors in a coloring.
pub fn coloring_count(colors : Array[Int]) -> Int {
  let mut maximum = -1
  for color in colors {
    if color > maximum {
      maximum = color
    }
  }
  maximum + 1
}

///|
/// Return a minimum spanning forest using a deterministic Kruskal pass.
pub fn WeightedGraph::minimum_spanning_forest(
  self : WeightedGraph,
) -> Array[GraphEdge] {
  let candidates = self.edges()
  for left in 0..<candidates.length() {
    for right in (left + 1)..<candidates.length() {
      if candidates[right].weight < candidates[left].weight {
        let temporary = candidates[left]
        candidates[left] = candidates[right]
        candidates[right] = temporary
      }
    }
  }
  let parent : Array[Int] = []
  for vertex in 0..<self.vertices {
    parent.push(vertex)
  }
  let result : Array[GraphEdge] = []
  for edge in candidates {
    let first = graph_root(parent, edge.from)
    let second = graph_root(parent, edge.to)
    if first != second {
      parent[first] = second
      result.push(edge)
    }
  }
  result
}

///|
/// Find a disjoint-set representative.
fn graph_root(parent : Array[Int], vertex : Int) -> Int {
  let mut current = vertex
  while parent[current] != current {
    current = parent[current]
  }
  current
}

///|
/// Return the total weight of an edge set.
pub fn edge_set_weight(edges : Array[GraphEdge]) -> Int {
  let mut result = 0
  for edge in edges {
    result += edge.weight
  }
  result
}

///|
/// Find a maximum flow between source and sink.
pub fn WeightedGraph::maximum_flow(
  self : WeightedGraph,
  source : Int,
  sink : Int,
) -> Int {
  if !self.valid_vertex(source) || !self.valid_vertex(sink) || source == sink {
    return 0
  }
  let residual = self.matrix()
  for from in 0..<self.vertices {
    for to in 0..<self.vertices {
      if residual[from][to] < 0 {
        residual[from][to] = 0
      }
    }
  }
  let mut flow = 0
  let parent : Array[Int] = []
  while graph_augmenting_path(residual, source, sink, parent) {
    let mut amount = 2147483647
    let mut current = sink
    while current != source {
      let previous = parent[current]
      if residual[previous][current] < amount {
        amount = residual[previous][current]
      }
      current = previous
    }
    current = sink
    while current != source {
      let previous = parent[current]
      residual[previous][current] -= amount
      residual[current][previous] += amount
      current = previous
    }
    flow += amount
  }
  flow
}

///|
/// Find one augmenting path in a residual graph.
fn graph_augmenting_path(
  residual : Array[Array[Int]],
  source : Int,
  sink : Int,
  parent : Array[Int],
) -> Bool {
  while parent.length() > 0 {
    ignore(parent.pop())
  }
  for _ in 0..<residual.length() {
    parent.push(-1)
  }
  let seen : Array[Bool] = []
  for _ in 0..<residual.length() {
    seen.push(false)
  }
  let queue : Array[Int] = [source]
  seen[source] = true
  let mut head = 0
  while head < queue.length() {
    let vertex = queue[head]
    head += 1
    for neighbor in 0..<residual.length() {
      if !seen[neighbor] && residual[vertex][neighbor] > 0 {
        seen[neighbor] = true
        parent[neighbor] = vertex
        queue.push(neighbor)
      }
    }
  }
  seen[sink]
}

///|
/// Return a stable edge-list representation.
pub fn WeightedGraph::edge_list(self : WeightedGraph) -> String {
  let builder = StringBuilder()
  for index, edge in self.edges() {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string("\{edge.from},\{edge.to},\{edge.weight}")
  }
  builder.to_string()
}

///|
/// Parse a small edge list with one `from,to,weight` row per line.
pub fn parse_edge_list(
  input : String,
  vertices : Int,
  directed : Bool,
) -> WeightedGraph? {
  let graph = weighted_graph(vertices, directed)
  for line_view in input.split("\n") {
    let line = line_view.to_owned()
    if line.trim() == "" {
      continue
    }
    let values = parse_integer_list(line)
    match values {
      Some(row) =>
        if row.length() != 3 || !graph.add_edge(row[0], row[1], row[2]) {
          return None
        }
      None => return None
    }
  }
  Some(graph)
}

///|
/// Return the average outgoing degree.
pub fn WeightedGraph::average_degree(self : WeightedGraph) -> Int {
  if self.vertices == 0 {
    return 0
  }
  let mut total = 0
  for vertex in 0..<self.vertices {
    total += self.degree(vertex)
  }
  total / self.vertices
}

///|
/// Return whether the graph is a simple graph.
pub fn WeightedGraph::is_simple_graph(self : WeightedGraph) -> Bool {
  for vertex in 0..<self.vertices {
    if self.weights[vertex][vertex] >= 0 {
      return false
    }
  }
  true
}

///|
/// Return the heaviest outgoing edge weight from a vertex.
pub fn WeightedGraph::maximum_outgoing_weight(
  self : WeightedGraph,
  vertex : Int,
) -> Int {
  let mut result = 0
  for neighbor in self.neighbors(vertex) {
    if self.weights[vertex][neighbor] > result {
      result = self.weights[vertex][neighbor]
    }
  }
  result
}

///|
/// Return the lightest outgoing edge weight, or -1 when isolated.
pub fn WeightedGraph::minimum_outgoing_weight(
  self : WeightedGraph,
  vertex : Int,
) -> Int {
  let mut result = 2147483647
  for neighbor in self.neighbors(vertex) {
    if self.weights[vertex][neighbor] < result {
      result = self.weights[vertex][neighbor]
    }
  }
  if result == 2147483647 {
    -1
  } else {
    result
  }
}

///|
/// Return the vertex with the largest degree.
pub fn WeightedGraph::highest_degree_vertex(self : WeightedGraph) -> Int? {
  if self.vertices == 0 {
    return None
  }
  let mut result = 0
  for vertex in 1..<self.vertices {
    if self.degree(vertex) > self.degree(result) {
      result = vertex
    }
  }
  Some(result)
}

///|
/// Return the number of isolated vertices.
pub fn WeightedGraph::isolated_vertex_count(self : WeightedGraph) -> Int {
  let mut result = 0
  for vertex in 0..<self.vertices {
    if self.degree(vertex) == 0 {
      result += 1
    }
  }
  result
}

///|
/// Return whether a graph has a path between two vertices.
pub fn WeightedGraph::connected(
  self : WeightedGraph,
  source : Int,
  destination : Int,
) -> Bool {
  if !self.valid_vertex(source) || !self.valid_vertex(destination) {
    return false
  }
  self.breadth_first_order(source).contains(destination)
}

///|
/// Return the sum of distances from a source to reachable vertices.
pub fn WeightedGraph::distance_sum(self : WeightedGraph, source : Int) -> Int {
  let distances = self.dijkstra_distances(source)
  let mut result = 0
  for distance in distances {
    if distance < 2147483647 {
      result += distance
    }
  }
  result
}

///|
/// Return a stable graph fingerprint.
pub fn WeightedGraph::graph_signature(self : WeightedGraph) -> Int {
  let mut result = if self.directed { 31 } else { 17 }
  for edge in self.edges() {
    result = result * 37 + edge.from * 7 + edge.to * 11 + edge.weight
  }
  result
}
