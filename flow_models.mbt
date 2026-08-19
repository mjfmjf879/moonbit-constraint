///|
/// Capacity-network models for assignment and transport pipelines.
///
/// This layer complements the dense graph algorithms with an explicit network
/// object that tracks capacities, supplies, and a computed flow assignment.
pub struct CapacityArc {
  from : Int
  to : Int
  capacity : Int
  cost : Int
}

///|
/// Create a capacity arc.
pub fn capacity_arc(
  from : Int,
  to : Int,
  capacity : Int,
  cost : Int,
) -> CapacityArc {
  { from, to, capacity: if capacity < 0 { 0 } else { capacity }, cost }
}

///|
/// A capacity network.
pub struct CapacityNetwork {
  vertices : Int
  arcs : Array[CapacityArc]
}

///|
/// Create an empty network.
pub fn capacity_network(vertices : Int) -> CapacityNetwork {
  if vertices < 0 {
    abort("capacity network vertex count must be non-negative")
  }
  { vertices, arcs: [] }
}

///|
/// Add a directed capacity arc.
pub fn CapacityNetwork::add_arc(
  self : CapacityNetwork,
  from : Int,
  to : Int,
  capacity : Int,
  cost : Int,
) -> Bool {
  if from < 0 ||
    to < 0 ||
    from >= self.vertices ||
    to >= self.vertices ||
    capacity < 0 {
    return false
  }
  self.arcs.push(capacity_arc(from, to, capacity, cost))
  true
}

///|
/// Return vertex count.
pub fn CapacityNetwork::vertex_count(self : CapacityNetwork) -> Int {
  self.vertices
}

///|
/// Return arc count.
pub fn CapacityNetwork::arc_count(self : CapacityNetwork) -> Int {
  self.arcs.length()
}

///|
/// Return copied arcs.
pub fn CapacityNetwork::arcs(self : CapacityNetwork) -> Array[CapacityArc] {
  self.arcs.copy()
}

///|
/// Return outgoing arcs.
pub fn CapacityNetwork::outgoing(
  self : CapacityNetwork,
  vertex : Int,
) -> Array[CapacityArc] {
  let result : Array[CapacityArc] = []
  for arc in self.arcs {
    if arc.from == vertex {
      result.push(arc)
    }
  }
  result
}

///|
/// Return an integer capacity matrix.
pub fn CapacityNetwork::capacity_matrix(self : CapacityNetwork) -> IntMatrix {
  let result = int_matrix(self.vertices, self.vertices)
  for arc in self.arcs {
    let current = result.get(arc.from, arc.to)
    ignore(result.set(arc.from, arc.to, current + arc.capacity))
  }
  result
}

///|
/// Compute a maximum flow value and flow matrix.
pub fn CapacityNetwork::max_flow(
  self : CapacityNetwork,
  source : Int,
  sink : Int,
) -> (Int, IntMatrix) {
  let residual = self.capacity_matrix()
  let flow = int_matrix(self.vertices, self.vertices)
  let mut total = 0
  let parent : Array[Int] = []
  while network_augment(residual, source, sink, parent) {
    let mut amount = 2147483647
    let mut current = sink
    while current != source {
      let previous = parent[current]
      let available = residual.get(previous, current)
      if available < amount {
        amount = available
      }
      current = previous
    }
    current = sink
    while current != source {
      let previous = parent[current]
      ignore(
        residual.set(
          previous,
          current,
          residual.get(previous, current) - amount,
        ),
      )
      ignore(
        residual.set(
          current,
          previous,
          residual.get(current, previous) + amount,
        ),
      )
      ignore(flow.set(previous, current, flow.get(previous, current) + amount))
      current = previous
    }
    total += amount
  }
  (total, flow)
}

///|
/// Find a residual augmenting path.
fn network_augment(
  residual : IntMatrix,
  source : Int,
  sink : Int,
  parent : Array[Int],
) -> Bool {
  if source < 0 ||
    sink < 0 ||
    source >= residual.row_count() ||
    sink >= residual.row_count() ||
    source == sink {
    return false
  }
  while parent.length() > 0 {
    ignore(parent.pop())
  }
  let visited : Array[Bool] = []
  for _ in 0..<residual.row_count() {
    parent.push(-1)
    visited.push(false)
  }
  let queue : Array[Int] = [source]
  visited[source] = true
  let mut head = 0
  while head < queue.length() {
    let vertex = queue[head]
    head += 1
    for neighbor in 0..<residual.column_count() {
      if !visited[neighbor] && residual.get(vertex, neighbor) > 0 {
        visited[neighbor] = true
        parent[neighbor] = vertex
        queue.push(neighbor)
      }
    }
  }
  visited[sink]
}

