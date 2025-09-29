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

  /// Creates an expression applying bitwise AND between this expression and an integer literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise AND of "flags" field and 0xFF
  /// Field("flags").bitAnd(0xFF)
  /// ```
  ///
  /// - Parameter otherBits: The integer literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise AND operation.
  func bitAnd(_ otherBits: Int) -> FunctionExpression {
    return FunctionExpression("bit_and", [self, Helper.sendableToExpr(otherBits)])
  }

  /// Creates an expression applying bitwise AND between this expression and a UInt8 literal (often
  /// for byte masks).
  /// Assumes `self` evaluates to an Integer or Bytes.
  /// - Note: This API is in beta.
  /// ```swift
  /// // Bitwise AND of "byteFlags" field and a byte mask
  /// Field("byteFlags").bitAnd(0b00001111 as UInt8)
  /// ```
  /// - Parameter otherBits: The UInt8 literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise AND operation.
  func bitAnd(_ otherBits: UInt8) -> FunctionExpression {
    return FunctionExpression("bit_and", [self, Helper.sendableToExpr(otherBits)])
  }

  /// Creates an expression applying bitwise AND between this expression and another expression.
  /// Assumes `self` and `bitsExpression` evaluate to Integer or Bytes.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise AND of "mask1" and "mask2" fields
  /// Field("mask1").bitAnd(Field("mask2"))
  /// ```
  /// - Parameter bitsExpression: The other `Expr` operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise AND operation.
  func bitAnd(_ bitsExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_and", [self, bitsExpression])
  }

  /// Creates an expression applying bitwise OR between this expression and an integer literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise OR of "flags" field and 0x01
  /// Field("flags").bitOr(0x01)
  /// ```
  ///
  /// - Parameter otherBits: The integer literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise OR operation.
  func bitOr(_ otherBits: Int) -> FunctionExpression {
    return FunctionExpression("bit_or", [self, Helper.sendableToExpr(otherBits)])
  }

  /// Creates an expression applying bitwise OR between this expression and a UInt8 literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  /// - Note: This API is in beta.
  /// ```swift
  /// // Set specific bits in "controlByte"
  /// Field("controlByte").bitOr(0b10000001 as UInt8)
  /// ```
  /// - Parameter otherBits: The UInt8 literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise OR operation.
  func bitOr(_ otherBits: UInt8) -> FunctionExpression {
    return FunctionExpression("bit_or", [self, Helper.sendableToExpr(otherBits)])
  }

  /// Creates an expression applying bitwise OR between this expression and another expression.
  /// Assumes `self` and `bitsExpression` evaluate to Integer or Bytes.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise OR of "permissionSet1" and "permissionSet2" fields
  /// Field("permissionSet1").bitOr(Field("permissionSet2"))
  /// ```
  /// - Parameter bitsExpression: The other `Expr` operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise OR operation.
  func bitOr(_ bitsExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_or", [self, bitsExpression])
  }

  /// Creates an expression applying bitwise XOR between this expression and an integer literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise XOR of "toggle" field and 0xFFFF
  /// Field("toggle").bitXor(0xFFFF)
  /// ```
  ///
  /// - Parameter otherBits: The integer literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise XOR operation.
  func bitXor(_ otherBits: Int) -> FunctionExpression {
    return FunctionExpression("bit_xor", [self, Helper.sendableToExpr(otherBits)])
  }

  /// Creates an expression applying bitwise XOR between this expression and a UInt8 literal.
  /// Assumes `self` evaluates to an Integer or Bytes.
  /// - Note: This API is in beta.
  /// ```swift
  /// // Toggle bits in "statusByte" using a XOR mask
  /// Field("statusByte").bitXor(0b01010101 as UInt8)
  /// ```
  /// - Parameter otherBits: The UInt8 literal operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise XOR operation.
  func bitXor(_ otherBits: UInt8) -> FunctionExpression {
    return FunctionExpression("bit_xor", [self, Helper.sendableToExpr(otherBits)])
  }

  /// Creates an expression applying bitwise XOR between this expression and another expression.
  /// Assumes `self` and `bitsExpression` evaluate to Integer or Bytes.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise XOR of "key1" and "key2" fields (assuming Bytes)
  /// Field("key1").bitXor(Field("key2"))
  /// ```
  /// - Parameter bitsExpression: The other `Expr` operand.
  /// - Returns: A new "FunctionExpression" representing the bitwise XOR operation.
  func bitXor(_ bitsExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_xor", [self, bitsExpression])
  }

  /// Creates an expression applying bitwise NOT to this expression.
  /// Assumes `self` evaluates to an Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Bitwise NOT of "mask" field
  /// Field("mask").bitNot()
  /// ```
  ///
  /// - Returns: A new "FunctionExpression" representing the bitwise NOT operation.
  func bitNot() -> FunctionExpression {
    return FunctionExpression("bit_not", [self])
  }

  /// Creates an expression applying bitwise left shift to this expression by a literal number of
  /// bits.
  /// Assumes `self` evaluates to Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Left shift "value" field by 2 bits
  /// Field("value").bitLeftShift(2)
  /// ```
  ///
  /// - Parameter y: The number of bits (Int literal) to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise left shift operation.
  func bitLeftShift(_ y: Int) -> FunctionExpression {
    return FunctionExpression("bit_left_shift", [self, Helper.sendableToExpr(y)])
  }

  /// Creates an expression applying bitwise left shift to this expression by a number of bits
  /// specified by an expression.
  /// Assumes `self` evaluates to Integer or Bytes, and `numberExpr` evaluates to an Integer.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Left shift "data" by number of bits in "shiftCount" field
  /// Field("data").bitLeftShift(Field("shiftCount"))
  /// ```
  /// - Parameter numberExpr: An `Expr` (evaluating to an Int) for the number of bits to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise left shift operation.
  func bitLeftShift(_ numberExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_left_shift", [self, numberExpression])
  }

  /// Creates an expression applying bitwise right shift to this expression by a literal number of
  /// bits.
  /// Assumes `self` evaluates to Integer or Bytes.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Right shift "value" field by 4 bits
  /// Field("value").bitRightShift(4)
  /// ```
  ///
  /// - Parameter y: The number of bits (Int literal) to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise right shift operation.
  func bitRightShift(_ y: Int) -> FunctionExpression {
    return FunctionExpression("bit_right_shift", [self, Helper.sendableToExpr(y)])
  }

  /// Creates an expression applying bitwise right shift to this expression by a number of bits
  /// specified by an expression.
  /// Assumes `self` evaluates to Integer or Bytes, and `numberExpr` evaluates to an Integer.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Right shift "data" by number of bits in "shiftCount" field
  /// Field("data").bitRightShift(Field("shiftCount"))
  /// ```
  /// - Parameter numberExpr: An `Expr` (evaluating to an Int) for the number of bits to shift by.
  /// - Returns: A new "FunctionExpression" representing the bitwise right shift operation.
  func bitRightShift(_ numberExpression: Expression) -> FunctionExpression {
    return FunctionExpression("bit_right_shift", [self, numberExpression])
  }
}

