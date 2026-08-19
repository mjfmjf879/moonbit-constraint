///|
/// Deterministic discrete-event simulation helpers.
///
/// The simulation layer is intentionally integer-based: it can replay queue,
/// service, and maintenance scenarios in CI without wall-clock randomness.
/// Events are ordered by time and then sequence number, making traces stable
/// even when several events share a timestamp.
pub enum SimulationEventKind {
  Arrival
  ServiceStart
  ServiceFinish
  Maintenance
  CustomEvent
}

///|
/// Return the custom-event constructor for callers building integrations.
pub fn custom_event_kind() -> SimulationEventKind {
  CustomEvent
}

///|
/// A scheduled event.
pub struct SimulationEvent {
  time : Int
  sequence : Int
  entity : Int
  resource : Int
  kind : SimulationEventKind
  payload : Int
}

///|
/// Construct an event.
pub fn simulation_event(
  time : Int,
  sequence : Int,
  entity : Int,
  resource : Int,
  kind : SimulationEventKind,
  payload : Int,
) -> SimulationEvent {
  { time, sequence, entity, resource, kind, payload }
}

///|
/// Return a stable kind label.
pub fn SimulationEvent::kind_name(self : SimulationEvent) -> String {
  match self.kind {
    Arrival => "arrival"
    ServiceStart => "service-start"
    ServiceFinish => "service-finish"
    Maintenance => "maintenance"
    CustomEvent => "custom"
  }
}

///|
/// Return whether the first event precedes the second.
fn event_before(left : SimulationEvent, right : SimulationEvent) -> Bool {
  left.time < right.time ||
  (left.time == right.time && left.sequence < right.sequence)
}

///|
/// A sorted event queue.
pub struct EventQueue {
  events : Array[SimulationEvent]
}

///|
/// Create an empty queue.
pub fn event_queue() -> EventQueue {
  { events: [] }
}

///|
/// Return queue length.
pub fn EventQueue::length(self : EventQueue) -> Int {
  self.events.length()
}

///|
/// Add an event in stable order.
pub fn EventQueue::push(self : EventQueue, event : SimulationEvent) -> Bool {
  let mut position = 0
  while position < self.events.length() &&
        event_before(self.events[position], event) {
    position += 1
  }
  self.events.push(event)
  let mut index = self.events.length() - 1
  while index > position {
    self.events[index] = self.events[index - 1]
    index -= 1
  }
  self.events[position] = event
  true
}

///|
/// Pop the earliest event.
pub fn EventQueue::pop(self : EventQueue) -> SimulationEvent? {
  if self.events.length() == 0 {
    return None
  }
  let result = self.events[0]
  for index in 1..<self.events.length() {
    self.events[index - 1] = self.events[index]
  }
  ignore(self.events.pop())
  Some(result)
}

///|
/// Peek at the earliest event.
pub fn EventQueue::peek(self : EventQueue) -> SimulationEvent? {
  if self.events.length() == 0 {
    None
  } else {
    Some(self.events[0])
  }
}

///|
/// Remove all queued events.
pub fn EventQueue::clear(self : EventQueue) -> Unit {
  while self.events.length() > 0 {
    ignore(self.events.pop())
  }
}

///|
/// A simulated entity record.
pub struct SimulationEntity {
  id : Int
  arrival : Int
  service : Int
  priority : Int
}

///|
/// Create an entity.
pub fn simulation_entity(
  id : Int,
  arrival : Int,
  service : Int,
  priority : Int,
) -> SimulationEntity {
  {
    id,
    arrival: if arrival < 0 {
      0
    } else {
      arrival
    },
    service: if service < 0 {
      0
    } else {
      service
    },
    priority,
  }
}

///|
/// A single-server queue simulation.
pub struct QueueSimulation {
  horizon : Int
  entities : Array[SimulationEntity]
  queue : EventQueue
  trace : Array[SimulationEvent]
  mut next_sequence : Int
  mut server_free : Int
  mut total_wait : Int
  mut completed : Int
}

///|
/// Create a queue simulation and seed arrivals.
pub fn queue_simulation(
  horizon : Int,
  entities : Array[SimulationEntity],
) -> QueueSimulation? {
  if horizon < 0 {
    return None
  }
  for index, entity in entities {
    if entity.id != index || entity.arrival > horizon {
      return None
    }
  }
  let simulation = {
    horizon,
    entities: entities.copy(),
    queue: event_queue(),
    trace: [],
    next_sequence: 0,
    server_free: 0,
    total_wait: 0,
    completed: 0,
  }
  for entity in entities {
    ignore(
      simulation.schedule(entity.arrival, entity.id, 0, Arrival, entity.service),
    )
  }
  Some(simulation)
}

///|
/// Schedule an event.
pub fn QueueSimulation::schedule(
  self : QueueSimulation,
  time : Int,
  entity : Int,
  resource : Int,
  kind : SimulationEventKind,
  payload : Int,
) -> Bool {
  if time < 0 || time > self.horizon {
    return false
  }
  let event = simulation_event(
    time,
    self.next_sequence,
    entity,
    resource,
    kind,
    payload,
  )
  self.next_sequence += 1
  ignore(self.queue.push(event))
  true
}

