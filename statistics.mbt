///|
/// Integer statistics for deterministic solver and application telemetry.
///
/// Metrics avoid floating-point dependence so benchmark snapshots remain
/// reproducible across native, wasm, and wasm-gc targets. Percentage and
/// correlation helpers use explicit scale factors documented by their names.
pub struct IntegerSummary {
  count : Int
  total : Int
  minimum : Int
  maximum : Int
  median : Int
  mean : Int
}

///|
/// Summarize an integer sample.
pub fn integer_summary(values : Array[Int]) -> IntegerSummary {
  if values.length() == 0 {
    return { count: 0, total: 0, minimum: 0, maximum: 0, median: 0, mean: 0 }
  }
  let sorted = values.copy()
  sort_integers(sorted)
  let mut total = 0
  for value in sorted {
    total += value
  }
  {
    count: sorted.length(),
    total,
    minimum: sorted[0],
    maximum: sorted[sorted.length() - 1],
    median: sorted[sorted.length() / 2],
    mean: total / sorted.length(),
  }
}

///|
/// Read sample count.
pub fn IntegerSummary::count(self : IntegerSummary) -> Int {
  self.count
}

///|
/// Read total.
pub fn IntegerSummary::total(self : IntegerSummary) -> Int {
  self.total
}

///|
/// Read minimum.
pub fn IntegerSummary::minimum(self : IntegerSummary) -> Int {
  self.minimum
}

///|
/// Read maximum.
pub fn IntegerSummary::maximum(self : IntegerSummary) -> Int {
  self.maximum
}

///|
/// Read median.
pub fn IntegerSummary::median(self : IntegerSummary) -> Int {
  self.median
}

///|
/// Read integer mean.
pub fn IntegerSummary::mean(self : IntegerSummary) -> Int {
  self.mean
}

///|
/// Return a stable summary line.
pub fn IntegerSummary::describe(self : IntegerSummary) -> String {
  "count=\{self.count}, total=\{self.total}, min=\{self.minimum}, max=\{self.maximum}, median=\{self.median}, mean=\{self.mean}"
}

///|
/// Sort an integer array in ascending order.
pub fn sort_integers(values : Array[Int]) -> Unit {
  for left in 0..<values.length() {
    for right in (left + 1)..<values.length() {
      if values[right] < values[left] {
        let temporary = values[left]
        values[left] = values[right]
        values[right] = temporary
      }
    }
  }
}

///|
/// Return the sum of a sample.
pub fn integer_sum(values : Array[Int]) -> Int {
  let mut result = 0
  for value in values {
    result += value
  }
  result
}

///|
/// Return the integer mean or zero for an empty sample.
pub fn integer_mean(values : Array[Int]) -> Int {
  if values.length() == 0 {
    0
  } else {
    integer_sum(values) / values.length()
  }
}

///|
/// Return population variance using integer division.
pub fn integer_variance(values : Array[Int]) -> Int {
  if values.length() == 0 {
    return 0
  }
  let mean = integer_mean(values)
  let mut total = 0
  for value in values {
    let delta = value - mean
    total += delta * delta
  }
  total / values.length()
}

///|
/// Return an integer square root.
pub fn integer_sqrt(value : Int) -> Int {
  if value <= 0 {
    return 0
  }
  let mut low = 1
  let mut high = if value < 46340 * 46340 { value } else { 46340 }
  let mut result = 0
  while low <= high {
    let middle = (low + high) / 2
    if middle <= value / middle {
      result = middle
      low = middle + 1
    } else {
      high = middle - 1
    }
  }
  result
}

///|
/// Return population standard deviation as an integer.
pub fn integer_stddev(values : Array[Int]) -> Int {
  integer_sqrt(integer_variance(values))
}

///|
/// Return a percentile using nearest-rank selection.
pub fn integer_percentile(values : Array[Int], percent : Int) -> Int? {
  if values.length() == 0 || percent < 0 || percent > 100 {
    return None
  }
  let sorted = values.copy()
  sort_integers(sorted)
  let index = percent * (sorted.length() - 1) / 100
  Some(sorted[index])
}

///|
/// Return the median of a sample.
pub fn integer_median(values : Array[Int]) -> Int? {
  integer_percentile(values, 50)
}

///|
/// Return the mode, choosing the smallest value on ties.
pub fn integer_mode(values : Array[Int]) -> Int? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sort_integers(sorted)
  let mut best = sorted[0]
  let mut best_count = 1
  let mut current = sorted[0]
  let mut current_count = 0
  for value in sorted {
    if value == current {
      current_count += 1
    } else {
      if current_count > best_count {
        best = current
        best_count = current_count
      }
      current = value
      current_count = 1
    }
  }
  if current_count > best_count {
    best = current
  }
  Some(best)
}

///|
/// Return a scaled covariance.
pub fn integer_covariance(
  left : Array[Int],
  right : Array[Int],
  scale : Int,
) -> Int? {
  if left.length() != right.length() || left.length() == 0 || scale <= 0 {
    return None
  }
  let left_mean = integer_mean(left)
  let right_mean = integer_mean(right)
  let mut total = 0
  for index in 0..<left.length() {
    total += (left[index] - left_mean) * (right[index] - right_mean)
  }
  Some(total * scale / left.length())
}

///|
/// Return correlation scaled by 1,000, or None when undefined.
pub fn integer_correlation(left : Array[Int], right : Array[Int]) -> Int? {
  if left.length() != right.length() || left.length() == 0 {
    return None
  }
  let left_mean = integer_mean(left)
  let right_mean = integer_mean(right)
  let mut numerator = 0
  let mut left_total = 0
  let mut right_total = 0
  for index in 0..<left.length() {
    let left_delta = left[index] - left_mean
    let right_delta = right[index] - right_mean
    numerator += left_delta * right_delta
    left_total += left_delta * left_delta
    right_total += right_delta * right_delta
  }
  if left_total == 0 || right_total == 0 {
    return None
  }
  Some(numerator * 1000 / integer_sqrt(left_total * right_total))
}

