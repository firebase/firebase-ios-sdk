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

import Foundation

///
/// A `ConditionalExpression` is a `FunctionExpression` that evaluates to one of two expressions
/// based on a boolean condition.
///
/// This is equivalent to a ternary operator (`condition ? then : else`).
///
/// Example of using `ConditionalExpression`:
/// ```swift
/// // Create a new field "status" based on the "rating" field.
/// // If rating > 4.5, status is "top_rated", otherwise "regular".
/// firestore.pipeline()
///   .collection("products")
///   .addFields([
///     ConditionalExpression(
///       Field("rating").greaterThan(4.5),
///       then: Constant("top_rated"),
///       else: Constant("regular")
///     ).as("status")
///   ])
/// ```
public class ConditionalExpression: FunctionExpression, @unchecked Sendable {
  /// Creates a new `ConditionalExpression`.
  ///
  /// - Parameters:
  ///   - expression: The `BooleanExpression` to evaluate.
  ///   - thenExpression: The `Expression` to evaluate if the boolean expression is `true`.
  ///   - elseExpression: The `Expression` to evaluate if the boolean expression is `false`.
  public init(_ expression: BooleanExpression,
              then thenExpression: Expression,
              else elseExpression: Expression) {
    super.init(functionName: "conditional", args: [expression, thenExpression, elseExpression])
  }
}

/// Evaluates alternating condition/result pairs and returns the result corresponding to the first
/// `true` condition.
///
/// This provides a multi-way conditional (switch/case) expression. It accepts a sequence of
/// `BooleanExpression` and `Expression` pairs. An optional final argument acts as a default
/// (else) result. If no default is provided and no condition evaluates to `true`, the expression
// throws an error.
///
/// ```swift
/// // Create a "sizeCategory" field based on the "amount" field.
/// firestore.pipeline()
///   .collection("items")
///   .addFields([
///     switchOn(
///       Field("amount").lessThan(10), Constant("Small"),
///       Field("amount").lessThan(100), Constant("Medium"),
///       Constant("Large")
///     ).as("sizeCategory")
///   ])
/// ```
///
/// - Parameters:
///   - condition: The first condition to evaluate.
///   - result: The expression to return if the first condition is `true`.
///   - others: Additional condition/result pairs, optionally followed by a default expression.
/// - Returns: A new `Expression` representing the `switchOn` logic.
public func switchOn(_ condition: BooleanExpression,
                     _ result: Expression,
                     _ others: Expression...) -> Expression {
  var args: [Expression] = [condition, result]
  args.append(contentsOf: others)
  return FunctionExpression(functionName: "switch_on", args: args)
}
