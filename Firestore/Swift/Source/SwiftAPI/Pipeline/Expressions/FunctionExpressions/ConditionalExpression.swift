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