///|
/// A histogram with fixed-width integer buckets.
pub struct IntegerHistogram {
  lower : Int
  width : Int
  counts : Array[Int]
}

///|
/// Create a histogram.
pub fn integer_histogram(
  lower : Int,
  width : Int,
  buckets : Int,
) -> IntegerHistogram {
  let counts : Array[Int] = []
  for _ in 0..<buckets {
    counts.push(0)
  }
  { lower, width: if width < 1 { 1 } else { width }, counts }
}

///|
/// Add a value to a histogram when it falls within its buckets.
pub fn IntegerHistogram::add(self : IntegerHistogram, value : Int) -> Bool {
  let index = (value - self.lower) / self.width
  if index < 0 || index >= self.counts.length() {
    return false
  }
  self.counts[index] += 1
  true
}

///|
/// Add all values and return the number accepted.
pub fn IntegerHistogram::add_all(
  self : IntegerHistogram,
  values : Array[Int],
) -> Int {
  let mut result = 0
  for value in values {
    if self.add(value) {
      result += 1
    }
  }
  result
}

///|
/// Return bucket counts.
pub fn IntegerHistogram::counts(self : IntegerHistogram) -> Array[Int] {
  self.counts.copy()
}

///|
/// Return a bucket count.
pub fn IntegerHistogram::bucket(self : IntegerHistogram, index : Int) -> Int {
  if index < 0 || index >= self.counts.length() {
    0
  } else {
    self.counts[index]
  }
}

///|
/// Return total accepted values.
pub fn IntegerHistogram::total(self : IntegerHistogram) -> Int {
  integer_sum(self.counts)
}

///|
/// Return the bucket with the largest count.
pub fn IntegerHistogram::peak(self : IntegerHistogram) -> Int? {
  if self.counts.length() == 0 {
    return None
  }
  let mut result = 0
  for index in 1..<self.counts.length() {
    if self.counts[index] > self.counts[result] {
      result = index
    }
  }
  Some(result)
}

///|
/// Return moving averages with a fixed window.
pub fn moving_average(values : Array[Int], window : Int) -> Array[Int] {
  let result : Array[Int] = []
  if window <= 0 {
    return result
  }
  for index in 0..<values.length() {
    let start = if index + 1 < window { 0 } else { index + 1 - window }
    let mut total = 0
    for current in start..<(index + 1) {
      total += values[current]
    }
    result.push(total / (index - start + 1))
  }
  result
}

///|
/// Return first differences.
pub fn first_differences(values : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  for index in 1..<values.length() {
    result.push(values[index] - values[index - 1])
  }
  result
}

///|
/// Return a simple linear forecast from the last value and average delta.
pub fn linear_forecast(values : Array[Int], steps : Int) -> Array[Int] {
  let result : Array[Int] = []
  if values.length() == 0 || steps <= 0 {
    return result
  }
  let delta = integer_mean(first_differences(values))
  let mut current = values[values.length() - 1]
  for _ in 0..<steps {
    current += delta
    result.push(current)
  }
  result
}

///|
/// Return values outside mean plus or minus k standard deviations.
pub fn integer_outliers(values : Array[Int], deviations : Int) -> Array[Int] {
  let result : Array[Int] = []
  let summary = integer_summary(values)
  let margin = integer_stddev(values) *
    (if deviations < 1 { 1 } else { deviations })
  for value in values {
    if value < summary.mean - margin || value > summary.mean + margin {
      result.push(value)
    }
  }
  result
}

///|
/// A pair of samples for regression.
pub struct IntegerRegression {
  slope_scaled : Int
  intercept : Int
  error : Int
}

///|
/// Fit y = slope*x + intercept with slope scaled by 1,000.
pub fn integer_regression(x : Array[Int], y : Array[Int]) -> IntegerRegression? {
  if x.length() != y.length() || x.length() == 0 {
    return None
  }
  let x_mean = integer_mean(x)
  let y_mean = integer_mean(y)
  let mut numerator = 0
  let mut denominator = 0
  for index in 0..<x.length() {
    numerator += (x[index] - x_mean) * (y[index] - y_mean)
    denominator += (x[index] - x_mean) * (x[index] - x_mean)
  }
  let slope = if denominator == 0 { 0 } else { numerator * 1000 / denominator }
  let intercept = y_mean - slope * x_mean / 1000
  let mut error = 0
  for index in 0..<x.length() {
    let predicted = slope * x[index] / 1000 + intercept
    let difference = y[index] - predicted
    error += difference * difference
  }
  Some({ slope_scaled: slope, intercept, error })
}

///|
/// Read scaled slope.
pub fn IntegerRegression::slope_scaled(self : IntegerRegression) -> Int {
  self.slope_scaled
}

///|
/// Read intercept.
pub fn IntegerRegression::intercept(self : IntegerRegression) -> Int {
  self.intercept
}

///|
/// Read squared error.
pub fn IntegerRegression::error(self : IntegerRegression) -> Int {
  self.error
}

///|
/// Return a benchmark speedup percentage.
pub fn speedup_percent(baseline : Int, candidate : Int) -> Int? {
  if baseline <= 0 {
    return None
  }
  Some((baseline - candidate) * 100 / baseline)
}

///|
/// Return whether a metric regressed beyond a tolerance percentage.
pub fn regressed(
  baseline : Int,
  candidate : Int,
  tolerance_percent : Int,
) -> Bool {
  if baseline <= 0 {
    return candidate > baseline
  }
  candidate > baseline + baseline * tolerance_percent / 100
}
