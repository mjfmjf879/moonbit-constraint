///|
/// Job-shop and machine-sequencing utilities.
///
/// Manufacturing operations are represented as fixed machine assignments with
/// setup and processing durations. The module provides deterministic dispatch
/// rules and validates the resulting Gantt plan before it is used as a solver
/// seed or exported to a shop-floor integration.
pub struct MachineSpec {
  id : Int
  name : String
  capacity : Int
}

///|
/// Create a machine specification.
pub fn machine_spec(id : Int, name : String, capacity : Int) -> MachineSpec {
  { id, name, capacity: if capacity < 1 { 1 } else { capacity } }
}

///|
/// Read machine identifier.
pub fn MachineSpec::id(self : MachineSpec) -> Int {
  self.id
}

///|
/// Read machine capacity.
pub fn MachineSpec::capacity(self : MachineSpec) -> Int {
  self.capacity
}

///|
/// A fixed-machine operation.
pub struct ManufacturingOperation {
  id : Int
  job : Int
  sequence : Int
  machine : Int
  setup : Int
  duration : Int
  family : Int
  due : Int
}

///|
/// Create an operation.
pub fn manufacturing_operation(
  id : Int,
  job : Int,
  sequence : Int,
  machine : Int,
  setup : Int,
  duration : Int,
  family : Int,
  due : Int,
) -> ManufacturingOperation {
  {
    id,
    job,
    sequence,
    machine,
    setup: if setup < 0 {
      0
    } else {
      setup
    },
    duration: if duration < 0 {
      0
    } else {
      duration
    },
    family,
    due,
  }
}

///|
/// Read operation job.
pub fn ManufacturingOperation::job(self : ManufacturingOperation) -> Int {
  self.job
}

///|
/// Read operation sequence.
pub fn ManufacturingOperation::sequence(self : ManufacturingOperation) -> Int {
  self.sequence
}

///|
/// Read assigned machine.
pub fn ManufacturingOperation::machine(self : ManufacturingOperation) -> Int {
  self.machine
}

///|
/// Return setup plus processing duration.
pub fn ManufacturingOperation::total_duration(
  self : ManufacturingOperation,
) -> Int {
  self.setup + self.duration
}

///|
/// A validated manufacturing instance.
pub struct ManufacturingInstance {
  machines : Array[MachineSpec]
  operations : Array[ManufacturingOperation]
  setup_matrix : Array[Array[Int]]
}

///|
/// Build an instance with a family-to-family setup matrix.
pub fn manufacturing_instance(
  machines : Array[MachineSpec],
  operations : Array[ManufacturingOperation],
  setup_matrix : Array[Array[Int]],
) -> ManufacturingInstance? {
  if machines.length() == 0 || setup_matrix.length() != machines.length() {
    return None
  }
  for row in setup_matrix {
    if row.length() != machines.length() {
      return None
    }
  }
  for index, machine in machines {
    if machine.id != index || machine.capacity < 1 {
      return None
    }
  }
  for index, operation in operations {
    if operation.id != index ||
      operation.machine < 0 ||
      operation.machine >= machines.length() ||
      operation.job < 0 ||
      operation.sequence < 0 ||
      operation.setup < 0 ||
      operation.duration < 0 {
      return None
    }
  }
  Some({
    machines: machines.copy(),
    operations: operations.copy(),
    setup_matrix: setup_matrix.map(row => row.copy()),
  })
}

///|
/// Return operation count.
pub fn ManufacturingInstance::operation_count(
  self : ManufacturingInstance,
) -> Int {
  self.operations.length()
}

///|
/// Return machine count.
pub fn ManufacturingInstance::machine_count(
  self : ManufacturingInstance,
) -> Int {
  self.machines.length()
}

///|
/// Read an operation.
pub fn ManufacturingInstance::operation(
  self : ManufacturingInstance,
  id : Int,
) -> ManufacturingOperation {
  if id < 0 || id >= self.operations.length() {
    abort("manufacturing operation is outside the instance")
  }
  self.operations[id]
}

///|
/// Read a machine.
pub fn ManufacturingInstance::machine(
  self : ManufacturingInstance,
  id : Int,
) -> MachineSpec {
  if id < 0 || id >= self.machines.length() {
    abort("manufacturing machine is outside the instance")
  }
  self.machines[id]
}

