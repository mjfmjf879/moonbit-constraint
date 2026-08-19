///|
/// Dependency-free text and delimited-data utilities.
///
/// Model files and benchmark artifacts often need a tiny parser but should not
/// pull an IO or JSON dependency into the core package. These routines cover
/// stable tokenization, key-value configuration, CSV rows, and redaction.
pub struct TextToken {
  value : String
  line : Int
  column : Int
}

///|
/// Create a token.
pub fn text_token(value : String, line : Int, column : Int) -> TextToken {
  { value, line, column }
}

///|
/// Read token value.
pub fn TextToken::value(self : TextToken) -> String {
  self.value
}

///|
/// Read token line.
pub fn TextToken::line(self : TextToken) -> Int {
  self.line
}

///|
/// Read token column.
pub fn TextToken::column(self : TextToken) -> Int {
  self.column
}

///|
/// Tokenize non-whitespace runs while preserving locations.
pub fn tokenize_text(input : String) -> Array[TextToken] {
  let result : Array[TextToken] = []
  let mut token = ""
  let mut line = 0
  let mut column = 0
  let mut token_line = 0
  let mut token_column = 0
  let flush = () => {
    if token != "" {
      result.push(text_token(token, token_line, token_column))
      token = ""
    }
  }
  for character in input {
    if character == '\n' {
      flush()
      line += 1
      column = 0
    } else if character.is_whitespace() {
      flush()
      column += 1
    } else {
      if token == "" {
        token_line = line
        token_column = column
      }
      token += character.to_string()
      column += 1
    }
  }
  flush()
  result
}

///|
/// A text document with line access.
pub struct TextDocument {
  lines : Array[String]
}

///|
/// Split a document into owned lines.
pub fn text_document(input : String) -> TextDocument {
  let lines : Array[String] = []
  for line in input.split("\n") {
    lines.push(line.to_owned())
  }
  { lines, }
}

///|
/// Return line count.
pub fn TextDocument::line_count(self : TextDocument) -> Int {
  self.lines.length()
}

///|
/// Return one line.
pub fn TextDocument::line(self : TextDocument, index : Int) -> String {
  if index < 0 || index >= self.lines.length() {
    ""
  } else {
    self.lines[index]
  }
}

///|
/// Return copied lines.
pub fn TextDocument::lines(self : TextDocument) -> Array[String] {
  self.lines.copy()
}

///|
/// Return non-empty line numbers.
pub fn TextDocument::nonempty_lines(self : TextDocument) -> Array[Int] {
  let result : Array[Int] = []
  for index, line in self.lines {
    if line.trim() != "" {
      result.push(index)
    }
  }
  result
}

///|
/// Return comment-free lines with a configured prefix.
pub fn TextDocument::without_comments(
  self : TextDocument,
  prefix : String,
) -> Array[String] {
  let result : Array[String] = []
  for line in self.lines {
    if !line.trim().has_prefix(prefix) {
      result.push(line)
    }
  }
  result
}

///|
/// Parse key-value pairs separated by `=`.
pub fn parse_key_values(input : String) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  for line_view in input.split("\n") {
    let raw = line_view.to_owned()
    let line = raw.trim().to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    match text_find_char(line, '=') {
      Some(index) => {
        let key = line[0:index].to_owned().trim().to_owned()
        let value = line[index + 1:].to_owned().trim().to_owned()
        result.push((key, value))
      }
      None => ()
    }
  }
  result
}