public extension Expression {
  func `as`(_ name: String) -> AliasedExpression {
    return AliasedExpression(self, name)
  }

  // MARK: Arithmetic Operators

  func abs() -> FunctionExpression {
    return FunctionExpression("abs", [self])
  }

  func ceil() -> FunctionExpression {
    return FunctionExpression("ceil", [self])
  }

  func exp() -> FunctionExpression {
    return FunctionExpression("exp", [self])
  }

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

  func arrayReverse() -> FunctionExpression {
    return FunctionExpression("array_reverse", [self])
  }

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

  func arrayContainsAll(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanExpression("array_contains_all", [self, arrayExpression])
  }

  func arrayContainsAny(_ values: [Expression]) -> BooleanExpression {
    return BooleanExpression("array_contains_any", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpression {
    return BooleanExpression("array_contains_any", [self, Helper.array(values)])
  }

  func arrayContainsAny(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanExpression("array_contains_any", [self, arrayExpression])
  }

  func arrayLength() -> FunctionExpression {
    return FunctionExpression("array_length", [self])
  }

  func arrayGet(_ offset: Int) -> FunctionExpression {
    return FunctionExpression("array_get", [self, Helper.sendableToExpr(offset)])
  }

  func arrayGet(_ offsetExpression: Expression) -> FunctionExpression {
    return FunctionExpression("array_get", [self, offsetExpression])
  }

  func greaterThan(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("greater_than", [self, other])
  }

  func greaterThan(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("greater_than", [self, exprOther])
  }

  func greaterThanOrEqual(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("greater_than_or_equal", [self, other])
  }

  func greaterThanOrEqual(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("greater_than_or_equal", [self, exprOther])
  }

  func lessThan(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("less_than", [self, other])
  }

  func lessThan(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("less_than", [self, exprOther])
  }

  func lessThanOrEqual(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("less_than_or_equal", [self, other])
  }

  func lessThanOrEqual(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("less_than_or_equal", [self, exprOther])
  }

  func equal(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("equal", [self, other])
  }

  func equal(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanExpression("equal", [self, exprOther])
  }

  func notEqual(_ other: Expression) -> BooleanExpression {
    return BooleanExpression("not_equal", [self, other])
  }

  func notEqual(_ other: Sendable) -> BooleanExpression {
    return BooleanExpression("not_equal", [self, Helper.sendableToExpr(other)])
  }

  func equalAny(_ others: [Expression]) -> BooleanExpression {
    return BooleanExpression("equal_any", [self, Helper.array(others)])
  }

  func equalAny(_ others: [Sendable]) -> BooleanExpression {
    return BooleanExpression("equal_any", [self, Helper.array(others)])
  }

  func equalAny(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanExpression("equal_any", [self, arrayExpression])
  }

  func notEqualAny(_ others: [Expression]) -> BooleanExpression {
    return BooleanExpression("not_equal_any", [self, Helper.array(others)])
  }

  func notEqualAny(_ others: [Sendable]) -> BooleanExpression {
    return BooleanExpression("not_equal_any", [self, Helper.array(others)])
  }

  func notEqualAny(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanExpression("not_equal_any", [self, arrayExpression])
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
    return BooleanExpression("string_contains", [self, Helper.sendableToExpr(substring)])
  }

  func string_contains(_ expression: Expression) -> BooleanExpression {
    return BooleanExpression("string_contains", [self, expression])
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

  func toLower() -> FunctionExpression {
    return FunctionExpression("to_lower", [self])
  }

  func toUpper() -> FunctionExpression {
    return FunctionExpression("to_upper", [self])
  }

  func trim() -> FunctionExpression {
    return FunctionExpression("trim", [self])
  }

  func stringConcat(_ strings: [Expression]) -> FunctionExpression {
    return FunctionExpression("string_concat", [self] + strings)
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

  func mapRemove(_ keyExpression: Expression) -> FunctionExpression {
    return FunctionExpression("map_remove", [self, keyExpression])
  }

  func mapMerge(_ maps: [[String: Sendable]]) -> FunctionExpression {
    let mapExprs = maps.map { Helper.sendableToExpr($0) }
    return FunctionExpression("map_merge", [self] + mapExprs)
  }

  func mapMerge(_ maps: [Expression]) -> FunctionExpression {
    return FunctionExpression("map_merge", [self] + maps)
  }

  // --- Added Aggregate Operations (on Expr) ---

  func countDistinct() -> AggregateFunction {
    return AggregateFunction("count_distinct", [self])
  }

  func count() -> AggregateFunction {
    return AggregateFunction("count", [self])
  }

  func sum() -> AggregateFunction {
    return AggregateFunction("sum", [self])
  }

  func average() -> AggregateFunction {
    return AggregateFunction("average", [self])
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

  func cosineDistance(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression("cosine_distance", [self, expression])
  }

  func cosineDistance(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression("cosine_distance", [self, Helper.sendableToExpr(vector)])
  }

  func cosineDistance(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression("cosine_distance", [self, Helper.sendableToExpr(vector)])
  }

  func dotProduct(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression("dot_product", [self, expression])
  }

  func dotProduct(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression("dot_product", [self, Helper.sendableToExpr(vector)])
  }

  func dotProduct(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression("dot_product", [self, Helper.sendableToExpr(vector)])
  }

  func euclideanDistance(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression("euclidean_distance", [self, expression])
  }

  func euclideanDistance(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression("euclidean_distance", [self, Helper.sendableToExpr(vector)])
  }

  func euclideanDistance(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression("euclidean_distance", [self, Helper.sendableToExpr(vector)])
  }

  func manhattanDistance(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression("manhattan_distance", [self, expression])
  }

  func manhattanDistance(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression("manhattan_distance", [self, Helper.sendableToExpr(vector)])
  }

  func manhattanDistance(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression("manhattan_distance", [self, Helper.sendableToExpr(vector)])
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
    return FunctionExpression("timestamp_subtract", [self, unit, amount])
  }

  func timestampSub(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression {
    return FunctionExpression(
      "timestamp_subtract",
      [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func documentId() -> FunctionExpression {
    return FunctionExpression("document_id", [self])
  }

  func collectionId() -> FunctionExpression {
    return FunctionExpression("collection_id", [self])
  }

  func ifError(_ catchExpression: Expression) -> FunctionExpression {
    return FunctionExpression("if_error", [self, catchExpression])
  }

  func ifError(_ catchValue: Sendable) -> FunctionExpression {
    return FunctionExpression("if_error", [self, Helper.sendableToExpr(catchValue)])
  }

  // MARK: Sorting

  func ascending() -> Ordering {
    return Ordering(expression: self, direction: .ascending)
  }

  func descending() -> Ordering {
    return Ordering(expression: self, direction: .descending)
  }
}
