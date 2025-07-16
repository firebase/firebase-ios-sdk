// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

extension Expression {
  func toBridge() -> ExprBridge {
    return (self as! BridgeWrapper).bridge
  }
}

public extension Expression {
  func `as`(_ name: String) -> AliasedExpression {
    return AliasedExpression(self, name)
  }

  // MARK: Arithmetic Operators

  func add(_ value: Expression) -> FunctionExpression {
    return FunctionExpression("add", [self, value])
  }

  func add(_ value: Sendable) -> FunctionExpression {
    return FunctionExpression("add", [self, Helper.sendableToExpr(value)])
  }

  func subtract(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("subtract", [self, other])
  }

  func subtract(_ other: Sendable) -> FunctionExpression {
    return FunctionExpression("subtract", [self, Helper.sendableToExpr(other)])
  }

  func multiply(_ value: Expression) -> FunctionExpression {
    return FunctionExpression("multiply", [self, value])
  }

  func multiply(_ value: Sendable) -> FunctionExpression {
    return FunctionExpression("multiply", [self, Helper.sendableToExpr(value)])
  }

  func divide(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("divide", [self, other])
  }

  func divide(_ other: Sendable) -> FunctionExpression {
    return FunctionExpression("divide", [self, Helper.sendableToExpr(other)])
  }

  func mod(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("mod", [self, other])
  }

  func mod(_ other: Sendable) -> FunctionExpression {
    return FunctionExpression("mod", [self, Helper.sendableToExpr(other)])
  }

  // MARK: Array Operations

  func arrayConcat(_ arrays: [Expression]) -> FunctionExpression {
    return FunctionExpression("array_concat", [self] + arrays)
  }

  func arrayConcat(_ arrays: [[Sendable]]) -> FunctionExpression {
    let exprs = [self] + arrays.map { Helper.sendableToExpr($0) }
    return FunctionExpression("array_concat", exprs)
  }

  func arrayContains(_ element: Expression) -> BooleanExpression {
    return BooleanExpression("array_contains", [self, element])
  }

  func arrayContains(_ element: Sendable) -> BooleanExpression {
    return BooleanExpression("array_contains", [self, Helper.sendableToExpr(element)])
  }

  func arrayContainsAll(_ values: [Expression]) -> BooleanExpression {
    return BooleanExpression("array_contains_all", [self, Helper.array(values)])
  }