///|
/// Process the next queued event.
pub fn QueueSimulation::step(self : QueueSimulation) -> SimulationEvent? {
  match self.queue.pop() {
    None => None
    Some(event) => {
      self.trace.push(event)
      match event.kind {
        Arrival => {
          let start = if self.server_free > event.time {
            self.server_free
          } else {
            event.time
          }
          self.total_wait += start - event.time
          ignore(
            self.schedule(
              start,
              event.entity,
              event.resource,
              ServiceStart,
              event.payload,
            ),
          )
        }
        ServiceStart => {
          let finish = event.time + event.payload
          self.server_free = finish
          if finish <= self.horizon {
            ignore(
              self.schedule(
                finish,
                event.entity,
                event.resource,
                ServiceFinish,
                event.payload,
              ),
            )
          }
        }
        ServiceFinish => self.completed += 1
        Maintenance =>
          self.server_free = if self.server_free < event.time + event.payload {
            event.time + event.payload
          } else {
            self.server_free
          }
        CustomEvent => ()
      }
      Some(event)
    }
  }
}

///|
/// Run until no event remains or the horizon is reached.
pub fn QueueSimulation::run(self : QueueSimulation) -> Int {
  let mut steps = 0
  while self.queue.length() > 0 {
    match self.step() {
      Some(_) => steps += 1
      None => break
    }
  }
  steps
}

///|
/// Return current simulation time.
pub fn QueueSimulation::current_time(self : QueueSimulation) -> Int {
  if self.trace.length() == 0 {
    0
  } else {
    self.trace[self.trace.length() - 1].time
  }
}

///|
/// Return completed entity count.
pub fn QueueSimulation::completed(self : QueueSimulation) -> Int {
  self.completed
}

///|
/// Return queued entity count.
pub fn QueueSimulation::pending(self : QueueSimulation) -> Int {
  self.entities.length() - self.completed
}

///|
/// Return total waiting time.
pub fn QueueSimulation::total_wait(self : QueueSimulation) -> Int {
  self.total_wait
}

///|
/// Return average waiting time.
pub fn QueueSimulation::average_wait(self : QueueSimulation) -> Int {
  if self.completed == 0 {
    0
  } else {
    self.total_wait / self.completed
  }
}

///|
/// Return the event trace.
pub fn QueueSimulation::trace(self : QueueSimulation) -> Array[SimulationEvent] {
  self.trace.copy()
}

///|
/// Return all events for one entity.
pub fn QueueSimulation::entity_trace(
  self : QueueSimulation,
  entity : Int,
) -> Array[SimulationEvent] {
  let result : Array[SimulationEvent] = []
  for event in self.trace {
    if event.entity == entity {
      result.push(event)
    }
  }
  result
}

///|
/// Schedule a maintenance block on the server.
pub fn QueueSimulation::schedule_maintenance(
  self : QueueSimulation,
  start : Int,
  duration : Int,
) -> Bool {
  self.schedule(
    start,
    -1,
    0,
    Maintenance,
    if duration < 0 {
      0
    } else {
      duration
    },
  )
}

///|
/// Return a deterministic utilization percentage.
pub fn QueueSimulation::utilization(self : QueueSimulation) -> Int {
  if self.horizon == 0 {
    return 0
  }
  self.server_free * 100 / self.horizon
}

///|
/// Return all arrivals in id order.
pub fn QueueSimulation::arrivals(self : QueueSimulation) -> Array[Int] {
  self.entities.map(entity => entity.arrival)
}

///|
/// Return all service durations in id order.
pub fn QueueSimulation::service_times(self : QueueSimulation) -> Array[Int] {
  self.entities.map(entity => entity.service)
}

///|
/// Return a stable simulation signature.
pub fn QueueSimulation::signature(self : QueueSimulation) -> Int {
  let mut result = self.horizon * 31 + self.entities.length()
  for event in self.trace {
    result = result * 37 + event.time * 3 + event.entity * 5 + event.payload
  }
  result
}

///|
/// Return a trace summary.
pub fn QueueSimulation::describe(self : QueueSimulation) -> String {
  "entities=\{self.entities.length()}, completed=\{self.completed}, wait=\{self.total_wait}, utilization=\{self.utilization()}%"
}

///|
/// Build a deterministic burst-arrival queue.
pub fn burst_queue(
  count : Int,
  spacing : Int,
  service : Int,
  horizon : Int,
) -> QueueSimulation? {
  let entities : Array[SimulationEntity] = []
  for id in 0..<count {
    entities.push(simulation_entity(id, id * spacing, service, 0))
  }
  queue_simulation(horizon, entities)
}

///|
/// Return the maximum queue length observed in a trace.
pub fn queue_length_trace(simulation : QueueSimulation) -> Int {
  let mut arrivals = 0
  let mut finishes = 0
  let mut maximum = 0
  for event in simulation.trace {
    match event.kind {
      Arrival => arrivals += 1
      ServiceFinish => finishes += 1
      _ => ()
    }
    if arrivals - finishes > maximum {
      maximum = arrivals - finishes
    }
  }
  maximum
}

///|
/// Return whether every event timestamp is nondecreasing.
pub fn trace_is_ordered(simulation : QueueSimulation) -> Bool {
  for index in 1..<simulation.trace.length() {
    if event_before(simulation.trace[index], simulation.trace[index - 1]) {
      return false
    }
  }
  true
}
