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
// WITHOUT WARRANTIES OR CONDITIONS OF Sendable KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

public protocol Expr: Sendable {
  func `as`(_ name: String) -> ExprWithAlias

  // MARK: Arithmetic Operators

  func add(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func add(_ second: Sendable, _ others: Sendable...) -> FunctionExpr

  func subtract(_ other: Expr) -> FunctionExpr
  func subtract(_ other: Sendable) -> FunctionExpr

  func multiply(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func multiply(_ second: Sendable, _ others: Sendable...) -> FunctionExpr

  func divide(_ other: Expr) -> FunctionExpr
  func divide(_ other: Sendable) -> FunctionExpr

  func mod(_ other: Expr) -> FunctionExpr
  func mod(_ other: Sendable) -> FunctionExpr

  // MARK: Array Operations

  func arrayConcat(_ secondArray: Expr, _ otherArrays: Expr...) -> FunctionExpr
  func arrayConcat(_ secondArray: [Sendable], _ otherArrays: [Sendable]...) -> FunctionExpr

  func arrayContains(_ element: Expr) -> BooleanExpr
  func arrayContains(_ element: Sendable) -> BooleanExpr

  func arrayContainsAll(_ values: Expr...) -> BooleanExpr
  func arrayContainsAll(_ values: Sendable...) -> BooleanExpr

  func arrayContainsSendable(_ values: Expr...) -> BooleanExpr
  func arrayContainsSendable(_ values: Sendable...) -> BooleanExpr

  func arrayLength() -> FunctionExpr

  func arrayOffset(_ offset: Int) -> FunctionExpr
  func arrayOffset(_ offsetExpr: Expr) -> FunctionExpr

  // MARK: Equality with Sendable

  func eqSendable(_ others: Expr...) -> BooleanExpr
  func eqSendable(_ others: Sendable...) -> BooleanExpr

  func notEqSendable(_ others: Expr...) -> BooleanExpr
  func notEqSendable(_ others: Sendable...) -> BooleanExpr

  // MARK: Checks

  func isNan() -> BooleanExpr
  func isNull() -> BooleanExpr
  func exists() -> BooleanExpr
  func isError() -> BooleanExpr
  func isAbsent() -> BooleanExpr
  func isNotNull() -> BooleanExpr
  func isNotNan() -> BooleanExpr

  // MARK: String Operations

  func charLength() -> FunctionExpr
  func like(_ pattern: String) -> FunctionExpr
  func like(_ pattern: Expr) -> FunctionExpr

  func regexContains(_ pattern: String) -> BooleanExpr
  func regexContains(_ pattern: Expr) -> BooleanExpr

  func regexMatch(_ pattern: String) -> BooleanExpr
  func regexMatch(_ pattern: Expr) -> BooleanExpr

  func strContains(_ substring: String) -> BooleanExpr
  func strContains(_ expr: Expr) -> BooleanExpr

  func startsWith(_ prefix: String) -> BooleanExpr
  func startsWith(_ prefix: Expr) -> BooleanExpr

  func endsWith(_ suffix: String) -> BooleanExpr
  func endsWith(_ suffix: Expr) -> BooleanExpr

  func lowercased() -> FunctionExpr
  func uppercased() -> FunctionExpr
  func trim() -> FunctionExpr

  func strConcat(_ secondString: Expr, _ otherStrings: Expr...) -> FunctionExpr
  func strConcat(_ secondString: String, _ otherStrings: String...) -> FunctionExpr

  func reverse() -> FunctionExpr
  func replaceFirst(_ find: String, _ replace: String) -> FunctionExpr
  func replaceFirst(_ find: Expr, _ replace: Expr) -> FunctionExpr
  func replaceAll(_ find: String, _ replace: String) -> FunctionExpr
  func replaceAll(_ find: Expr, _ replace: Expr) -> FunctionExpr

  func byteLength() -> FunctionExpr

  func substr(_ position: Int, _ length: Int?) -> FunctionExpr
  func substr(_ position: Expr, _ length: Expr?) -> FunctionExpr

  // MARK: Map Operations

  func mapGet(_ subfield: String) -> FunctionExpr
  func mapRemove(_ key: String) -> FunctionExpr
  func mapRemove(_ keyExpr: Expr) -> FunctionExpr
  func mapMerge(_ secondMap: [String: Sendable], _ otherMaps: [String: Sendable]...) -> FunctionExpr
  func mapMerge(_ secondMap: Expr, _ otherMaps: Expr...) -> FunctionExpr

  // MARK: Aggregations

  func count() -> AggregateFunction
  func sum() -> AggregateFunction
  func avg() -> AggregateFunction
  func minimum() -> AggregateFunction
  func maximum() -> AggregateFunction

  // MARK: Logical min/max

  func logicalMaximum(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func logicalMaximum(_ second: Sendable, _ others: Sendable...) -> FunctionExpr

  func logicalMinimum(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func logicalMinimum(_ second: Sendable, _ others: Sendable...) -> FunctionExpr

  // MARK: Vector Operations

  func vectorLength() -> FunctionExpr
  func cosineDistance(_ other: Expr) -> FunctionExpr
  func cosineDistance(_ other: VectorValue) -> FunctionExpr
  func cosineDistance(_ other: [Double]) -> FunctionExpr

  func dotProduct(_ other: Expr) -> FunctionExpr
  func dotProduct(_ other: VectorValue) -> FunctionExpr
  func dotProduct(_ other: [Double]) -> FunctionExpr

  func euclideanDistance(_ other: Expr) -> FunctionExpr
  func euclideanDistance(_ other: VectorValue) -> FunctionExpr
  func euclideanDistance(_ other: [Double]) -> FunctionExpr

  func manhattanDistance(_ other: Expr) -> FunctionExpr
  func manhattanDistance(_ other: VectorValue) -> FunctionExpr
  func manhattanDistance(_ other: [Double]) -> FunctionExpr

  // MARK: Timestamp operations

  func unixMicrosToTimestamp() -> FunctionExpr
  func timestampToUnixMicros() -> FunctionExpr
  func unixMillisToTimestamp() -> FunctionExpr
  func timestampToUnixMillis() -> FunctionExpr
  func unixSecondsToTimestamp() -> FunctionExpr
  func timestampToUnixSeconds() -> FunctionExpr

  func timestampAdd(_ unit: Expr, _ amount: Expr) -> FunctionExpr
  func timestampAdd(_ unit: TimeUnit, _ amount: Int) -> FunctionExpr
  func timestampSub(_ unit: Expr, _ amount: Expr) -> FunctionExpr
  func timestampSub(_ unit: TimeUnit, _ amount: Int) -> FunctionExpr

  // MARK: - Bitwise operations

  func bitAnd(_ otherBits: Int) -> FunctionExpr
  func bitAnd(_ otherBits: UInt8) -> FunctionExpr
  func bitAnd(_ bitsExpression: Expr) -> FunctionExpr

  func bitOr(_ otherBits: Int) -> FunctionExpr
  func bitOr(_ otherBits: UInt8) -> FunctionExpr
  func bitOr(_ bitsExpression: Expr) -> FunctionExpr

  func bitXor(_ otherBits: Int) -> FunctionExpr
  func bitXor(_ otherBits: UInt8) -> FunctionExpr
  func bitXor(_ bitsExpression: Expr) -> FunctionExpr

  func bitNot() -> FunctionExpr

  func bitLeftShift(_ y: Int) -> FunctionExpr
  func bitLeftShift(_ numberExpr: Expr) -> FunctionExpr

  func bitRightShift(_ y: Int) -> FunctionExpr
  func bitRightShift(_ numberExpr: Expr) -> FunctionExpr

  func ifError(_ catchExpr: Expr) -> FunctionExpr
  func ifError(_ catchValue: Sendable) -> FunctionExpr

  // MARK: Sorting

  func ascending() -> Ordering
  func descending() -> Ordering
}

public extension Expr {
  func `as`(_ name: String) -> ExprWithAlias {
    return ExprWithAlias(self, name)
  }

  // MARK: Comparison Operators

  func eq(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("eq", [self, other])
  }

  func eq(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("eq", [self, Helper.sendableToExpr(other)])
  }

  func neq(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("neq", [self, other])
  }

  func neq(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("neq", [self, Helper.sendableToExpr(other)])
  }

  func lt(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("lt", [self, other])
  }

  func lt(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("lt", [self, Helper.sendableToExpr(other)])
  }

  func lte(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("lte", [self, other])
  }

  func lte(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("lte", [self, Helper.sendableToExpr(other)])
  }

  func gt(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("gt", [self, other])
  }

  func gt(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("gt", [self, Helper.sendableToExpr(other)])
  }

  func gte(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("gte", [self, other])
  }

  func gte(_ other: Sendable) -> BooleanExpr {
    return BooleanExpr("gte", [self, Helper.sendableToExpr(other)])
  }

  // MARK: Arithmetic Operators

  func add(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("add", [self, second] + others)
  }

  func add(_ second: Sendable, _ others: Sendable...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("add", exprs)
  }

  func subtract(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("subtract", [self, other])
  }

  func subtract(_ other: Sendable) -> FunctionExpr {
    return FunctionExpr("subtract", [self, Helper.sendableToExpr(other)])
  }

  func multiply(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("multiply", [self, second] + others)
  }

  func multiply(_ second: Sendable, _ others: Sendable...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("multiply", exprs)
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

  func arrayContainsAll(_ values: Expr...) -> BooleanExpr {
    return BooleanExpr("array_contains_all", [self] + values)
  }

  func arrayContainsAll(_ values: Sendable...) -> BooleanExpr {
    let exprValues = values.map { Helper.sendableToExpr($0) }
    return BooleanExpr("array_contains_all", [self] + exprValues)
  }

  func arrayContainsSendable(_ values: Expr...) -> BooleanExpr {
    return BooleanExpr("array_contains_Sendable", [self] + values)
  }

  func arrayContainsSendable(_ values: Sendable...) -> BooleanExpr {
    let exprValues = values.map { Helper.sendableToExpr($0) }
    return BooleanExpr("array_contains_Sendable", [self] + exprValues)
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

  // MARK: Equality with Sendable

  func eqSendable(_ others: Expr...) -> BooleanExpr {
    return BooleanExpr("eq_Sendable", [self] + others)
  }

  func eqSendable(_ others: Sendable...) -> BooleanExpr {
    let exprOthers = others.map { Helper.sendableToExpr($0) }
    return BooleanExpr("eq_Sendable", [self] + exprOthers)
  }

  func notEqSendable(_ others: Expr...) -> BooleanExpr {
    return BooleanExpr("not_eq_Sendable", [self] + others)
  }

  func notEqSendable(_ others: Sendable...) -> BooleanExpr {
    let exprOthers = others.map { Helper.sendableToExpr($0) }
    return BooleanExpr("not_eq_Sendable", [self] + exprOthers)
  }

  // MARK: Checks

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

  // MARK: String Operations

  func charLength() -> FunctionExpr {
    return FunctionExpr("char_length", [self])
  }

  func like(_ pattern: String) -> FunctionExpr {
    return FunctionExpr("like", [self, Helper.sendableToExpr(pattern)])
  }

  func like(_ pattern: Expr) -> FunctionExpr {
    return FunctionExpr("like", [self, pattern])
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

  // MARK: Map Operations

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

  // MARK: Aggregations

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
    return FunctionExpr("logical_min", [self, second] + others)
  }

  func logicalMinimum(_ second: Sendable, _ others: Sendable...) -> FunctionExpr {
    let exprs = [self] + [Helper.sendableToExpr(second)] + others
      .map { Helper.sendableToExpr($0) }
    return FunctionExpr("logical_min", exprs)
  }

  // MARK: Vector Operations

  func vectorLength() -> FunctionExpr {
    return FunctionExpr("vector_length", [self])
  }

  func cosineDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("cosine_distance", [self, other])
  }

  func cosineDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("cosine_distance", [self, Helper.vectorToExpr(other)])
  }

  func cosineDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("cosine_distance", [self, Helper.sendableToExpr(other)])
  }

  func dotProduct(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, other])
  }

  func dotProduct(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, Helper.vectorToExpr(other)])
  }

  func dotProduct(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, Helper.sendableToExpr(other)])
  }

  func euclideanDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, other])
  }

  func euclideanDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, Helper.vectorToExpr(other)])
  }

  func euclideanDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, Helper.sendableToExpr(other)])
  }

  func manhattanDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, other])
  }

  func manhattanDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, Helper.vectorToExpr(other)])
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
      [self, Helper.timeUnitToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func timestampSub(_ unit: Expr, _ amount: Expr) -> FunctionExpr {
    return FunctionExpr("timestamp_sub", [self, unit, amount])
  }

  func timestampSub(_ unit: TimeUnit, _ amount: Int) -> FunctionExpr {
    return FunctionExpr(
      "timestamp_sub",
      [self, Helper.timeUnitToExpr(unit), Helper.sendableToExpr(amount)]
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

extension Expr {
  func exprToExprBridge() -> ExprBridge {
    return (self as! BridgeWrapper).bridge
  }
}

// protocal cannot overwrite operator, since every inheritated class will have this function
// it will lead to error: Generic parameter 'Self' could not be inferred

public func > (lhs: Expr, rhs: @autoclosure () throws -> Sendable) rethrows -> BooleanExpr {
  try BooleanExpr("gt", [lhs, Helper.sendableToExpr(rhs())])
}

public func >= (lhs: Expr, rhs: @autoclosure () throws -> Sendable) rethrows -> BooleanExpr {
  try BooleanExpr("gte", [lhs, Helper.sendableToExpr(rhs())])
}

public func < (lhs: Expr, rhs: @autoclosure () throws -> Sendable) rethrows -> BooleanExpr {
  try BooleanExpr("lt", [lhs, Helper.sendableToExpr(rhs())])
}

public func <= (lhs: Expr, rhs: @autoclosure () throws -> Sendable) rethrows -> BooleanExpr {
  try BooleanExpr("lte", [lhs, Helper.sendableToExpr(rhs())])
}

public func == (lhs: Expr, rhs: @autoclosure () throws -> Sendable) rethrows -> BooleanExpr {
  try BooleanExpr("eq", [lhs, Helper.sendableToExpr(rhs())])
}

public func != (lhs: Expr, rhs: @autoclosure () throws -> Sendable) rethrows -> BooleanExpr {
  try BooleanExpr("neq", [lhs, Helper.sendableToExpr(rhs())])
}