///|
/// Find a key in key-value pairs.
pub fn key_value(pairs : Array[(String, String)], key : String) -> String? {
  for pair in pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Parse one CSV row with quoted fields.
pub fn parse_csv_row(input : String) -> Array[String] {
  let result : Array[String] = []
  let mut field = ""
  let mut quoted = false
  for character in input {
    if character == '"' {
      quoted = !quoted
    } else if character == ',' && !quoted {
      result.push(field)
      field = ""
    } else {
      field += character.to_string()
    }
  }
  result.push(field)
  result
}

///|
/// Parse a CSV document.
pub fn parse_csv(input : String) -> Array[Array[String]] {
  let result : Array[Array[String]] = []
  for line in input.split("\n") {
    let owned = line.to_owned()
    if owned.trim() != "" {
      result.push(parse_csv_row(owned))
    }
  }
  result
}

///|
/// Render a CSV row with quote escaping.
pub fn render_csv_row(fields : Array[String]) -> String {
  let builder = StringBuilder()
  for index, field in fields {
    if index > 0 {
      builder.write_char(',')
    }
    let needs_quotes = field.contains(",") ||
      field.contains("\"") ||
      field.contains("\n")
    if needs_quotes {
      builder.write_char('"')
    }
    for character in field {
      if character == '"' {
        builder.write_string("\"\"")
      } else {
        builder.write_char(character)
      }
    }
    if needs_quotes {
      builder.write_char('"')
    }
  }
  builder.to_string()
}

///|
/// Render CSV rows.
pub fn render_csv(rows : Array[Array[String]]) -> String {
  let builder = StringBuilder()
  for index, row in rows {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(render_csv_row(row))
  }
  builder.to_string()
}

///|
/// Return all integer tokens in a document.
pub fn integer_tokens(input : String) -> Array[Int] {
  let result : Array[Int] = []
  for token in tokenize_text(input) {
    match parse_integer_list(token.value) {
      Some(values) => if values.length() == 1 { result.push(values[0]) }
      None => ()
    }
  }
  result
}

///|
/// Replace all occurrences of a substring.
pub fn replace_text(
  input : String,
  target : String,
  replacement : String,
) -> String {
  if target == "" {
    return input
  }
  let builder = StringBuilder()
  let mut start = 0
  while start < input.length() {
    match text_find_substring(input, target, start) {
      Some(index) => {
        builder.write_string(input[start:index].to_owned())
        builder.write_string(replacement)
        start = index + target.length()
      }
      None => {
        builder.write_string(input[start:].to_owned())
        start = input.length()
      }
    }
  }
  builder.to_string()
}

///|
/// Find a character in an owned string.
fn text_find_char(input : String, target : Char) -> Int? {
  for index in 0..<input.length() {
    match input.get_char(index) {
      Some(character) => if character == target { return Some(index) }
      None => return None
    }
  }
  None
}

///|
/// Find a substring at or after an offset.
fn text_find_substring(input : String, target : String, offset : Int) -> Int? {
  if target == "" {
    return Some(offset)
  }
  for index in offset..<input.length() {
    if input[index:].to_owned().has_prefix(target) {
      return Some(index)
    }
  }
  None
}

///|
/// Redact values after configured key prefixes.
pub fn redact_key_values(
  input : String,
  keys : Array[String],
  replacement : String,
) -> String {
  let result : Array[String] = []
  for pair in parse_key_values(input) {
    let mut value = pair.1
    if keys.contains(pair.0) {
      value = replacement
    }
    result.push(pair.0 + "=" + value)
  }
  let builder = StringBuilder()
  for index, line in result {
    if index > 0 {
      builder.write_char('\n')
    }
    builder.write_string(line)
  }
  builder.to_string()
}

///|
/// Return a stable text fingerprint.
pub fn text_signature(input : String) -> Int {
  let mut result = 17
  for character in input {
    result = result * 31 + character.to_int()
  }
  result
}

///|
/// Return whether all lines have a maximum width.
pub fn lines_within_width(input : String, width : Int) -> Bool {
  for line in input.split("\n") {
    if line.length() > width {
      return false
    }
  }
  true
}

///|
/// Return the longest line length.
pub fn longest_line(input : String) -> Int {
  let mut result = 0
  for line in input.split("\n") {
    if line.length() > result {
      result = line.length()
    }
  }
  result
}

///|
/// Return word frequencies in first-seen order.
pub fn word_frequency(input : String) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for token in tokenize_text(input) {
    let mut found = false
    for index, pair in result {
      if pair.0 == token.value {
        result[index] = (pair.0, pair.1 + 1)
        found = true
      }
    }
    if !found {
      result.push((token.value, 1))
    }
  }
  result
}
