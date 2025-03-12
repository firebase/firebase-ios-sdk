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

public protocol Expr: Sendable {
  func `as`(_ name: String) -> ExprWithAlias

  // MARK: Comparison Operators

  func eq(_ other: Expr) -> BooleanExpr
  func eq(_ other: Any) -> BooleanExpr

  func neq(_ other: Expr) -> BooleanExpr
  func neq(_ other: Any) -> BooleanExpr

  func lt(_ other: Expr) -> BooleanExpr
  func lt(_ other: Any) -> BooleanExpr

  func lte(_ other: Expr) -> BooleanExpr
  func lte(_ other: Any) -> BooleanExpr

  func gt(_ other: Expr) -> BooleanExpr
  func gt(_ other: Any) -> BooleanExpr

  func gte(_ other: Expr) -> BooleanExpr
  func gte(_ other: Any) -> BooleanExpr

  // MARK: Arithmetic Operators

  func add(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func add(_ second: Any, _ others: Any...) -> FunctionExpr

  func subtract(_ other: Expr) -> FunctionExpr
  func subtract(_ other: Any) -> FunctionExpr

  func multiply(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func multiply(_ second: Any, _ others: Any...) -> FunctionExpr

  func divide(_ other: Expr) -> FunctionExpr
  func divide(_ other: Any) -> FunctionExpr

  func mod(_ other: Expr) -> FunctionExpr
  func mod(_ other: Any) -> FunctionExpr

  // MARK: Array Operations

  func arrayConcat(_ secondArray: Expr, _ otherArrays: Expr...) -> FunctionExpr
  func arrayConcat(_ secondArray: [Any], _ otherArrays: [Any]...) -> FunctionExpr

  func arrayContains(_ element: Expr) -> BooleanExpr
  func arrayContains(_ element: Any) -> BooleanExpr

  func arrayContainsAll(_ values: Expr...) -> BooleanExpr
  func arrayContainsAll(_ values: Any...) -> BooleanExpr

  func arrayContainsAny(_ values: Expr...) -> BooleanExpr
  func arrayContainsAny(_ values: Any...) -> BooleanExpr

  func arrayLength() -> FunctionExpr

  func arrayOffset(_ offset: Int) -> FunctionExpr
  func arrayOffset(_ offsetExpr: Expr) -> FunctionExpr

  // MARK: Equality with Any

  func eqAny(_ others: Expr...) -> BooleanExpr
  func eqAny(_ others: Any...) -> BooleanExpr

  func notEqAny(_ others: Expr...) -> BooleanExpr
  func notEqAny(_ others: Any...) -> BooleanExpr

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

  func toLower() -> FunctionExpr
  func toUpper() -> FunctionExpr
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
  func mapMerge(_ secondMap: [String: Any], _ otherMaps: [String: Any]...) -> FunctionExpr
  func mapMerge(_ secondMap: Expr, _ otherMaps: Expr...) -> FunctionExpr

  // MARK: Aggregations

  func count() -> AggregateFunction
  func sum() -> AggregateFunction
  func avg() -> AggregateFunction
  func minimum() -> AggregateFunction
  func maximum() -> AggregateFunction

  // MARK: Logical min/max

  func logicalMaximum(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func logicalMaximum(_ second: Any, _ others: Any...) -> FunctionExpr

  func logicalMinimum(_ second: Expr, _ others: Expr...) -> FunctionExpr
  func logicalMinimum(_ second: Any, _ others: Any...) -> FunctionExpr

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

  // MARK: - String operations.

  func documentId() -> FunctionExpr

  func ifError(_ catchExpr: Expr) -> FunctionExpr
  func ifError(_ catchValue: Any) -> FunctionExpr

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

  func eq(_ other: Any) -> BooleanExpr {
    return BooleanExpr("eq", [self, Helper.valueToDefaultExpr(other)])
  }

  func neq(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("neq", [self, other])
  }

  func neq(_ other: Any) -> BooleanExpr {
    return BooleanExpr("neq", [self, Helper.valueToDefaultExpr(other)])
  }

  func lt(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("lt", [self, other])
  }

  func lt(_ other: Any) -> BooleanExpr {
    return BooleanExpr("lt", [self, Helper.valueToDefaultExpr(other)])
  }

  func lte(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("lte", [self, other])
  }

  func lte(_ other: Any) -> BooleanExpr {
    return BooleanExpr("lte", [self, Helper.valueToDefaultExpr(other)])
  }

  func gt(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("gt", [self, other])
  }

  func gt(_ other: Any) -> BooleanExpr {
    return BooleanExpr("gt", [self, Helper.valueToDefaultExpr(other)])
  }

  func gte(_ other: Expr) -> BooleanExpr {
    return BooleanExpr("gte", [self, other])
  }

  func gte(_ other: Any) -> BooleanExpr {
    return BooleanExpr("gte", [self, Helper.valueToDefaultExpr(other)])
  }

  // MARK: Arithmetic Operators

  func add(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("add", [self, second] + others)
  }

  func add(_ second: Any, _ others: Any...) -> FunctionExpr {
    let exprs = [self] + [Helper.valueToDefaultExpr(second)] + others
      .map { Helper.valueToDefaultExpr($0) }
    return FunctionExpr("add", exprs)
  }

  func subtract(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("subtract", [self, other])
  }

  func subtract(_ other: Any) -> FunctionExpr {
    return FunctionExpr("subtract", [self, Helper.valueToDefaultExpr(other)])
  }

  func multiply(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("multiply", [self, second] + others)
  }

  func multiply(_ second: Any, _ others: Any...) -> FunctionExpr {
    let exprs = [self] + [Helper.valueToDefaultExpr(second)] + others
      .map { Helper.valueToDefaultExpr($0) }
    return FunctionExpr("multiply", exprs)
  }

  func divide(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("divide", [self, other])
  }

  func divide(_ other: Any) -> FunctionExpr {
    return FunctionExpr("divide", [self, Helper.valueToDefaultExpr(other)])
  }

  func mod(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("mod", [self, other])
  }

  func mod(_ other: Any) -> FunctionExpr {
    return FunctionExpr("mod", [self, Helper.valueToDefaultExpr(other)])
  }

  // MARK: Array Operations

  func arrayConcat(_ secondArray: Expr, _ otherArrays: Expr...) -> FunctionExpr {
    return FunctionExpr("array_concat", [self, secondArray] + otherArrays)
  }

  func arrayConcat(_ secondArray: [Any], _ otherArrays: [Any]...) -> FunctionExpr {
    let exprs = [self] + [Helper.valueToDefaultExpr(secondArray)] + otherArrays
      .map { Helper.valueToDefaultExpr($0) }
    return FunctionExpr("array_concat", exprs)
  }

  func arrayContains(_ element: Expr) -> BooleanExpr {
    return BooleanExpr("array_contains", [self, element])
  }

  func arrayContains(_ element: Any) -> BooleanExpr {
    return BooleanExpr("array_contains", [self, Helper.valueToDefaultExpr(element)])
  }

  func arrayContainsAll(_ values: Expr...) -> BooleanExpr {
    return BooleanExpr("array_contains_all", [self] + values)
  }

  func arrayContainsAll(_ values: Any...) -> BooleanExpr {
    let exprValues = values.map { Helper.valueToDefaultExpr($0) }
    return BooleanExpr("array_contains_all", [self] + exprValues)
  }

  func arrayContainsAny(_ values: Expr...) -> BooleanExpr {
    return BooleanExpr("array_contains_any", [self] + values)
  }

  func arrayContainsAny(_ values: Any...) -> BooleanExpr {
    let exprValues = values.map { Helper.valueToDefaultExpr($0) }
    return BooleanExpr("array_contains_any", [self] + exprValues)
  }

  func arrayLength() -> FunctionExpr {
    return FunctionExpr("array_length", [self])
  }

  func arrayOffset(_ offset: Int) -> FunctionExpr {
    return FunctionExpr("array_offset", [self, Helper.valueToDefaultExpr(offset)])
  }

  func arrayOffset(_ offsetExpr: Expr) -> FunctionExpr {
    return FunctionExpr("array_offset", [self, offsetExpr])
  }

  // MARK: Equality with Any

  func eqAny(_ others: Expr...) -> BooleanExpr {
    return BooleanExpr("eq_any", [self] + others)
  }

  func eqAny(_ others: Any...) -> BooleanExpr {
    let exprOthers = others.map { Helper.valueToDefaultExpr($0) }
    return BooleanExpr("eq_any", [self] + exprOthers)
  }

  func notEqAny(_ others: Expr...) -> BooleanExpr {
    return BooleanExpr("not_eq_any", [self] + others)
  }

  func notEqAny(_ others: Any...) -> BooleanExpr {
    let exprOthers = others.map { Helper.valueToDefaultExpr($0) }
    return BooleanExpr("not_eq_any", [self] + exprOthers)
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
    return FunctionExpr("like", [self, Helper.valueToDefaultExpr(pattern)])
  }

  func like(_ pattern: Expr) -> FunctionExpr {
    return FunctionExpr("like", [self, pattern])
  }

  func regexContains(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("regex_contains", [self, Helper.valueToDefaultExpr(pattern)])
  }

  func regexContains(_ pattern: Expr) -> BooleanExpr {
    return BooleanExpr("regex_contains", [self, pattern])
  }

  func regexMatch(_ pattern: String) -> BooleanExpr {
    return BooleanExpr("regex_match", [self, Helper.valueToDefaultExpr(pattern)])
  }

  func regexMatch(_ pattern: Expr) -> BooleanExpr {
    return BooleanExpr("regex_match", [self, pattern])
  }

  func strContains(_ substring: String) -> BooleanExpr {
    return BooleanExpr("str_contains", [self, Helper.valueToDefaultExpr(substring)])
  }

  func strContains(_ expr: Expr) -> BooleanExpr {
    return BooleanExpr("str_contains", [self, expr])
  }

  func startsWith(_ prefix: String) -> BooleanExpr {
    return BooleanExpr("starts_with", [self, Helper.valueToDefaultExpr(prefix)])
  }

  func startsWith(_ prefix: Expr) -> BooleanExpr {
    return BooleanExpr("starts_with", [self, prefix])
  }

  func endsWith(_ suffix: String) -> BooleanExpr {
    return BooleanExpr("ends_with", [self, Helper.valueToDefaultExpr(suffix)])
  }

  func endsWith(_ suffix: Expr) -> BooleanExpr {
    return BooleanExpr("ends_with", [self, suffix])
  }

  func toLower() -> FunctionExpr {
    return FunctionExpr("to_lower", [self])
  }

  func toUpper() -> FunctionExpr {
    return FunctionExpr("to_upper", [self])
  }

  func trim() -> FunctionExpr {
    return FunctionExpr("trim", [self])
  }

  func strConcat(_ secondString: Expr, _ otherStrings: Expr...) -> FunctionExpr {
    return FunctionExpr("str_concat", [self, secondString] + otherStrings)
  }

  func strConcat(_ secondString: String, _ otherStrings: String...) -> FunctionExpr {
    let exprs = [self] + [Helper.valueToDefaultExpr(secondString)] + otherStrings
      .map { Helper.valueToDefaultExpr($0) }
    return FunctionExpr("str_concat", exprs)
  }

  func reverse() -> FunctionExpr {
    return FunctionExpr("reverse", [self])
  }

  func replaceFirst(_ find: String, _ replace: String) -> FunctionExpr {
    return FunctionExpr(
      "replace_first",
      [self, Helper.valueToDefaultExpr(find), Helper.valueToDefaultExpr(replace)]
    )
  }

  func replaceFirst(_ find: Expr, _ replace: Expr) -> FunctionExpr {
    return FunctionExpr("replace_first", [self, find, replace])
  }

  func replaceAll(_ find: String, _ replace: String) -> FunctionExpr {
    return FunctionExpr(
      "replace_all",
      [self, Helper.valueToDefaultExpr(find), Helper.valueToDefaultExpr(replace)]
    )
  }

  func replaceAll(_ find: Expr, _ replace: Expr) -> FunctionExpr {
    return FunctionExpr("replace_all", [self, find, replace])
  }

  func byteLength() -> FunctionExpr {
    return FunctionExpr("byte_length", [self])
  }

  func substr(_ position: Int, _ length: Int? = nil) -> FunctionExpr {
    let positionExpr = Helper.valueToDefaultExpr(position)
    if let length = length {
      return FunctionExpr("substr", [self, positionExpr, Helper.valueToDefaultExpr(length)])
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
    return FunctionExpr("map_remove", [self, Helper.valueToDefaultExpr(key)])
  }

  func mapRemove(_ keyExpr: Expr) -> FunctionExpr {
    return FunctionExpr("map_remove", [self, keyExpr])
  }

  func mapMerge(_ secondMap: [String: Any], _ otherMaps: [String: Any]...) -> FunctionExpr {
    let secondMapExpr = Helper.valueToDefaultExpr(secondMap)
    let otherMapExprs = otherMaps.map { Helper.valueToDefaultExpr($0) }
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

  func logicalMaximum(_ second: Any, _ others: Any...) -> FunctionExpr {
    let exprs = [self] + [Helper.valueToDefaultExpr(second)] + others
      .map { Helper.valueToDefaultExpr($0) }
    return FunctionExpr("logical_maximum", exprs)
  }

  func logicalMinimum(_ second: Expr, _ others: Expr...) -> FunctionExpr {
    return FunctionExpr("logical_min", [self, second] + others)
  }

  func logicalMinimum(_ second: Any, _ others: Any...) -> FunctionExpr {
    let exprs = [self] + [Helper.valueToDefaultExpr(second)] + others
      .map { Helper.valueToDefaultExpr($0) }
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
    return FunctionExpr("cosine_distance", [self, Helper.valueToDefaultExpr(other)])
  }

  func dotProduct(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, other])
  }

  func dotProduct(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, Helper.vectorToExpr(other)])
  }

  func dotProduct(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("dot_product", [self, Helper.valueToDefaultExpr(other)])
  }

  func euclideanDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, other])
  }

  func euclideanDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, Helper.vectorToExpr(other)])
  }

  func euclideanDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("euclidean_distance", [self, Helper.valueToDefaultExpr(other)])
  }

  func manhattanDistance(_ other: Expr) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, other])
  }

  func manhattanDistance(_ other: VectorValue) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, Helper.vectorToExpr(other)])
  }

  func manhattanDistance(_ other: [Double]) -> FunctionExpr {
    return FunctionExpr("manhattan_distance", [self, Helper.valueToDefaultExpr(other)])
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
      [self, Helper.timeUnitToExpr(unit), Helper.valueToDefaultExpr(amount)]
    )
  }

  func timestampSub(_ unit: Expr, _ amount: Expr) -> FunctionExpr {
    return FunctionExpr("timestamp_sub", [self, unit, amount])
  }

  func timestampSub(_ unit: TimeUnit, _ amount: Int) -> FunctionExpr {
    return FunctionExpr(
      "timestamp_sub",
      [self, Helper.timeUnitToExpr(unit), Helper.valueToDefaultExpr(amount)]
    )
  }

  // MARK: - Bitwise operations

  func bitAnd(_ otherBits: Int) -> FunctionExpr {
    return FunctionExpr("bit_and", [self, Helper.valueToDefaultExpr(otherBits)])
  }

  func bitAnd(_ otherBits: UInt8) -> FunctionExpr {
    return FunctionExpr("bit_and", [self, Helper.valueToDefaultExpr(otherBits)])
  }

  func bitAnd(_ bitsExpression: Expr) -> FunctionExpr {
    return FunctionExpr("bit_and", [self, bitsExpression])
  }

  func bitOr(_ otherBits: Int) -> FunctionExpr {
    return FunctionExpr("bit_or", [self, Helper.valueToDefaultExpr(otherBits)])
  }

  func bitOr(_ otherBits: UInt8) -> FunctionExpr {
    return FunctionExpr("bit_or", [self, Helper.valueToDefaultExpr(otherBits)])
  }

  func bitOr(_ bitsExpression: Expr) -> FunctionExpr {
    return FunctionExpr("bit_or", [self, bitsExpression])
  }

  func bitXor(_ otherBits: Int) -> FunctionExpr {
    return FunctionExpr("bit_xor", [self, Helper.valueToDefaultExpr(otherBits)])
  }

  func bitXor(_ otherBits: UInt8) -> FunctionExpr {
    return FunctionExpr("bit_xor", [self, Helper.valueToDefaultExpr(otherBits)])
  }

  func bitXor(_ bitsExpression: Expr) -> FunctionExpr {
    return FunctionExpr("bit_xor", [self, bitsExpression])
  }

  func bitNot() -> FunctionExpr {
    return FunctionExpr("bit_not", [self])
  }

  func bitLeftShift(_ y: Int) -> FunctionExpr {
    return FunctionExpr("bit_left_shift", [self, Helper.valueToDefaultExpr(y)])
  }

  func bitLeftShift(_ numberExpr: Expr) -> FunctionExpr {
    return FunctionExpr("bit_left_shift", [self, numberExpr])
  }

  func bitRightShift(_ y: Int) -> FunctionExpr {
    return FunctionExpr("bit_right_shift", [self, Helper.valueToDefaultExpr(y)])
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

  func ifError(_ catchValue: Any) -> FunctionExpr {
    return FunctionExpr("if_error", [self, Helper.valueToDefaultExpr(catchValue)])
  }

  // MARK: Sorting

  func ascending() -> Ordering {
    return Ordering(expr: self, direction: .ascending)
  }

  func descending() -> Ordering {
    return Ordering(expr: self, direction: .descending)
  }
}

// protocal cannot overwrite operator, since every inheritated class will have this function
// it will lead to error: Generic parameter 'Self' could not be inferred

public func > (lhs: Expr, rhs: @autoclosure () throws -> Any) rethrows -> BooleanExpr {
  try BooleanExpr("gt", [lhs, Helper.valueToDefaultExpr(rhs())])
}

public func < (lhs: Expr, rhs: @autoclosure () throws -> Any) rethrows -> BooleanExpr {
  try BooleanExpr("lt", [lhs, Helper.valueToDefaultExpr(rhs())])
}

public func <= (lhs: Expr, rhs: @autoclosure () throws -> Any) rethrows -> BooleanExpr {
  try BooleanExpr("lte", [lhs, Helper.valueToDefaultExpr(rhs())])
}

public func == (lhs: Expr, rhs: @autoclosure () throws -> Any) rethrows -> BooleanExpr {
  try BooleanExpr("eq", [lhs, Helper.valueToDefaultExpr(rhs())])
}
