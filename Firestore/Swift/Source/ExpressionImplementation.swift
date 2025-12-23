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
    return FunctionExpression(
      functionName: "bit_and",
      args: [self, Helper.sendableToExpr(otherBits)]
    )
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
    return FunctionExpression(
      functionName: "bit_and",
      args: [self, Helper.sendableToExpr(otherBits)]
    )
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
    return FunctionExpression(functionName: "bit_and", args: [self, bitsExpression])
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
    return FunctionExpression(
      functionName: "bit_or",
      args: [self, Helper.sendableToExpr(otherBits)]
    )
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
    return FunctionExpression(
      functionName: "bit_or",
      args: [self, Helper.sendableToExpr(otherBits)]
    )
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
    return FunctionExpression(functionName: "bit_or", args: [self, bitsExpression])
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
    return FunctionExpression(
      functionName: "bit_xor",
      args: [self, Helper.sendableToExpr(otherBits)]
    )
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
    return FunctionExpression(
      functionName: "bit_xor",
      args: [self, Helper.sendableToExpr(otherBits)]
    )
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
    return FunctionExpression(functionName: "bit_xor", args: [self, bitsExpression])
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
    return FunctionExpression(functionName: "bit_not", args: [self])
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
    return FunctionExpression(
      functionName: "bit_left_shift",
      args: [self, Helper.sendableToExpr(y)]
    )
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
    return FunctionExpression(functionName: "bit_left_shift", args: [self, numberExpression])
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
    return FunctionExpression(
      functionName: "bit_right_shift",
      args: [self, Helper.sendableToExpr(y)]
    )
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
    return FunctionExpression(functionName: "bit_right_shift", args: [self, numberExpression])
  }

  /// Calculates the Manhattan (L1) distance between this vector expression and another vector
  /// expression.
  /// Assumes both `self` and `other` evaluate to Vectors.
  ///
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Manhattan distance between "vector1" field and "vector2" field
  /// Field("vector1").manhattanDistance(Field("vector2"))
  /// ```
  ///
  /// - Parameter expression: The other vector as an `Expr` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Manhattan distance.
  func manhattanDistance(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "manhattan_distance", args: [self, expression])
  }

  /// Calculates the Manhattan (L1) distance between this vector expression and another vector
  /// literal (`VectorValue`).
  /// Assumes `self` evaluates to a Vector.
  /// - Note: This API is in beta.
  /// ```swift
  /// let referencePoint = VectorValue(vector: [5.0, 10.0])
  /// Field("dataPoint").manhattanDistance(referencePoint)
  /// ```
  /// - Parameter vector: The other vector as a `VectorValue` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Manhattan distance.
  func manhattanDistance(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression(
      functionName: "manhattan_distance",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  /// Calculates the Manhattan (L1) distance between this vector expression and another vector
  /// literal (`[Double]`).
  /// Assumes `self` evaluates to a Vector.
  /// - Note: This API is in beta.
  ///
  /// ```swift
  /// // Manhattan distance between "point" field and a target point
  /// Field("point").manhattanDistance([10.0, 20.0])
  /// ```
  /// - Parameter vector: The other vector as `[Double]` to compare against.
  /// - Returns: A new `FunctionExpression` representing the Manhattan distance.
  func manhattanDistance(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression(
      functionName: "manhattan_distance",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  /// Creates an expression that replaces the first occurrence of a literal substring within this
  /// string expression with another literal substring.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Replace the first "hello" with "hi" in the "message" field
  /// Field("message").replaceFirst("hello", "hi")
  /// ```
  ///
  /// - Parameter find: The literal string substring to search for.
  /// - Parameter replace: The literal string substring to replace the first occurrence with.
  /// - Returns: A new `FunctionExpr` representing the string with the first occurrence replaced.
  func replaceFirst(_ find: String, with replace: String) -> FunctionExpression {
    return FunctionExpression(
      functionName: "replace_first",
      args: [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  /// Creates an expression that replaces the first occurrence of a substring (from an expression)
  /// within this string expression with another substring (from an expression).
  /// Assumes `self` evaluates to a string, and `find`/`replace` evaluate to strings.
  ///
  /// ```swift
  /// // Replace first occurrence of field "findPattern" with field "replacePattern" in "text"
  /// Field("text").replaceFirst(Field("findPattern"), Field("replacePattern"))
  /// ```
  ///
  /// - Parameter find: An `Expr` (evaluating to a string) for the substring to search for.
  /// - Parameter replace: An `Expr` (evaluating to a string) for the substring to replace the first
  /// occurrence with.
  /// - Returns: A new `FunctionExpr` representing the string with the first occurrence replaced.
  func replaceFirst(_ find: Expression, with replace: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "replace_first", args: [self, find, replace])
  }

  /// Creates an expression that replaces all occurrences of a literal substring within this string
  /// expression with another literal substring.
  /// Assumes `self` evaluates to a string.
  ///
  /// ```swift
  /// // Replace all occurrences of " " with "_" in "description"
  /// Field("description").stringReplace(" ", "_")
  /// ```
  ///
  /// - Parameter find: The literal string substring to search for.
  /// - Parameter replace: The literal string substring to replace all occurrences with.
  /// - Returns: A new `FunctionExpr` representing the string with all occurrences replaced.
  func stringReplace(_ find: String, with replace: String) -> FunctionExpression {
    return FunctionExpression(
      functionName: "string_replace",
      args: [self, Helper.sendableToExpr(find), Helper.sendableToExpr(replace)]
    )
  }

  /// Creates an expression that replaces all occurrences of a substring (from an expression) within
  /// this string expression with another substring (from an expression).
  /// Assumes `self` evaluates to a string, and `find`/`replace` evaluate to strings.
  ///
  /// ```swift
  /// // Replace all occurrences of field "target" with field "replacement" in "content"
  /// Field("content").stringReplace(Field("target"), Field("replacement"))
  /// ```
  ///
  /// - Parameter find: An `Expression` (evaluating to a string) for the substring to search for.
  /// - Parameter replace: An `Expression` (evaluating to a string) for the substring to replace all
  /// occurrences with.
  /// - Returns: A new `FunctionExpression` representing the string with all occurrences replaced.
  func stringReplace(_ find: Expression, with replace: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "string_replace", args: [self, find, replace])
  }
}

public extension Expression {
  func asBoolean() -> BooleanExpression {
    switch self {
    case let boolExpr as BooleanExpression:
      return boolExpr
    case let constant as Constant:
      return BooleanConstant(constant)
    case let field as Field:
      return BooleanField(field)
    case let funcExpr as FunctionExpression:
      return BooleanFunctionExpression(funcExpr)
    default:
      // This should be unreachable if all expression types are handled.
      fatalError(
        "Unknown expression type \(Swift.type(of: self)) cannot be converted to BooleanExpression"
      )
    }
  }

  func `as`(_ name: String) -> AliasedExpression {
    return AliasedExpression(self, name)
  }

  // MARK: Arithmetic Operators

  func abs() -> FunctionExpression {
    return FunctionExpression(functionName: "abs", args: [self])
  }

  func ceil() -> FunctionExpression {
    return FunctionExpression(functionName: "ceil", args: [self])
  }

  func floor() -> FunctionExpression {
    return FunctionExpression(functionName: "floor", args: [self])
  }

  func ln() -> FunctionExpression {
    return FunctionExpression(functionName: "ln", args: [self])
  }

  func pow(_ exponent: Sendable) -> FunctionExpression {
    return FunctionExpression(functionName: "pow", args: [self, Helper.sendableToExpr(exponent)])
  }

  func pow(_ exponent: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "pow", args: [self, exponent])
  }

  func round() -> FunctionExpression {
    return FunctionExpression(functionName: "round", args: [self])
  }

  func sqrt() -> FunctionExpression {
    return FunctionExpression(functionName: "sqrt", args: [self])
  }

  func exp() -> FunctionExpression {
    return FunctionExpression(functionName: "exp", args: [self])
  }

  func add(_ value: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "add", args: [self, value])
  }

  func add(_ value: Sendable) -> FunctionExpression {
    return FunctionExpression(functionName: "add", args: [self, Helper.sendableToExpr(value)])
  }

  func subtract(_ other: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "subtract", args: [self, other])
  }

  func subtract(_ other: Sendable) -> FunctionExpression {
    return FunctionExpression(functionName: "subtract", args: [self, Helper.sendableToExpr(other)])
  }

  func multiply(_ value: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "multiply", args: [self, value])
  }

  func multiply(_ value: Sendable) -> FunctionExpression {
    return FunctionExpression(functionName: "multiply", args: [self, Helper.sendableToExpr(value)])
  }

  func divide(_ other: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "divide", args: [self, other])
  }

  func divide(_ other: Sendable) -> FunctionExpression {
    return FunctionExpression(functionName: "divide", args: [self, Helper.sendableToExpr(other)])
  }

  func mod(_ other: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "mod", args: [self, other])
  }

  func mod(_ other: Sendable) -> FunctionExpression {
    return FunctionExpression(functionName: "mod", args: [self, Helper.sendableToExpr(other)])
  }

  // MARK: Array Operations

  func arrayReverse() -> FunctionExpression {
    return FunctionExpression(functionName: "array_reverse", args: [self])
  }

  func arrayConcat(_ arrays: [Expression]) -> FunctionExpression {
    return FunctionExpression(functionName: "array_concat", args: [self] + arrays)
  }

  func arrayConcat(_ arrays: [[Sendable]]) -> FunctionExpression {
    let exprs = [self] + arrays.map { Helper.sendableToExpr($0) }
    return FunctionExpression(functionName: "array_concat", args: exprs)
  }

  func arrayContains(_ element: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "array_contains", args: [self, element])
  }

  func arrayContains(_ element: Sendable) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains",
      args: [self, Helper.sendableToExpr(element)]
    )
  }

  func arrayContainsAll(_ values: [Expression]) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains_all",
      args: [self, Helper.array(values)]
    )
  }

  func arrayContainsAll(_ values: [Sendable]) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains_all",
      args: [self, Helper.array(values)]
    )
  }

  func arrayContainsAll(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains_all",
      args: [self, arrayExpression]
    )
  }

  func arrayContainsAny(_ values: [Expression]) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains_any",
      args: [self, Helper.array(values)]
    )
  }

  func arrayContainsAny(_ values: [Sendable]) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains_any",
      args: [self, Helper.array(values)]
    )
  }

  func arrayContainsAny(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "array_contains_any",
      args: [self, arrayExpression]
    )
  }

  func arrayLength() -> FunctionExpression {
    return FunctionExpression(functionName: "array_length", args: [self])
  }

  func arrayGet(_ offset: Int) -> FunctionExpression {
    return FunctionExpression(
      functionName: "array_get",
      args: [self, Helper.sendableToExpr(offset)]
    )
  }

  func arrayGet(_ offsetExpression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "array_get", args: [self, offsetExpression])
  }

  func arrayMaximum() -> FunctionExpression {
    return FunctionExpression(functionName: "maximum", args: [self])
  }

  func arrayMinimum() -> FunctionExpression {
    return FunctionExpression(functionName: "minimum", args: [self])
  }

  func greaterThan(_ other: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "greater_than", args: [self, other])
  }

  func greaterThan(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanFunctionExpression(functionName: "greater_than", args: [self, exprOther])
  }

  func greaterThanOrEqual(_ other: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "greater_than_or_equal", args: [self, other])
  }

  func greaterThanOrEqual(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanFunctionExpression(functionName: "greater_than_or_equal", args: [self, exprOther])
  }

  func lessThan(_ other: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "less_than", args: [self, other])
  }

  func lessThan(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanFunctionExpression(functionName: "less_than", args: [self, exprOther])
  }

  func lessThanOrEqual(_ other: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "less_than_or_equal", args: [self, other])
  }

  func lessThanOrEqual(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanFunctionExpression(functionName: "less_than_or_equal", args: [self, exprOther])
  }

  func equal(_ other: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "equal", args: [self, other])
  }

  func equal(_ other: Sendable) -> BooleanExpression {
    let exprOther = Helper.sendableToExpr(other)
    return BooleanFunctionExpression(functionName: "equal", args: [self, exprOther])
  }

  func notEqual(_ other: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "not_equal", args: [self, other])
  }

  func notEqual(_ other: Sendable) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "not_equal",
      args: [self, Helper.sendableToExpr(other)]
    )
  }

  func equalAny(_ others: [Expression]) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "equal_any", args: [self, Helper.array(others)])
  }

  func equalAny(_ others: [Sendable]) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "equal_any", args: [self, Helper.array(others)])
  }

  func equalAny(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "equal_any", args: [self, arrayExpression])
  }

  func notEqualAny(_ others: [Expression]) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "not_equal_any",
      args: [self, Helper.array(others)]
    )
  }

  func notEqualAny(_ others: [Sendable]) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "not_equal_any",
      args: [self, Helper.array(others)]
    )
  }

  func notEqualAny(_ arrayExpression: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "not_equal_any", args: [self, arrayExpression])
  }

  // MARK: Checks

  // --- Added Type Check Operations ---

  func exists() -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "exists", args: [self])
  }

  func isError() -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "is_error", args: [self])
  }

  func isAbsent() -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "is_absent", args: [self])
  }

  // --- Added String Operations ---

  func join(delimiter: String) -> FunctionExpression {
    return FunctionExpression(functionName: "join", args: [self, Constant(delimiter)])
  }

  func split(delimiter: String) -> FunctionExpression {
    return FunctionExpression(functionName: "split", args: [self, Constant(delimiter)])
  }

  func split(delimiter: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "split", args: [self, delimiter])
  }

  func length() -> FunctionExpression {
    return FunctionExpression(functionName: "length", args: [self])
  }

  func charLength() -> FunctionExpression {
    return FunctionExpression(functionName: "char_length", args: [self])
  }

  func like(_ pattern: String) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "like",
      args: [self, Helper.sendableToExpr(pattern)]
    )
  }

  func like(_ pattern: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "like", args: [self, pattern])
  }

  func regexContains(_ pattern: String) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "regex_contains",
      args: [self, Helper.sendableToExpr(pattern)]
    )
  }

  func regexContains(_ pattern: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "regex_contains", args: [self, pattern])
  }

  func regexMatch(_ pattern: String) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "regex_match",
      args: [self, Helper.sendableToExpr(pattern)]
    )
  }

  func regexMatch(_ pattern: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "regex_match", args: [self, pattern])
  }

  func stringContains(_ substring: String) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "string_contains",
      args: [self, Helper.sendableToExpr(substring)]
    )
  }

  func stringContains(_ expression: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "string_contains", args: [self, expression])
  }

  func startsWith(_ prefix: String) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "starts_with",
      args: [self, Helper.sendableToExpr(prefix)]
    )
  }

  func startsWith(_ prefix: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "starts_with", args: [self, prefix])
  }

  func endsWith(_ suffix: String) -> BooleanExpression {
    return BooleanFunctionExpression(
      functionName: "ends_with",
      args: [self, Helper.sendableToExpr(suffix)]
    )
  }

  func endsWith(_ suffix: Expression) -> BooleanExpression {
    return BooleanFunctionExpression(functionName: "ends_with", args: [self, suffix])
  }

  func toLower() -> FunctionExpression {
    return FunctionExpression(functionName: "to_lower", args: [self])
  }

  func toUpper() -> FunctionExpression {
    return FunctionExpression(functionName: "to_upper", args: [self])
  }

  func trim(_ value: String) -> FunctionExpression {
    return FunctionExpression(
      functionName: "trim",
      args: [self, Helper.sendableToExpr(value)]
    )
  }

  func trim(_ value: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "trim", args: [self, value])
  }

  func trim() -> FunctionExpression {
    return FunctionExpression(functionName: "trim", args: [self])
  }

  func stringConcat(_ strings: [Expression]) -> FunctionExpression {
    return FunctionExpression(functionName: "string_concat", args: [self] + strings)
  }

  func stringConcat(_ strings: [Sendable]) -> FunctionExpression {
    let exprs = [self] + strings.map { Helper.sendableToExpr($0) }
    return FunctionExpression(functionName: "string_concat", args: exprs)
  }

  func reverse() -> FunctionExpression {
    return FunctionExpression(functionName: "reverse", args: [self])
  }

  func stringReverse() -> FunctionExpression {
    return FunctionExpression(functionName: "string_reverse", args: [self])
  }

  func byteLength() -> FunctionExpression {
    return FunctionExpression(functionName: "byte_length", args: [self])
  }

  func substring(position: Int, length: Int? = nil) -> FunctionExpression {
    let positionExpr = Helper.sendableToExpr(position)
    if let length = length {
      return FunctionExpression(
        functionName: "substring",
        args: [self, positionExpr, Helper.sendableToExpr(length)]
      )
    } else {
      return FunctionExpression(functionName: "substring", args: [self, positionExpr])
    }
  }

  func substring(position: Expression, length: Expression? = nil) -> FunctionExpression {
    if let length = length {
      return FunctionExpression(functionName: "substring", args: [self, position, length])
    } else {
      return FunctionExpression(functionName: "substring", args: [self, position])
    }
  }

  // --- Added Map Operations ---

  func mapGet(_ subfield: String) -> FunctionExpression {
    return FunctionExpression(functionName: "map_get", args: [self, Constant(subfield)])
  }

  func mapRemove(_ key: String) -> FunctionExpression {
    return FunctionExpression(functionName: "map_remove", args: [self, Helper.sendableToExpr(key)])
  }

  func mapRemove(_ keyExpression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "map_remove", args: [self, keyExpression])
  }

  func mapMerge(_ maps: [[String: Sendable]]) -> FunctionExpression {
    let mapExprs = maps.map { Helper.sendableToExpr($0) }
    return FunctionExpression(functionName: "map_merge", args: [self] + mapExprs)
  }

  func mapMerge(_ maps: [Expression]) -> FunctionExpression {
    return FunctionExpression(functionName: "map_merge", args: [self] + maps)
  }

  // --- Added Aggregate Operations (on Expr) ---

  func countDistinct() -> AggregateFunction {
    return AggregateFunction(functionName: "count_distinct", args: [self])
  }

  func count() -> AggregateFunction {
    return AggregateFunction(functionName: "count", args: [self])
  }

  func sum() -> AggregateFunction {
    return AggregateFunction(functionName: "sum", args: [self])
  }

  func average() -> AggregateFunction {
    return AggregateFunction(functionName: "average", args: [self])
  }

  func minimum() -> AggregateFunction {
    return AggregateFunction(functionName: "minimum", args: [self])
  }

  func maximum() -> AggregateFunction {
    return AggregateFunction(functionName: "maximum", args: [self])
  }

  // MARK: Logical min/max

  func logicalMaximum(_ expressions: [Expression]) -> FunctionExpression {
    return FunctionExpression(functionName: "maximum", args: [self] + expressions)
  }

  func logicalMaximum(_ values: [Sendable]) -> FunctionExpression {
    let exprs = [self] + values.map { Helper.sendableToExpr($0) }
    return FunctionExpression(functionName: "maximum", args: exprs)
  }

  func logicalMinimum(_ expressions: [Expression]) -> FunctionExpression {
    return FunctionExpression(functionName: "minimum", args: [self] + expressions)
  }

  func logicalMinimum(_ values: [Sendable]) -> FunctionExpression {
    let exprs = [self] + values.map { Helper.sendableToExpr($0) }
    return FunctionExpression(functionName: "minimum", args: exprs)
  }

  // MARK: Vector Operations

  func vectorLength() -> FunctionExpression {
    return FunctionExpression(functionName: "vector_length", args: [self])
  }

  func cosineDistance(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "cosine_distance", args: [self, expression])
  }

  func cosineDistance(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression(
      functionName: "cosine_distance",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  func cosineDistance(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression(
      functionName: "cosine_distance",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  func dotProduct(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "dot_product", args: [self, expression])
  }

  func dotProduct(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression(
      functionName: "dot_product",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  func dotProduct(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression(
      functionName: "dot_product",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  func euclideanDistance(_ expression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "euclidean_distance", args: [self, expression])
  }

  func euclideanDistance(_ vector: VectorValue) -> FunctionExpression {
    return FunctionExpression(
      functionName: "euclidean_distance",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  func euclideanDistance(_ vector: [Double]) -> FunctionExpression {
    return FunctionExpression(
      functionName: "euclidean_distance",
      args: [self, Helper.sendableToExpr(vector)]
    )
  }

  // MARK: Timestamp operations

  func unixMicrosToTimestamp() -> FunctionExpression {
    return FunctionExpression(functionName: "unix_micros_to_timestamp", args: [self])
  }

  func timestampToUnixMicros() -> FunctionExpression {
    return FunctionExpression(functionName: "timestamp_to_unix_micros", args: [self])
  }

  func unixMillisToTimestamp() -> FunctionExpression {
    return FunctionExpression(functionName: "unix_millis_to_timestamp", args: [self])
  }

  func timestampToUnixMillis() -> FunctionExpression {
    return FunctionExpression(functionName: "timestamp_to_unix_millis", args: [self])
  }

  func unixSecondsToTimestamp() -> FunctionExpression {
    return FunctionExpression(functionName: "unix_seconds_to_timestamp", args: [self])
  }

  func timestampToUnixSeconds() -> FunctionExpression {
    return FunctionExpression(functionName: "timestamp_to_unix_seconds", args: [self])
  }

  func timestampTruncate(granularity: TimeGranularity) -> FunctionExpression {
    return FunctionExpression(
      functionName: "timestamp_trunc",
      args: [self, Helper.sendableToExpr(granularity.rawValue)]
    )
  }

  func timestampTruncate(granularity: Sendable) -> FunctionExpression {
    return FunctionExpression(
      functionName: "timestamp_trunc",
      args: [self, Helper.sendableToExpr(granularity)]
    )
  }

  func timestampAdd(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression {
    return FunctionExpression(
      functionName: "timestamp_add",
      args: [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func timestampAdd(amount: Expression, unit: Sendable) -> FunctionExpression {
    return FunctionExpression(
      functionName: "timestamp_add",
      args: [self, Helper.sendableToExpr(unit), amount]
    )
  }

  func timestampSubtract(_ amount: Int, _ unit: TimeUnit) -> FunctionExpression {
    return FunctionExpression(
      functionName: "timestamp_subtract",
      args: [self, Helper.sendableToExpr(unit), Helper.sendableToExpr(amount)]
    )
  }

  func timestampSubtract(amount: Expression, unit: Sendable) -> FunctionExpression {
    return FunctionExpression(
      functionName: "timestamp_subtract",
      args: [self, Helper.sendableToExpr(unit), amount]
    )
  }

  func documentId() -> FunctionExpression {
    return FunctionExpression(functionName: "document_id", args: [self])
  }

  func collectionId() -> FunctionExpression {
    return FunctionExpression(functionName: "collection_id", args: [self])
  }

  func ifError(_ catchExpression: Expression) -> FunctionExpression {
    return FunctionExpression(functionName: "if_error", args: [self, catchExpression])
  }

  func ifError(_ catchValue: Sendable) -> FunctionExpression {
    return FunctionExpression(
      functionName: "if_error",
      args: [self, Helper.sendableToExpr(catchValue)]
    )
  }

  func ifAbsent(_ defaultValue: Sendable) -> FunctionExpression {
    return FunctionExpression(
      functionName: "if_absent",
      args: [self, Helper.sendableToExpr(defaultValue)]
    )
  }

  // MARK: Sorting

  func ascending() -> Ordering {
    return Ordering(expression: self, direction: .ascending)
  }

  func descending() -> Ordering {
    return Ordering(expression: self, direction: .descending)
  }

  func concat(_ values: [Sendable]) -> FunctionExpression {
    let exprs = [self] + values.map { Helper.sendableToExpr($0) }
    return FunctionExpression(functionName: "concat", args: exprs)
  }

  func type() -> FunctionExpression {
    return FunctionExpression(functionName: "type", args: [self])
  }
}
