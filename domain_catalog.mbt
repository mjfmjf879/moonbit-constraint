///|
/// Domain catalogs for application-level variable schemas.
///
/// A catalog gives names, domains, tags, and simple filtering operations to
/// data-driven model builders. It preserves the finite-domain core while
/// allowing CLI and configuration layers to inspect variables without
/// depending on solver internals.
pub struct DomainEntry {
  id : Int
  name : String
  domain : Domain
  tag : String
}

///|
/// Create a domain entry.
pub fn domain_entry(
  id : Int,
  name : String,
  value_domain : Domain,
  tag : String,
) -> DomainEntry {
  { id, name, domain: value_domain, tag }
}

///|
/// A named domain catalog.
pub struct DomainCatalog {
  entries : Array[DomainEntry]
}

///|
/// Create an empty catalog.
pub fn domain_catalog() -> DomainCatalog {
  { entries: [] }
}

///|
/// Add a unique entry.
pub fn DomainCatalog::add(
  self : DomainCatalog,
  name : String,
  value_domain : Domain,
  tag : String,
) -> Int? {
  for entry in self.entries {
    if entry.name == name {
      return None
    }
  }
  let id = self.entries.length()
  self.entries.push(domain_entry(id, name, value_domain.clone(), tag))
  Some(id)
}

///|
/// Return catalog length.
pub fn DomainCatalog::length(self : DomainCatalog) -> Int {
  self.entries.length()
}

///|
/// Read an entry.
pub fn DomainCatalog::entry(self : DomainCatalog, id : Int) -> DomainEntry {
  if id < 0 || id >= self.entries.length() {
    abort("domain catalog entry is outside the catalog")
  }
  self.entries[id]
}

///|
/// Find an entry by name.
pub fn DomainCatalog::find(self : DomainCatalog, name : String) -> DomainEntry? {
  for entry in self.entries {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// Return copied entries.
pub fn DomainCatalog::entries(self : DomainCatalog) -> Array[DomainEntry] {
  self.entries.copy()
}

///|
/// Return entries with a tag.
pub fn DomainCatalog::with_tag(
  self : DomainCatalog,
  tag : String,
) -> Array[Int] {
  let result : Array[Int] = []
  for entry in self.entries {
    if entry.tag == tag {
      result.push(entry.id)
    }
  }
  result
}

///|
/// Return all names.
pub fn DomainCatalog::names(self : DomainCatalog) -> Array[String] {
  self.entries.map(entry => entry.name)
}

///|
/// Return all domain sizes.
pub fn DomainCatalog::sizes(self : DomainCatalog) -> Array[Int] {
  self.entries.map(entry => entry.domain.size())
}

///|
/// Return the total Cartesian size capped at a limit.
pub fn DomainCatalog::cartesian_size(self : DomainCatalog, limit : Int) -> Int {
  let cap = if limit < 1 { 1 } else { limit }
  let mut result = 1
  for entry in self.entries {
    result *= entry.domain.size()
    if result >= cap {
      return cap
    }
  }
  result
}

///|
/// Remove a value from one catalog entry.
pub fn DomainCatalog::remove(
  self : DomainCatalog,
  id : Int,
  value : Int,
) -> Bool {
  if id < 0 || id >= self.entries.length() {
    return false
  }
  self.entries[id].domain.remove(value)
}

///|
/// Restrict one domain to an interval.
pub fn DomainCatalog::intersect_range(
  self : DomainCatalog,
  id : Int,
  lower : Int,
  upper : Int,
) -> Bool {
  if id < 0 || id >= self.entries.length() {
    return false
  }
  self.entries[id].domain.intersect_range(lower, upper)
}

///|
/// Restrict one domain to an explicit set.
pub fn DomainCatalog::intersect_values(
  self : DomainCatalog,
  id : Int,
  values : Array[Int],
) -> Bool {
  if id < 0 || id >= self.entries.length() {
    return false
  }
  self.entries[id].domain.intersect_values(values)
}

///|
/// Return empty-domain entries.
pub fn DomainCatalog::empty_entries(self : DomainCatalog) -> Array[Int] {
  let result : Array[Int] = []
  for entry in self.entries {
    if entry.domain.is_empty() {
      result.push(entry.id)
    }
  }
  result
}

///|
/// Return singleton entries.
pub fn DomainCatalog::singleton_entries(
  self : DomainCatalog,
) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  for entry in self.entries {
    match entry.domain.singleton() {
      Some(value) => result.push((entry.id, value))
      None => ()
    }
  }
  result
}

///|
/// Return a catalog of cloned domains.
pub fn DomainCatalog::clone(self : DomainCatalog) -> DomainCatalog {
  let result = domain_catalog()
  for entry in self.entries {
    ignore(result.add(entry.name, entry.domain.clone(), entry.tag))
  }
  result
}

///|
/// Return whether every domain is non-empty.
pub fn DomainCatalog::consistent(self : DomainCatalog) -> Bool {
  self.empty_entries().length() == 0
}

///|
/// Return the number of available values.
pub fn DomainCatalog::available_values(self : DomainCatalog) -> Int {
  let mut result = 0
  for entry in self.entries {
    result += entry.domain.size()
  }
  result
}

///|
/// Return domains with at most a threshold number of values.
pub fn DomainCatalog::most_constrained(
  self : DomainCatalog,
  threshold : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for entry in self.entries {
    if entry.domain.size() <= threshold {
      result.push(entry.id)
    }
  }
  result
}

///|
/// Return a compact catalog description.
pub fn DomainCatalog::describe(self : DomainCatalog) -> String {
  let builder = StringBuilder()
  for index, entry in self.entries {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(
      "\{entry.id}:\{entry.name}[\{entry.domain.describe()}]/\{entry.tag}",
    )
  }
  builder.to_string()
}

///|
/// Return a catalog fingerprint.
pub fn DomainCatalog::signature(self : DomainCatalog) -> Int {
  let mut result = 31
  for entry in self.entries {
    result = result * 37 + entry.id + entry.domain.size() * 7
    for character in entry.name {
      result = result * 41 + character.to_int()
    }
  }
  result
}

///|
/// Return the union of all values in tagged entries.
pub fn DomainCatalog::tagged_values(
  self : DomainCatalog,
  tag : String,
) -> IntegerSet {
  let values : Array[Int] = []
  for entry in self.entries {
    if entry.tag == tag {
      for value in entry.domain.values() {
        values.push(value)
      }
    }
  }
  integer_set(values)
}

///|
/// Return the smallest enclosing interval for tagged domains.
pub fn DomainCatalog::tagged_bounds(
  self : DomainCatalog,
  tag : String,
) -> (Int, Int)? {
  let values = self.tagged_values(tag).values()
  if values.length() == 0 {
    return None
  }
  Some((values[0], values[values.length() - 1]))
}

///|
/// Return the number of holes across all domains.
pub fn DomainCatalog::hole_count(self : DomainCatalog) -> Int {
  let mut result = 0
  for entry in self.entries {
    result += entry.domain.removed_count()
  }
  result
}

///|
/// Return a copy with every domain intersected by a shared interval.
pub fn DomainCatalog::restrict_all(
  self : DomainCatalog,
  lower : Int,
  upper : Int,
) -> Int {
  let mut changed = 0
  for entry in self.entries {
    if entry.domain.intersect_range(lower, upper) {
      changed += 1
    }
  }
  changed
}
