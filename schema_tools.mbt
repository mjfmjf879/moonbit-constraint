///|
/// Schema helpers for named finite-domain models.
///
/// A schema is a stable, serializable view of variables and defaults. It is
/// useful for CLI forms, configuration validation, and checking that a saved
/// solution still matches the model shape after a library upgrade.
pub struct SchemaField {
  id : Int
  name : String
  lower : Int
  upper : Int
  default : Int
}

///|
/// Create a field.
pub fn schema_field(
  id : Int,
  name : String,
  lower : Int,
  upper : Int,
  default : Int,
) -> SchemaField {
  { id, name, lower, upper, default }
}

///|
/// Return whether the field is valid.
pub fn SchemaField::valid(self : SchemaField) -> Bool {
  self.id >= 0 &&
  self.name.trim() != "" &&
  self.lower <= self.upper &&
  self.default >= self.lower &&
  self.default <= self.upper
}

///|
/// Return its finite domain.
pub fn SchemaField::domain(self : SchemaField) -> Domain {
  domain(self.lower, self.upper)
}

///|
/// A model schema.
pub struct ModelSchema {
  name : String
  fields : Array[SchemaField]
}

///|
/// Create an empty schema.
pub fn model_schema(name : String) -> ModelSchema {
  { name, fields: [] }
}

///|
/// Add a field if its id and name are unique.
pub fn ModelSchema::add(self : ModelSchema, field : SchemaField) -> Bool {
  if !field.valid() || field.id != self.fields.length() {
    return false
  }
  for current in self.fields {
    if current.name == field.name {
      return false
    }
  }
  self.fields.push(field)
  true
}

///|
/// Return schema field count.
pub fn ModelSchema::length(self : ModelSchema) -> Int {
  self.fields.length()
}

///|
/// Read a field.
pub fn ModelSchema::field(self : ModelSchema, id : Int) -> SchemaField {
  if id < 0 || id >= self.fields.length() {
    abort("schema field is outside the schema")
  }
  self.fields[id]
}

///|
/// Find a field by name.
pub fn ModelSchema::find(self : ModelSchema, name : String) -> SchemaField? {
  for field in self.fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}

///|
/// Return default values.
pub fn ModelSchema::defaults(self : ModelSchema) -> Array[Int] {
  self.fields.map(field => field.default)
}

///|
/// Return field names.
pub fn ModelSchema::names(self : ModelSchema) -> Array[String] {
  self.fields.map(field => field.name)
}

///|
/// Validate values against the schema.
pub fn ModelSchema::validate(
  self : ModelSchema,
  values : Array[Int],
) -> ValidationReport {
  let report = validation_report()
  if values.length() != self.fields.length() {
    report.error("schema-length", "values", "value count differs from schema")
    return report
  }
  for index, field in self.fields {
    ignore(
      validate_range(
        report,
        "values[\{index}]",
        values[index],
        field.lower,
        field.upper,
      ),
    )
  }
  report
}

///|
/// Return a schema report.
pub fn ModelSchema::report(self : ModelSchema) -> ValidationReport {
  let report = validation_report()
  if self.name.trim() == "" {
    report.error("schema-name", "name", "schema name is blank")
  }
  let names : Array[String] = []
  for field in self.fields {
    if !field.valid() {
      report.error(
        "field-invalid",
        "fields[\{field.id}]",
        "field definition is invalid",
      )
    }
    names.push(field.name)
  }
  ignore(validate_names(report, "fields", names))
  report
}

///|
/// Render a schema as CSV.
pub fn ModelSchema::csv(self : ModelSchema) -> String {
  let builder = StringBuilder()
  for index, field in self.fields {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(
      "\{field.id},\{field.name},\{field.lower},\{field.upper},\{field.default}",
    )
  }
  builder.to_string()
}

///|
/// Return an assignment difference from defaults.
pub fn ModelSchema::changed_defaults(
  self : ModelSchema,
  values : Array[Int],
) -> Array[(Int, Int, Int)] {
  let result : Array[(Int, Int, Int)] = []
  let defaults = self.defaults()
  let limit = if values.length() < defaults.length() {
    values.length()
  } else {
    defaults.length()
  }
  for index in 0..<limit {
    if values[index] != defaults[index] {
      result.push((index, defaults[index], values[index]))
    }
  }
  result
}

///|
/// Return a stable schema signature.
pub fn ModelSchema::signature(self : ModelSchema) -> Int {
  let mut result = 31
  for field in self.fields {
    result = result * 37 +
      field.id * 3 +
      field.lower * 5 +
      field.upper * 7 +
      field.default
  }
  result
}

///|
/// Return the Cartesian size capped at a limit.
pub fn ModelSchema::cartesian_size(self : ModelSchema, limit : Int) -> Int {
  let cap = if limit < 1 { 1 } else { limit }
  let mut result = 1
  for field in self.fields {
    result *= field.upper - field.lower + 1
    if result >= cap {
      return cap
    }
  }
  result
}

///|
/// Return whether two schemas have the same field shape.
pub fn schemas_compatible(left : ModelSchema, right : ModelSchema) -> Bool {
  if left.fields.length() != right.fields.length() {
    return false
  }
  for index in 0..<left.fields.length() {
    if left.fields[index].name != right.fields[index].name ||
      left.fields[index].lower != right.fields[index].lower ||
      left.fields[index].upper != right.fields[index].upper {
      return false
    }
  }
  true
}

///|
/// Return a schema summary.
pub fn ModelSchema::describe(self : ModelSchema) -> String {
  "name=\{self.name}, fields=\{self.fields.length()}, combinations=\{self.cartesian_size(1000000)}, valid=\{self.report().valid()}"
}
