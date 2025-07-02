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

  func arrayConcat(_ secondArray: Expression, _ otherArrays: Expression...) -> FunctionExpression {
    return FunctionExpression("array_concat", [self, secondArray] + otherArrays)
  }

  func arrayConcat(_ secondArray: [Sendable], _ otherArrays: [Sendable]...) -> FunctionExpression {
    let exprs = [self] + [Helper.sendableToExpr(secondArray)] + otherArrays
      .map { Helper.sendableToExpr($0) }
    return FunctionExpression("array_concat", exprs)
  }

  func arrayContains(_ element: Expression) -> BooleanExpr {
    return BooleanExpr("array_contains", [self, element])
  }

  func arrayContains(_ element: Sendable) -> BooleanExpr {
    return BooleanExpr("array_contains", [self, Helper.sendableToExpr(element)])
  }

  func arrayContainsAll(_ values: [Expression]) -> BooleanExpr {
    return BooleanExpr("array_contains_all", [self, Helper.array(values)])
  }

  func arrayContainsAll(_ values: [Sendable]) -> BooleanExpr {
    return BooleanExpr("array_contains_all", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Expression]) -> BooleanExpr {
    return BooleanExpr("array_contains_any", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpr {
    return BooleanExpr("array_contains_any", [self, Helper.array(values)])
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

  func gt(_ other: Expression) -> BooleanExpr {
    return BooleanExpr("gt", [self, other])
  }

  func gt(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("gt", [self, exprOther])
  }

  // MARK: - Greater Than or Equal (gte)

  func gte(_ other: Expression) -> BooleanExpr {
    return BooleanExpr("gte", [self, other])
  }

  func gte(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("gte", [self, exprOther])
  }

  // MARK: - Less Than (lt)

  func lt(_ other: Expression) -> BooleanExpr {
    return BooleanExpr("lt", [self, other])
  }

  func lt(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("lt", [self, exprOther])
  }

  // MARK: - Less Than or Equal (lte)

  func lte(_ other: Expression) -> BooleanExpr {
    return BooleanExpr("lte", [self, other])
  }

  func lte(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("lte", [self, exprOther])
  }

  // MARK: - Equal (eq)

  func eq(_ other: Expression) -> BooleanExpr {
    return BooleanExpr("eq", [self, other])
  }

  func eq(_ other: Sendable) -> BooleanExpr {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpr("eq", [self, exprOther])
  }

  func neq(_ other: Expression) -> BooleanExpr {
    return BooleanExpr("neq", [self, other])
  }

  func neq(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("neq", [self, Helper.sendableToExpr(other)])
  }

  func eqAny(_ others: [Expression]) -> BooleanExpr {
    return BooleanExpr("eq_any", [self, Helper.array(others)])
  }

  func eqAny(_ others: [Sendable]) -> BooleanExpr {
    return BooleanExpr("eq_any", [self, Helper.array(others)])
  }

  func notEqAny(_ others: [Expression]) -> BooleanExpr {
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

  func charLength() -> FunctionExpression {
    return FunctionExpression("char_length", [self])
  }

  func like(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("like", [self, Helper.sendableToExpr(pattern)])
  }

  func like(_ pattern: Expression) -> BooleanExpr {
    return BooleanExpr("like", [self, pattern])
  }

  func regexContains(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("regex_contains", [self, Helper.sendableToExpr(pattern)])
  }

  func regexContains(_ pattern: Expression) -> BooleanExpr {
    return BooleanExpr("regex_contains", [self, pattern])
  }

  func regexMatch(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("regex_match", [self, Helper.sendableToExpr(pattern)])
  }

  func regexMatch(_ pattern: Expression) -> BooleanExpr {
    return BooleanExpr("regex_match", [self, pattern])
  }

  func strContains(_ substring: String) -> BooleanExpr {
    return BooleanExpr("str_contains", [self, Helper.sendableToExpr(substring)])
  }

  func strContains(_ expr: Expression) -> BooleanExpr {
    return BooleanExpr("str_contains", [self, expr])
  }

  func startsWith(_ prefix: String) -> BooleanExpr {
    return BooleanExpr("starts_with", [self, Helper.sendableToExpr(prefix)])
  }

  func startsWith(_ prefix: Expression) -> BooleanExpr {
    return BooleanExpr("starts_with", [self, prefix])
  }

  func endsWith(_ suffix: String) -> BooleanExpr {
    return BooleanExpr("ends_with", [self, Helper.sendableToExpr(suffix)])
  }

  func endsWith(_ suffix: Expression) -> BooleanExpr {
    return BooleanExpr("ends_with", [self, suffix])
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

  func strConcat(_ secondString: Expression, _ otherStrings: Expression...) -> FunctionExpression {
    return FunctionExpression("str_concat", [self, secondString] + otherStrings)
  }

  func strConcat(_ secondString: String, _ otherStrings: String...) -> FunctionExpression {
    let exprs = [self] + [Helper.sendableToExpr(secondString)] + otherStrings
      .map { Helper.sendableToExpr($0) }
    return FunctionExpression("str_concat", exprs)
  }

  func reverse() -> FunctionExpression {
    return FunctionExpression("reverse", [self])
  }

  func replaceFirst(_ find: String, _ replace: String) -> FunctionExpression {
    return FunctionExpression(
      "replace_first",
      [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  func replaceFirst(_ find: Expression, _ replace: Expression) -> FunctionExpression {
    return FunctionExpression("replace_first", [self, find, replace])
  }

  func replaceAll(_ find: String, _ replace: String) -> FunctionExpression {
    return FunctionExpression(
      "replace_all",
      [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  func replaceAll(_ find: Expression, _ replace: Expression) -> FunctionExpression {
    return FunctionExpression("replace_all", [self, find, replace])
  }

  func byteLength() -> FunctionExpression {
    return FunctionExpression("byte_length", [self])
  }

  func substr(_ position: Int, _ length: Int? = nil) -> FunctionExpression {
    let positionExpr = Helper.sendableToExpr(position)
    if let length = length {
      return FunctionExpression("substr", [self, positionExpr, Helper.sendableToExpr(length)])
    } else {
      return FunctionExpression("substr", [self, positionExpr])
    }
  }

  func substr(_ position: Expression, _ length: Expression? = nil) -> FunctionExpression {
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

  func mapMerge(_ secondMap: [String: Sendable],
                _ otherMaps: [String: Sendable]...) -> FunctionExpression {
    let secondMapExpr = Helper.sendableToExpr(secondMap)
    let otherMapExprs = otherMaps.map { Helper.sendableToExpr($0) }
    return FunctionExpression("map_merge", [self, secondMapExpr] + otherMapExprs)
  }

  func mapMerge(_ secondMap: Expression, _ otherMaps: Expression...) -> FunctionExpression {
    return FunctionExpression("map_merge", [self, secondMap] + otherMaps)
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

  func logicalMaximum(_ second: Expression, _ others: Expression...) -> FunctionExpression {
    return FunctionExpression("logical_maximum", [self, second] + others)
  }

  func logicalMaximum(_ second: Sendable, _ others: Sendable...) -> FunctionExpression {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
    return FunctionExpression("logical_maximum", exprs)
  }

  func logicalMinimum(_ second: Expression, _ others: Expression...) -> FunctionExpression {
    return FunctionExpression("logical_minimum", [self, second] + others)
  }

  func logicalMinimum(_ second: Sendable, _ others: Sendable...) -> FunctionExpression {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
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

  func timestampAdd(_ unit: Expression, _ amount: Expression) -> FunctionExpression {
    return FunctionExpression("timestamp_add", [self, unit, amount])
  }

  func timestampAdd(_ unit: TimeUnit, _ amount: Int) -> FunctionExpression {
    return FunctionExpression(
      "timestamp_add",
      [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func timestampSub(_ unit: Expression, _ amount: Expression) -> FunctionExpression {
    return FunctionExpression("timestamp_sub", [self, unit, amount])
  }

  func timestampSub(_ unit: TimeUnit, _ amount: Int) -> FunctionExpression {
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