///|
/// Return vertices reachable from source in the residual network.
pub fn residual_reachable(residual : IntMatrix, source : Int) -> Array[Int] {
  let result : Array[Int] = []
  if source < 0 || source >= residual.row_count() {
    return result
  }
  let visited : Array[Bool] = []
  for _ in 0..<residual.row_count() {
    visited.push(false)
  }
  let queue : Array[Int] = [source]
  visited[source] = true
  let mut head = 0
  while head < queue.length() {
    let vertex = queue[head]
    head += 1
    result.push(vertex)
    for neighbor in 0..<residual.column_count() {
      if !visited[neighbor] && residual.get(vertex, neighbor) > 0 {
        visited[neighbor] = true
        queue.push(neighbor)
      }
    }
  }
  result
}

///|
/// Return the total cost of a flow matrix.
pub fn CapacityNetwork::flow_cost(
  self : CapacityNetwork,
  flow : IntMatrix,
) -> Int {
  let mut result = 0
  for arc in self.arcs {
    if flow.valid_cell(arc.from, arc.to) {
      result += flow.get(arc.from, arc.to) * arc.cost
    }
  }
  result
}

///|
/// Validate a flow matrix against arc capacities.
pub fn CapacityNetwork::validate_flow(
  self : CapacityNetwork,
  flow : IntMatrix,
) -> Array[String] {
  let errors : Array[String] = []
  if flow.row_count() != self.vertices || flow.column_count() != self.vertices {
    errors.push("flow-shape")
    return errors
  }
  for arc in self.arcs {
    if flow.get(arc.from, arc.to) < 0 ||
      flow.get(arc.from, arc.to) > arc.capacity {
      errors.push("capacity-\{arc.from}-\{arc.to}")
    }
  }
  errors
}

///|
/// Return outgoing flow from a vertex.
pub fn flow_out(flow : IntMatrix, vertex : Int) -> Int {
  integer_sum(flow.row(vertex))
}

///|
/// Return incoming flow to a vertex.
pub fn flow_in(flow : IntMatrix, vertex : Int) -> Int {
  integer_sum(flow.column(vertex))
}

///|
/// Return supply imbalance at a vertex.
pub fn flow_balance(flow : IntMatrix, vertex : Int) -> Int {
  flow_out(flow, vertex) - flow_in(flow, vertex)
}

///|
/// Return whether flow is conserved at all non-terminal vertices.
pub fn flow_conserved(flow : IntMatrix, source : Int, sink : Int) -> Bool {
  for vertex in 0..<flow.row_count() {
    if vertex != source && vertex != sink && flow_balance(flow, vertex) != 0 {
      return false
    }
  }
  true
}

///|
/// Return a min-cut capacity from a reachable partition.
pub fn CapacityNetwork::cut_capacity(
  self : CapacityNetwork,
  reachable : Array[Int],
) -> Int {
  let mut result = 0
  for arc in self.arcs {
    if reachable.contains(arc.from) && !reachable.contains(arc.to) {
      result += arc.capacity
    }
  }
  result
}

///|
/// Return a deterministic network fingerprint.
pub fn CapacityNetwork::signature(self : CapacityNetwork) -> Int {
  let mut result = self.vertices * 31
  for arc in self.arcs {
    result = result * 37 +
      arc.from * 3 +
      arc.to * 5 +
      arc.capacity * 7 +
      arc.cost
  }
  result
}

///|
/// Build a bipartite compatibility network.
pub fn bipartite_network(
  left_size : Int,
  right_size : Int,
  relation : FiniteRelation,
) -> CapacityNetwork {
  let source = 0
  let left_start = 1
  let right_start = left_start + left_size
  let sink = right_start + right_size
  let network = capacity_network(sink + 1)
  for left in 0..<left_size {
    ignore(network.add_arc(source, left_start + left, 1, 0))
  }
  for right in 0..<right_size {
    ignore(network.add_arc(right_start + right, sink, 1, 0))
  }
  for pair in relation.pairs() {
    ignore(
      network.add_arc(left_start + pair.left, right_start + pair.right, 1, 0),
    )
  }
  network
}

///|
/// Return matched left-right pairs from a unit flow.
pub fn bipartite_matching(
  left_size : Int,
  right_size : Int,
  relation : FiniteRelation,
) -> Array[RelationPair] {
  let network = bipartite_network(left_size, right_size, relation)
  let flow_result = network.max_flow(0, left_size + right_size + 1)
  let flow = flow_result.1
  let result : Array[RelationPair] = []
  for pair in relation.pairs() {
    if flow.get(pair.left + 1, pair.right + left_size + 1) > 0 {
      result.push(pair)
    }
  }
  result
}