///|
/// A concrete operation start schedule.
pub struct ManufacturingSchedule {
  starts : Array[Int]
  machine_order : Array[Array[Int]]
}

///|
/// Create an empty schedule.
pub fn manufacturing_schedule(
  instance : ManufacturingInstance,
) -> ManufacturingSchedule {
  let starts : Array[Int] = []
  for _ in instance.operations {
    starts.push(-1)
  }
  let machine_order : Array[Array[Int]] = []
  for _ in instance.machines {
    machine_order.push([])
  }
  { starts, machine_order }
}

///|
/// Set an operation start time.
pub fn ManufacturingSchedule::set_start(
  self : ManufacturingSchedule,
  operation : Int,
  start : Int,
) -> Bool {
  if operation < 0 || operation >= self.starts.length() || start < 0 {
    return false
  }
  self.starts[operation] = start
  true
}

///|
/// Add an operation to a machine sequence.
pub fn ManufacturingSchedule::queue(
  self : ManufacturingSchedule,
  machine : Int,
  operation : Int,
) -> Bool {
  if machine < 0 ||
    machine >= self.machine_order.length() ||
    operation < 0 ||
    operation >= self.starts.length() ||
    self.machine_order[machine].contains(operation) {
    return false
  }
  self.machine_order[machine].push(operation)
  true
}

///|
/// Read an operation start.
pub fn ManufacturingSchedule::start(
  self : ManufacturingSchedule,
  operation : Int,
) -> Int {
  if operation < 0 || operation >= self.starts.length() {
    return -1
  }
  self.starts[operation]
}

///|
/// Return machine sequence.
pub fn ManufacturingSchedule::machine_sequence(
  self : ManufacturingSchedule,
  machine : Int,
) -> Array[Int] {
  if machine < 0 || machine >= self.machine_order.length() {
    return []
  }
  self.machine_order[machine].copy()
}

///|
/// Return a copied start array.
pub fn ManufacturingSchedule::starts(
  self : ManufacturingSchedule,
) -> Array[Int] {
  self.starts.copy()
}

///|
/// Return operation finish time.
pub fn operation_finish(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
  operation : Int,
) -> Int {
  if operation < 0 || operation >= instance.operations.length() {
    return -1
  }
  schedule.start(operation) + instance.operations[operation].total_duration()
}

///|
/// Return the last operation of a job.
pub fn last_job_operation(instance : ManufacturingInstance, job : Int) -> Int? {
  let mut result : Int? = None
  let mut sequence = -1
  for operation in instance.operations {
    if operation.job == job && operation.sequence > sequence {
      result = Some(operation.id)
      sequence = operation.sequence
    }
  }
  result
}

