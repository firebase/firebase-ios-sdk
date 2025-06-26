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

extension Expr {
  func toBridge() -> ExprBridge {
    return (self as! BridgeWrapper).bridge
  }
}

public extension Expr {
  func `as`(_ name: String) -> ExprWithAlias {
    return ExprWithAlias(self, name)
  }

  // MARK: Arithmetic Operators

  func add(_ value: Expr) -> FunctionExpr {
    return FunctionExpr("add", [self, value])
  }

  func add(_ value: Sendable) -> FunctionExpr {
    return FunctionExpr("add", [self, Helper.sendableToExpr(value)])
  }

  func subtract(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("subtract", [self, other])
  }

  func subtract(_ other: Sendable) -> FunctionExpr {
    return FunctionExpr("subtract", [self, Helper.sendableToExpr(other)])
  }

  func multiply(_ value: Expr) -> FunctionExpr {
    return FunctionExpr("multiply", [self, value])
  }

  func multiply(_ value: Sendable) -> FunctionExpr {
    return FunctionExpr("multiply", [self, Helper.sendableToExpr(value)])
  }

  func divide(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("divide", [self, other])
  }

  func divide(_ other: Sendable) -> FunctionExpr {
    return FunctionExpr("divide", [self, Helper.sendableToExpr(other)])
  }

  func mod(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("mod", [self, other])
  }

  func mod(_ other: Sendable) -> FunctionExpr {
    return FunctionExpr("mod", [self, Helper.sendableToExpr(other)])
  }

  // MARK: Array Operations

  func arrayConcat(_ secondArray: Expr, _ otherArrays: Expr...) -> FunctionExpr {
    return FunctionExpr("array_concat", [self, secondArray] + otherArrays)
  }