  func arrayContainsAll(_ values: [Sendable]) -> BooleanExpression {
    return BooleanExpression("array_contains_all", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Expression]) -> BooleanExpression {
    return BooleanExpression("array_contains_any", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpression {
    return BooleanExpression("array_contains_any", [self, Helper.array(values)])
  }

  func arrayLength() -> FunctionExpression {
    return FunctionExpression("array_length", [self])
  }

  func arrayGet(_ offset: Int) -> FunctionExpression {
    return FunctionExpression("array_get", [self, Helper.sendableToExpr(offset)])
  }

  func arrayGet(_ offsetExpr: Expression) -> FunctionExpression {
    return FunctionExpression("array_get", [self, offsetExpr])
  }

  func greaterThan(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("gt", [self, other])
  }

  func greaterThan(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("gt", [self, exprOther])
  }

  func greaterThanOrEqualTo(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("gte", [self, other])
  }

  func greaterThanOrEqualTo(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("gte", [self, exprOther])
  }

  func lessThan(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("lt", [self, other])
  }

  func lessThan(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("lt", [self, exprOther])
  }

  func lessThanOrEqualTo(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("lte", [self, other])
  }

  func lessThanOrEqualTo(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("lte", [self, exprOther])
  }

  func equal(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("eq", [self, other])
  }

  func equal(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("eq", [self, exprOther])
  }

  func notEqual(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("neq", [self, other])
  }

  func notEqual(_ other: Sendable) -> BooleanExpression {
    return BooleanExpression("neq", [self, Helper.sendableToExpr(other)])
  }

  func eqAny(_ others: [Expression]) -> BooleanExpression {
    return BooleanExpression("eq_any", [self, Helper.array(others)])
  }

  func eqAny(_ others: [Sendable]) -> BooleanExpression {
    return BooleanExpression("eq_any", [self, Helper.array(others)])
  }

  func notEqAny(_ others: [Expression]) -> BooleanExpression {
    return BooleanExpression("not_eq_any", [self, Helper.array(others)])
  }

  func notEqAny(_ others: [Sendable]) -> BooleanExpression {
    return BooleanExpression("not_eq_any", [self, Helper.array(others)])
  }

  // MARK: Checks

  // --- Added Type Check Operations ---

  func isNan() -> BooleanExpression {
    return BooleanExpression("is_nan", [self])
  }

  func isNil() -> BooleanExpression {
    return BooleanExpression("is_null", [self])
  }

  func exists() -> BooleanExpression {
    return BooleanExpression("exists", [self])
  }

  func isError() -> BooleanExpression {
    return BooleanExpression("is_error", [self])
  }

  func isAbsent() -> BooleanExpression {
    return BooleanExpression("is_absent", [self])
  }

  func isNotNil() -> BooleanExpression {
    return BooleanExpression("is_not_null", [self])
  }

  func isNotNan() -> BooleanExpression {
    return BooleanExpression("is_not_nan", [self])
  }

  // --- Added String Operations ---

  func charLength() -> FunctionExpression {
    return FunctionExpression("char_length", [self])
  }

  func like(_ pattern: String) -> BooleanExpression {
    return BooleanExpression("like", [self, Helper.sendableToExpr(pattern)])
  }

  func like(_ pattern: Expression) -> BooleanExpression {
    return BooleanExpression("like", [self, pattern])
  }

  func regexContains(_ pattern: String) -> BooleanExpression {
    return BooleanExpression("regex_contains", [self, Helper.sendableToExpr(pattern)])
  }

  func regexContains(_ pattern: Expression) -> BooleanExpression {
    return BooleanExpression("regex_contains", [self, pattern])
  }

  func regexMatch(_ pattern: String) -> BooleanExpression {
    return BooleanExpression("regex_match", [self, Helper.sendableToExpr(pattern)])
  }

  func regexMatch(_ pattern: Expression) -> BooleanExpression {
    return BooleanExpression("regex_match", [self, pattern])
  }

  func strContains(_ substring: String) -> BooleanExpression {
    return BooleanExpression("str_contains", [self, Helper.sendableToExpr(substring)])
  }

  func strContains(_ expr: Expression) -> BooleanExpression {
    return BooleanExpression("str_contains", [self, expr])
  }

  func startsWith(_ prefix: String) -> BooleanExpression {
    return BooleanExpression("starts_with", [self, Helper.sendableToExpr(prefix)])
  }

  func startsWith(_ prefix: Expression) -> BooleanExpression {
    return BooleanExpression("starts_with", [self, prefix])
  }

  func endsWith(_ suffix: String) -> BooleanExpression {
    return BooleanExpression("ends_with", [self, Helper.sendableToExpr(suffix)])
  }

  func endsWith(_ suffix: Expression) -> BooleanExpression {
    return BooleanExpression("ends_with", [self, suffix])
  }

  func lowercased() -> FunctionExpression {
    return FunctionExpression("to_lower", [self])
  }

  func uppercased() -> FunctionExpression {
    return FunctionExpression("to_upper", [self])
  }

  func trim() -> FunctionExpression {
    return FunctionExpression("trim", [self])
  }

  func strConcat(_ strings: [Expression]) -> FunctionExpression {
    return FunctionExpression("str_concat", [self] + strings)
  }

  func strConcat(_ strings: [String]) -> FunctionExpression {
    let exprs = [self] + strings.map { Helper.sendableToExpr($0) }
    return FunctionExpression("str_concat", exprs)
  }

  func reverse() -> FunctionExpression {
    return FunctionExpression("reverse", [self])
  }

  func replaceFirst(_ find: String, with replace: String) -> FunctionExpression {
    return FunctionExpression(
      "replace_first",
      [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  func replaceFirst(_ find: Expression, with replace: Expression) -> FunctionExpression {
    return FunctionExpression("replace_first", [self, find, replace])
  }

  func replaceAll(_ find: String, with replace: String) -> FunctionExpression {
    return FunctionExpression(
      "replace_all",
      [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  func replaceAll(_ find: Expression, with replace: Expression) -> FunctionExpression {
    return FunctionExpression("replace_all", [self, find, replace])
  }

  func byteLength() -> FunctionExpression {
    return FunctionExpression("byte_length", [self])
  }

  func substr(position: Int, length: Int? = nil) -> FunctionExpression {
    let positionExpr = Helper.sendableToExpr(position)
    if let length = length {
      return FunctionExpression("substr", [self, positionExpr, Helper.sendableToExpr(length)])
    } else {
      return FunctionExpression("substr", [self, positionExpr])
    }
  }

  func substr(position: Expression, length: Expression? = nil) -> FunctionExpression {
    if let length = length {
      return FunctionExpression("substr", [self, position, length])
    } else {
      return FunctionExpression("substr", [self, position])
    }
  }

  // --- Added Map Operations ---

  func mapGet(_ subfield: String) -> FunctionExpression {
    return FunctionExpression("map_get", [self, Constant(subfield)])
  }

  func mapRemove(_ key: String) -> FunctionExpression {
    return FunctionExpression("map_remove", [self, Helper.sendableToExpr(key)])
  }

  func mapRemove(_ keyExpr: Expression) -> FunctionExpression {
    return FunctionExpression("map_remove", [self, keyExpr])
  }

  func mapMerge(_ maps: [[String: Sendable]]) -> FunctionExpression {
    let mapExprs = maps.map { Helper.sendableToExpr($0) }
    return FunctionExpression("map_merge", [self] + mapExprs)
  }

  func mapMerge(_ maps: [Expression]) -> FunctionExpression {
    return FunctionExpression("map_merge", [self] + maps)
  }

  // --- Added Aggregate Operations (on Expr) ---

  func count() -> AggregateFunction {
    return AggregateFunction("count", [self])
  }

  func sum() -> AggregateFunction {
    return AggregateFunction("sum", [self])
  }

  func average() -> AggregateFunction {
    return AggregateFunction("avg", [self])
  }

  func minimum() -> AggregateFunction {
    return AggregateFunction("minimum", [self])
  }

  func maximum() -> AggregateFunction {
    return AggregateFunction("maximum", [self])
  }

  // MARK: Logical min/max

  func logicalMaximum(_ expressions: [Expression]) -> FunctionExpression {
    return FunctionExpression("logical_maximum", [self] + expressions)
  }

  func logicalMaximum(_ values: [Sendable]) -> FunctionExpression {
    let exprs = [self] + values.map { Helper.sendableToExpr($0) }
    return FunctionExpression("logical_maximum", exprs)
  }

  func logicalMinimum(_ expressions: [Expression]) -> FunctionExpression {
    return FunctionExpression("logical_minimum", [self] + expressions)
  }

  func logicalMinimum(_ values: [Sendable]) -> FunctionExpression {
    let exprs = [self] + values.map { Helper.sendableToExpr($0) }
    return FunctionExpression("logical_minimum", exprs)
  }

  // MARK: Vector Operations

  func vectorLength() -> FunctionExpression {
    return FunctionExpression("vector_length", [self])
  }

  func cosineDistance(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("cosine_distance", [self, other])
  }

  func cosineDistance(_ other: VectorValue) -> FunctionExpression {
    return FunctionExpression("cosine_distance", [self, Helper.sendableToExpr(other)])
  }

  func cosineDistance(_ other: [Double]) -> FunctionExpression {
    return FunctionExpression("cosine_distance", [self, Helper.sendableToExpr(other)])
  }

  func dotProduct(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("dot_product", [self, other])
  }

  func dotProduct(_ other: VectorValue) -> FunctionExpression {
    return FunctionExpression("dot_product", [self, Helper.sendableToExpr(other)])
  }

  func dotProduct(_ other: [Double]) -> FunctionExpression {
    return FunctionExpression("dot_product", [self, Helper.sendableToExpr(other)])
  }

  func euclideanDistance(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("euclidean_distance", [self, other])
  }

  func euclideanDistance(_ other: VectorValue) -> FunctionExpression {
    return FunctionExpression("euclidean_distance", [self, Helper.sendableToExpr(other)])
  }

  func euclideanDistance(_ other: [Double]) -> FunctionExpression {
    return FunctionExpression("euclidean_distance", [self, Helper.sendableToExpr(other)])
  }

  func manhattanDistance(_ other: Expression) -> FunctionExpression {
    return FunctionExpression("manhattan_distance", [self, other])
  }

  func manhattanDistance(_ other: VectorValue) -> FunctionExpression {
    return FunctionExpression("manhattan_distance", [self, Helper.sendableToExpr(other)])
  }

  func manhattanDistance(_ other: [Double]) -> FunctionExpression {
    return FunctionExpression("manhattan_distance", [self, Helper.sendableToExpr(other)])
  }

  // MARK: Timestamp operations

  func unixMicrosToTimestamp() -> FunctionExpression {
    return FunctionExpression("unix_micros_to_timestamp", [self])
  }

  func timestampToUnixMicros() -> FunctionExpression {
    return FunctionExpression("timestamp_to_unix_micros", [self])
  }

  func unixMillisToTimestamp() -> FunctionExpression {
    return FunctionExpression("unix_millis_to_timestamp", [self])
  }

  func timestampToUnixMillis() -> FunctionExpression {
    return FunctionExpression("timestamp_to_unix_millis", [self])
  }

  func unixSecondsToTimestamp() -> FunctionExpression {
    return FunctionExpression("unix_seconds_to_timestamp", [self])
  }

  func timestampToUnixSeconds() -> FunctionExpression {
    return FunctionExpression("timestamp_to_unix_seconds", [self])
  }

  func timestampAdd(amount: Expression, unit: Expression) -> FunctionExpression {
    return FunctionExpression("timestamp_add", [self, unit, amount])
  }

  func timestampAdd(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression {
    return FunctionExpression(
      "timestamp_add",
      [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func timestampSub(amount: Expression, unit: Expression) -> FunctionExpression {
    return FunctionExpression("timestamp_sub", [self, unit, amount])
  }

  func timestampSub(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression {
    return FunctionExpression(
      "timestamp_sub",
      [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  // MARK: - Bitwise operations

  func bitAnd(_ otherBits: Int) -> FunctionExpression {
    return FunctionExpression("bit_and", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitAnd(_ otherBits: UInt8) -> FunctionExpression {
    return FunctionExpression("bit_and", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitAnd(_ bitsExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_and", [self, bitsExpression])
  }

  func bitOr(_ otherBits: Int) -> FunctionExpression {
    return FunctionExpression("bit_or", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitOr(_ otherBits: UInt8) -> FunctionExpression {
    return FunctionExpression("bit_or", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitOr(_ bitsExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_or", [self, bitsExpression])
  }

  func bitXor(_ otherBits: Int) -> FunctionExpression {
    return FunctionExpression("bit_xor", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitXor(_ otherBits: UInt8) -> FunctionExpression {
    return FunctionExpression("bit_xor", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitXor(_ bitsExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_xor", [self, bitsExpression])
  }

  func bitNot() -> FunctionExpression {
    return FunctionExpression("bit_not", [self])
  }

  func bitLeftShift(_ y: Int) -> FunctionExpression {
    return FunctionExpression("bit_left_shift", [self, Helper.sendableToExpr(y)])
  }

  func bitLeftShift(_ numberExpr: Expression) -> FunctionExpression {
    return FunctionExpression("bit_left_shift", [self, numberExpr])
  }

  func bitRightShift(_ y: Int) -> FunctionExpression {
    return FunctionExpression("bit_right_shift", [self, Helper.sendableToExpr(y)])
  }

  func bitRightShift(_ numberExpr: Expression) -> FunctionExpression {
    return FunctionExpression("bit_right_shift", [self, numberExpr])
  }

  func documentId() -> FunctionExpression {
    return FunctionExpression("document_id", [self])
  }

  func ifError(_ catchExpr: Expression) -> FunctionExpression {
    return FunctionExpression("if_error", [self, catchExpr])
  }

  func ifError(_ catchValue: Sendable) -> FunctionExpression {
    return FunctionExpression("if_error", [self, Helper.sendableToExpr(catchValue)])
  }

  // MARK: Sorting

  func ascending() -> Ordering {
    return Ordering(expr: self, direction: .ascending)
  }

  func descending() -> Ordering {
    return Ordering(expr: self, direction: .descending)
  }
}