///|
/// Return operation ids for a job in process order.
pub fn job_operations(
  instance : ManufacturingInstance,
  job : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for operation in instance.operations {
    if operation.job == job {
      result.push(operation.id)
    }
  }
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      if instance.operations[result[right]].sequence <
        instance.operations[result[left]].sequence {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Return all job identifiers in ascending order.
pub fn manufacturing_jobs(instance : ManufacturingInstance) -> Array[Int] {
  let result : Array[Int] = []
  for operation in instance.operations {
    if !result.contains(operation.job) {
      result.push(operation.job)
    }
  }
  result
}

///|
/// Schedule operations with a deterministic earliest-feasible dispatch.
pub fn dispatch_schedule(
  instance : ManufacturingInstance,
) -> ManufacturingSchedule {
  let schedule = manufacturing_schedule(instance)
  let remaining : Array[Int] = []
  for operation in instance.operations {
    remaining.push(operation.id)
  }
  let machine_ready : Array[Int] = []
  for _ in instance.machines {
    machine_ready.push(0)
  }
  while remaining.length() > 0 {
    let mut selected_index = 0
    let mut selected_due = 2147483647
    for index, operation_id in remaining {
      let operation = instance.operations[operation_id]
      if operation.due < selected_due {
        selected_index = index
        selected_due = operation.due
      }
    }
    let operation_id = remaining[selected_index]
    ignore(remove_manufacturing_value(remaining, operation_id))
    let operation = instance.operations[operation_id]
    let mut ready = machine_ready[operation.machine]
    for predecessor in job_operations(instance, operation.job) {
      if instance.operations[predecessor].sequence < operation.sequence &&
        schedule.start(predecessor) >= 0 {
        let finish = operation_finish(instance, schedule, predecessor)
        if finish > ready {
          ready = finish
        }
      }
    }
    ignore(schedule.set_start(operation_id, ready))
    ignore(schedule.queue(operation.machine, operation_id))
    machine_ready[operation.machine] = ready + operation.total_duration()
  }
  schedule
}

///|
/// Remove a value from an integer array.
fn remove_manufacturing_value(values : Array[Int], value : Int) -> Bool {
  let mut index = 0
  while index < values.length() {
    if values[index] == value {
      while index + 1 < values.length() {
        values[index] = values[index + 1]
        index += 1
      }
      ignore(values.pop())
      return true
    }
    index += 1
  }
  false
}

///|
/// Validate precedence, machine order, and due dates.
pub fn validate_manufacturing_schedule(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Array[String] {
  let errors : Array[String] = []
  for operation in instance.operations {
    if schedule.start(operation.id) < 0 {
      errors.push("unscheduled-\{operation.id}")
    }
    if operation.due != 2147483647 &&
      operation_finish(instance, schedule, operation.id) > operation.due {
      errors.push("due-\{operation.id}")
    }
  }
  for job in manufacturing_jobs(instance) {
    let operations = job_operations(instance, job)
    for index in 1..<operations.length() {
      let predecessor = operations[index - 1]
      let current = operations[index]
      if schedule.start(current) <
        operation_finish(instance, schedule, predecessor) {
        errors.push("precedence-\{predecessor}-\{current}")
      }
    }
  }
  for machine in 0..<instance.machines.length() {
    let order = schedule.machine_order[machine]
    for left in 0..<order.length() {
      for right in (left + 1)..<order.length() {
        let first = order[left]
        let second = order[right]
        if intervals_overlap(
            schedule.start(first),
            operation_finish(instance, schedule, first),
            schedule.start(second),
            operation_finish(instance, schedule, second),
          ) {
          errors.push("overlap-\{machine}-\{first}-\{second}")
        }
      }
    }
  }
  errors
}

///|
/// Return whether a schedule is valid.
pub fn manufacturing_feasible(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Bool {
  validate_manufacturing_schedule(instance, schedule).length() == 0
}

///|
/// Test two half-open intervals for overlap.
fn intervals_overlap(
  first_start : Int,
  first_end : Int,
  second_start : Int,
  second_end : Int,
) -> Bool {
  first_start < second_end && second_start < first_end
}

///|
/// Return the makespan.
pub fn manufacturing_makespan(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Int {
  let mut result = 0
  for operation in instance.operations {
    let finish = operation_finish(instance, schedule, operation.id)
    if finish > result {
      result = finish
    }
  }
  result
}

///|
/// Return machine busy time.
pub fn machine_busy_time(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
  machine : Int,
) -> Int {
  ignore(schedule)
  let mut result = 0
  if machine < 0 || machine >= instance.machines.length() {
    return 0
  }
  for operation in instance.operations {
    if operation.machine == machine {
      result += operation.total_duration()
    }
  }
  result
}

///|
/// Return machine utilization as an integer percentage.
pub fn machine_utilization(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
  machine : Int,
) -> Int {
  let makespan = manufacturing_makespan(instance, schedule)
  if makespan == 0 || machine < 0 || machine >= instance.machines.length() {
    return 0
  }
  machine_busy_time(instance, schedule, machine) *
  100 /
  (makespan * instance.machines[machine].capacity)
}

///|
/// Return the total processing work.
pub fn manufacturing_work(instance : ManufacturingInstance) -> Int {
  let mut result = 0
  for operation in instance.operations {
    result += operation.duration
  }
  result
}

///|
/// Return the total setup work.
pub fn manufacturing_setup_work(instance : ManufacturingInstance) -> Int {
  let mut result = 0
  for operation in instance.operations {
    result += operation.setup
  }
  result
}

///|
/// Return the total tardiness.
pub fn manufacturing_tardiness(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Int {
  let mut result = 0
  for operation in instance.operations {
    if operation.due != 2147483647 {
      let tardiness = operation_finish(instance, schedule, operation.id) -
        operation.due
      if tardiness > 0 {
        result += tardiness
      }
    }
  }
  result
}

///|
/// Return the critical operation ids by finish time.
pub fn critical_operations(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Array[Int] {
  let makespan = manufacturing_makespan(instance, schedule)
  let result : Array[Int] = []
  for operation in instance.operations {
    if operation_finish(instance, schedule, operation.id) == makespan {
      result.push(operation.id)
    }
  }
  result
}

///|
/// Return all operation ids for a machine in schedule order.
pub fn machine_operations(
  instance : ManufacturingInstance,
  machine : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for operation in instance.operations {
    if operation.machine == machine {
      result.push(operation.id)
    }
  }
  result
}

///|
/// Return setup time between two operation families on a machine.
pub fn setup_time(
  instance : ManufacturingInstance,
  machine : Int,
  from_family : Int,
  to_family : Int,
) -> Int {
  if machine < 0 ||
    machine >= instance.setup_matrix.length() ||
    from_family < 0 ||
    to_family < 0 ||
    from_family >= instance.setup_matrix[machine].length() ||
    to_family >= instance.setup_matrix[machine].length() {
    return 0
  }
  instance.setup_matrix[from_family][to_family]
}

///|
/// Return operations ordered by earliest due date.
pub fn due_date_order(instance : ManufacturingInstance) -> Array[Int] {
  let result : Array[Int] = []
  for operation in instance.operations {
    result.push(operation.id)
  }
  for left in 0..<result.length() {
    for right in (left + 1)..<result.length() {
      let first = instance.operations[result[left]]
      let second = instance.operations[result[right]]
      if second.due < first.due {
        let temporary = result[left]
        result[left] = result[right]
        result[right] = temporary
      }
    }
  }
  result
}

///|
/// Render a schedule as a stable Gantt summary.
pub fn manufacturing_render(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> String {
  let builder = StringBuilder()
  for machine in 0..<instance.machines.length() {
    if machine > 0 {
      builder.write_char('\n')
    }
    builder.write_string("machine \{machine}:")
    for operation in schedule.machine_order[machine] {
      builder.write_string(
        " \{operation}@\{schedule.start(operation)}+\{instance.operations[operation].total_duration()}",
      )
    }
  }
  builder.to_string()
}

///|
/// Return a stable manufacturing fingerprint.
pub fn manufacturing_signature(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Int {
  let mut result = instance.operations.length() * 31 +
    instance.machines.length()
  for operation in instance.operations {
    result = result * 37 +
      operation.machine * 5 +
      operation.duration * 7 +
      schedule.start(operation.id)
  }
  result
}

///|
/// Return jobs whose final operation is late.
pub fn late_jobs(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Array[Int] {
  let result : Array[Int] = []
  for job in manufacturing_jobs(instance) {
    match last_job_operation(instance, job) {
      Some(operation) => {
        let due = instance.operations[operation].due
        if due != 2147483647 &&
          operation_finish(instance, schedule, operation) > due {
          result.push(job)
        }
      }
      None => ()
    }
  }
  result
}

///|
/// Return the number of setup transitions in a machine sequence.
pub fn machine_setup_transitions(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
  machine : Int,
) -> Int {
  if machine < 0 || machine >= schedule.machine_order.length() {
    return 0
  }
  let order = schedule.machine_order[machine]
  let mut result = 0
  for index in 1..<order.length() {
    if instance.operations[order[index - 1]].family !=
      instance.operations[order[index]].family {
      result += 1
    }
  }
  result
}

///|
/// Return a scalar schedule objective.
pub fn manufacturing_objective(
  instance : ManufacturingInstance,
  schedule : ManufacturingSchedule,
) -> Int {
  manufacturing_makespan(instance, schedule) +
  manufacturing_tardiness(instance, schedule) * 1000 +
  validate_manufacturing_schedule(instance, schedule).length() * 1000000
}