  func arrayConcat(_ secondArray: [Sendable], _ otherArrays: [Sendable]...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(secondArray)] + otherArrays
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("array_concat", exprs)
  }

  func arrayContains(_ element: Expr) -> BooleanExpr {
    return BooleanExpr("array_contains", [self, element])
  }

  func arrayContains(_ element: Sendable) -> BooleanExpr {
    return BooleanExpr("array_contains", [self, Helper.sendableToExpr(element)])
  }

  func arrayContainsAll(_ values: [Expr]) -> BooleanExpr {
    return BooleanExpr("array_contains_all", [self, Helper.array(values)])
  }

  func arrayContainsAll(_ values: [Sendable]) -> BooleanExpr {
    return BooleanExpr("array_contains_all", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Expr]) -> BooleanExpr {
    return BooleanExpr("array_contains_any", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpr {
    return BooleanExpr("array_contains_any", [self, Helper.array(values)])
  }

  func arrayLength() -> FunctionExpr {
    return FunctionExpr("array_length", [self])
  }

  func arrayOffset(_ offset: Int) -> FunctionExpr {
    return FunctionExpr("array_offset", [self, Helper.sendableToExpr(offset)])
  }

  func arrayOffset(_ offsetExpr: Expr) -> FunctionExpr {
    return FunctionExpr("array_offset", [self, offsetExpr])
  }

  func gt(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("gt", [self, other])
  }

  func gt(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("gt", [self, exprOther])
  }

  // MARK: - Greater Than or Equal (gte)

  func gte(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("gte", [self, other])
  }

  func gte(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("gte", [self, exprOther])
  }

  // MARK: - Less Than (lt)

  func lt(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("lt", [self, other])
  }

  func lt(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("lt", [self, exprOther])
  }

  // MARK: - Less Than or Equal (lte)

  func lte(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("lte", [self, other])
  }

  func lte(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("lte", [self, exprOther])
  }

  // MARK: - Equal (eq)

  func eq(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("eq", [self, other])
  }

  func eq(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("eq", [self, exprOther])
  }

  func neq(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("neq", [self, other])
  }

  func neq(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("neq", [self, Helper.sendableToExpr(other)])
  }

  func eqAny(_ others: [Expr]) -> BooleanExpr {
    return BooleanExpr("eq_any", [self, Helper.array(others)])
  }

  func eqAny(_ others: [Sendable]) -> BooleanExpr {
    return BooleanExpr("eq_any", [self, Helper.array(others)])
  }

  func notEqAny(_ others: [Expr]) -> BooleanExpr {
    return BooleanExpr("not_eq_any", [self, Helper.array(others)])
  }

  func notEqAny(_ others: [Sendable]) -> BooleanExpr {
    return BooleanExpr("not_eq_any", [self, Helper.array(others)])
  }

  // MARK: Checks

  // --- Added Type Check Operations ---

  func isNan() -> BooleanExpr {
    return BooleanExpr("is_nan", [self])
  }

  func isNull() -> BooleanExpr {
    return BooleanExpr("is_null", [self])
  }

  func exists() -> BooleanExpr {
    return BooleanExpr("exists", [self])
  }

  func isError() -> BooleanExpr {
    return BooleanExpr("is_error", [self])
  }

  func isAbsent() -> BooleanExpr {
    return BooleanExpr("is_absent", [self])
  }

  func isNotNull() -> BooleanExpr {
    return BooleanExpr("is_not_null", [self])
  }

  func isNotNan() -> BooleanExpr {
    return BooleanExpr("is_not_nan", [self])
  }

  // --- Added String Operations ---

  func charLength() -> FunctionExpr {
    return FunctionExpr("char_length", [self])
  }

  func like(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("like", [self, Helper.sendableToExpr(pattern)])
  }

  func like(_ pattern: Expr) -> BooleanExpr {
    return BooleanExpr("like", [self, pattern])
  }

  func regexContains(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("regex_contains", [self, Helper.sendableToExpr(pattern)])
  }

  func regexContains(_ pattern: Expr) -> BooleanExpr {
    return BooleanExpr("regex_contains", [self, pattern])
  }

  func regexMatch(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("regex_match", [self, Helper.sendableToExpr(pattern)])
  }

  func regexMatch(_ pattern: Expr) -> BooleanExpr {
    return BooleanExpr("regex_match", [self, pattern])
  }

  func strContains(_ substring: String) -> BooleanExpr {
    return BooleanExpr("str_contains", [self, Helper.sendableToExpr(substring)])
  }

  func strContains(_ expr: Expr) -> BooleanExpr {
    return BooleanExpr("str_contains", [self, expr])
  }

  func startsWith(_ prefix: String) -> BooleanExpr {
    return BooleanExpr("starts_with", [self, Helper.sendableToExpr(prefix)])
  }

  func startsWith(_ prefix: Expr) -> BooleanExpr {
    return BooleanExpr("starts_with", [self, prefix])
  }

  func endsWith(_ suffix: String) -> BooleanExpr {
    return BooleanExpr("ends_with", [self, Helper.sendableToExpr(suffix)])
  }

  func endsWith(_ suffix: Expr) -> BooleanExpr {
    return BooleanExpr("ends_with", [self, suffix])
  }

  func lowercased() -> FunctionExpr {
    return FunctionExpr("to_lower", [self])
  }

  func uppercased() -> FunctionExpr {
    return FunctionExpr("to_upper", [self])
  }

  func trim() -> FunctionExpr {
    return FunctionExpr("trim", [self])
  }

  func strConcat(_ secondString: Expr, _ otherStrings: Expr...) -> FunctionExpr {
    return FunctionExpr("str_concat", [self, secondString] + otherStrings)
  }

  func strConcat(_ secondString: String, _ otherStrings: String...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(secondString)] + otherStrings
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("str_concat", exprs)
  }

  func reverse() -> FunctionExpr {
    return FunctionExpr("reverse", [self])
  }

  func replaceFirst(_ find: String, _ replace: String) -> FunctionExpr {
    return FunctionExpr(
      "replace_first",
      [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  func replaceFirst(_ find: Expr, _ replace: Expr) -> FunctionExpr {
    return FunctionExpr("replace_first", [self, find, replace])
  }

  func replaceAll(_ find: String, _ replace: String) -> FunctionExpr {
    return FunctionExpr(
      "replace_all",
      [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  func replaceAll(_ find: Expr, _ replace: Expr) -> FunctionExpr {
    return FunctionExpr("replace_all", [self, find, replace])
  }

  func byteLength() -> FunctionExpr {
    return FunctionExpr("byte_length", [self])
  }

  func substr(_ position: Int, _ length: Int? = nil) -> FunctionExpr {
    let positionExpr = Helper.sendableToExpr(position)
    if let length = length {
      return FunctionExpr("substr", [self, positionExpr, Helper.sendableToExpr(length)])
    } else {
      return FunctionExpr("substr", [self, positionExpr])
    }
  }

  func substr(_ position: Expr, _ length: Expr? = nil) -> FunctionExpr {
    if let length = length {
      return FunctionExpr("substr", [self, position, length])
    } else {
      return FunctionExpr("substr", [self, position])
    }
  }

  // --- Added Map Operations ---

  func mapGet(_ subfield: String) -> FunctionExpr {
    return FunctionExpr("map_get", [self, Constant(subfield)])
  }

  func mapRemove(_ key: String) -> FunctionExpr {
    return FunctionExpr("map_remove", [self, Helper.sendableToExpr(key)])
  }

  func mapRemove(_ keyExpr: Expr) -> FunctionExpr {
    return FunctionExpr("map_remove", [self, keyExpr])
  }

  func mapMerge(_ secondMap: [String: Sendable],
                _ otherMaps: [String: Sendable]...) -> FunctionExpr {
    let secondMapExpr = Helper.sendableToExpr(secondMap)
    let otherMapExprs = otherMaps.map { Helper.sendableToExpr($0) }
    return FunctionExpr("map_merge", [self, secondMapExpr] + otherMapExprs)
  }

  func mapMerge(_ secondMap: Expr, _ otherMaps: Expr...) -> FunctionExpr {
    return FunctionExpr("map_merge", [self, secondMap] + otherMaps)
  }

  // --- Added Aggregate Operations (on Expr) ---

  func count() -> AggregateFunction {
    return AggregateFunction("count", [self])
  }

  func sum() -> AggregateFunction {
    return AggregateFunction("sum", [self])
  }

  func avg() -> AggregateFunction {
    return AggregateFunction("avg", [self])
  }

  func minimum() -> AggregateFunction {
    return AggregateFunction("minimum", [self])
  }

  func maximum() -> AggregateFunction {
    return AggregateFunction("maximum", [self])
  }

  // MARK: Logical min/max

  func logicalMaximum(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("logical_maximum", [self, second] + others)
  }

  func logicalMaximum(_ second: Sendable, _ others: Sendable...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("logical_maximum", exprs)
  }

  func logicalMinimum(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("logical_minimum", [self, second] + others)
  }

  func logicalMinimum(_ second: Sendable, _ others: Sendable...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("logical_minimum", exprs)
  }

  // MARK: Vector Operations

  func vectorLength() -> FunctionExpr {
    return FunctionExpr("vector_length", [self])
  }

  func cosineDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("cosine_distance", [self, other])
  }

  func cosineDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("cosine_distance", [self, Helper.sendableToExpr(other)])
  }

  func cosineDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("cosine_distance", [self, Helper.sendableToExpr(other)])
  }

  func dotProduct(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, other])
  }

  func dotProduct(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, Helper.sendableToExpr(other)])
  }

  func dotProduct(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, Helper.sendableToExpr(other)])
  }

  func euclideanDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, other])
  }

  func euclideanDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, Helper.sendableToExpr(other)])
  }

  func euclideanDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, Helper.sendableToExpr(other)])
  }

  func manhattanDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, other])
  }

  func manhattanDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, Helper.sendableToExpr(other)])
  }

  func manhattanDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, Helper.sendableToExpr(other)])
  }

  // MARK: Timestamp operations

  func unixMicrosToTimestamp() -> FunctionExpr {
    return FunctionExpr("unix_micros_to_timestamp", [self])
  }

  func timestampToUnixMicros() -> FunctionExpr {
    return FunctionExpr("timestamp_to_unix_micros", [self])
  }

  func unixMillisToTimestamp() -> FunctionExpr {
    return FunctionExpr("unix_millis_to_timestamp", [self])
  }

  func timestampToUnixMillis() -> FunctionExpr {
    return FunctionExpr("timestamp_to_unix_millis", [self])
  }

  func unixSecondsToTimestamp() -> FunctionExpr {
    return FunctionExpr("unix_seconds_to_timestamp", [self])
  }

  func timestampToUnixSeconds() -> FunctionExpr {
    return FunctionExpr("timestamp_to_unix_seconds", [self])
  }

  func timestampAdd(_ unit: Expr, _ amount: Expr) -> FunctionExpr {
    return FunctionExpr("timestamp_add", [self, unit, amount])
  }

  func timestampAdd(_ unit: TimeUnit, _ amount: Int) -> FunctionExpr {
    return FunctionExpr(
      "timestamp_add",
      [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func timestampSub(_ unit: Expr, _ amount: Expr) -> FunctionExpr {
    return FunctionExpr("timestamp_sub", [self, unit, amount])
  }

  func timestampSub(_ unit: TimeUnit, _ amount: Int) -> FunctionExpr {
    return FunctionExpr(
      "timestamp_sub",
      [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  // MARK: - Bitwise operations

  func bitAnd(_ otherBits: Int) -> FunctionExpr {
    return FunctionExpr("bit_and", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitAnd(_ otherBits: UInt8) -> FunctionExpr {
    return FunctionExpr("bit_and", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitAnd(_ bitsExpression: Expr) -> FunctionExpr {
    return FunctionExpr("bit_and", [self, bitsExpression])
  }

  func bitOr(_ otherBits: Int) -> FunctionExpr {
    return FunctionExpr("bit_or", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitOr(_ otherBits: UInt8) -> FunctionExpr {
    return FunctionExpr("bit_or", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitOr(_ bitsExpression: Expr) -> FunctionExpr {
    return FunctionExpr("bit_or", [self, bitsExpression])
  }

  func bitXor(_ otherBits: Int) -> FunctionExpr {
    return FunctionExpr("bit_xor", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitXor(_ otherBits: UInt8) -> FunctionExpr {
    return FunctionExpr("bit_xor", [self, Helper.sendableToExpr(otherBits)])
  }

  func bitXor(_ bitsExpression: Expr) -> FunctionExpr {
    return FunctionExpr("bit_xor", [self, bitsExpression])
  }

  func bitNot() -> FunctionExpr {
    return FunctionExpr("bit_not", [self])
  }

  func bitLeftShift(_ y: Int) -> FunctionExpr {
    return FunctionExpr("bit_left_shift", [self, Helper.sendableToExpr(y)])
  }

  func bitLeftShift(_ numberExpr: Expr) -> FunctionExpr {
    return FunctionExpr("bit_left_shift", [self, numberExpr])
  }

  func bitRightShift(_ y: Int) -> FunctionExpr {
    return FunctionExpr("bit_right_shift", [self, Helper.sendableToExpr(y)])
  }

  func bitRightShift(_ numberExpr: Expr) -> FunctionExpr {
    return FunctionExpr("bit_right_shift", [self, numberExpr])
  }

  func documentId() -> FunctionExpr {
    return FunctionExpr("document_id", [self])
  }

  func ifError(_ catchExpr: Expr) -> FunctionExpr {
    return FunctionExpr("if_error", [self, catchExpr])
  }

  func ifError(_ catchValue: Sendable) -> FunctionExpr {
    return FunctionExpr("if_error", [self, Helper.sendableToExpr(catchValue)])
  }

  // MARK: Sorting

  func ascending() -> Ordering {
    return Ordering(expr: self, direction: .ascending)
  }

  func descending() -> Ordering {
    return Ordering(expr: self, direction: .descending)
  }
}
