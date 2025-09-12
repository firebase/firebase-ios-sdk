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
/// A `BooleanExpression` is a specialized `FunctionExpression` that evaluates to a boolean value.
///
/// It is used to construct conditional logic within Firestore pipelines, such as in `where`
/// clauses or `cond` expressions. `BooleanExpression` instances can be combined using standard
/// logical operators (`&&`, `||`, `!`, `^`) to create complex conditions.
///
/// Example usage in a `where` clause:
/// ```swift
/// firestore.pipeline()
///   .collection("products")
///   .where(
///     Field("price").greaterThan(100) &&
///     (Field("category").equal("electronics") || Field("on_sale").equal(true))
///   )
/// ```
public class BooleanExpression: FunctionExpression, @unchecked Sendable {
  override public init(_ functionName: String, _ agrs: [Expression]) {
    super.init(functionName, agrs)
  }

  /// Creates an aggregation that counts the number of documents for which this boolean expression
  /// evaluates to `true`.
  ///
  /// This is useful for counting documents that meet a specific condition without retrieving the
  /// documents themselves.
  ///
  /// ```swift
  /// // Count how many books were published after 1980
  /// let post1980Condition = Field("published").greaterThan(1980)
  /// firestore.pipeline()
  ///   .collection("books")
  ///   .aggregate([
  ///     post1980Condition.countIf().as("modernBooksCount")
  ///   ])
  /// ```
  ///
  /// - Returns: An `AggregateFunction` that performs the conditional count.
  public func countIf() -> AggregateFunction {
    return AggregateFunction("count_if", [self])
  }

  /// Creates a conditional expression that returns one of two specified expressions based on the
  /// result of this boolean expression.
  ///
  /// This is equivalent to a ternary operator (`condition ? then : else`).
  ///
  /// ```swift
  /// // Create a new field "status" based on the "rating" field.
  /// // If rating > 4.5, status is "top_rated", otherwise "regular".
  /// firestore.pipeline()
  ///   .collection("products")
  ///   .addFields([
  ///     Field("rating").greaterThan(4.5)
  ///       .then(Constant("top_rated"), else: Constant("regular"))
  ///       .as("status")
  ///   ])
  /// ```
  ///
  /// - Parameters:
  ///   - thenExpression: The `Expression` to evaluate if this boolean expression is `true`.
  ///   - elseExpression: The `Expression` to evaluate if this boolean expression is `false`.
  /// - Returns: A new `FunctionExpression` representing the conditional logic.
  public func then(_ thenExpression: Expression,
                   else elseExpression: Expression) -> FunctionExpression {
    return FunctionExpression("cond", [self, thenExpression, elseExpression])
  }

  /// Combines two boolean expressions with a logical AND (`&&`).
  ///
  /// The resulting expression is `true` only if both the left-hand side (`lhs`) and the right-hand
  /// side (`rhs`) are `true`.
  ///
  /// ```swift
  /// // Find books in the "Fantasy" genre with a rating greater than 4.5
  /// firestore.pipeline()
  ///   .collection("books")
  ///   .where(
  ///     Field("genre").equal("Fantasy") && Field("rating").greaterThan(4.5)
  ///   )
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand boolean expression.
  ///   - rhs: The right-hand boolean expression.
  /// - Returns: A new `BooleanExpression` representing the logical AND.
  public static func && (lhs: BooleanExpression,
                         rhs: @autoclosure () throws -> BooleanExpression) rethrows
    -> BooleanExpression {
    try BooleanExpression("and", [lhs, rhs()])
  }

  /// Combines two boolean expressions with a logical OR (`||`).
  ///
  /// The resulting expression is `true` if either the left-hand side (`lhs`) or the right-hand
  /// side (`rhs`) is `true`.
  ///
  /// ```swift
  /// // Find books that are either in the "Romance" genre or were published before 1900
  /// firestore.pipeline()
  ///   .collection("books")
  ///   .where(
  ///     Field("genre").equal("Romance") || Field("published").lessThan(1900)
  ///   )
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand boolean expression.
  ///   - rhs: The right-hand boolean expression.
  /// - Returns: A new `BooleanExpression` representing the logical OR.
  public static func || (lhs: BooleanExpression,
                         rhs: @autoclosure () throws -> BooleanExpression) rethrows
    -> BooleanExpression {
    try BooleanExpression("or", [lhs, rhs()])
  }

  /// Combines two boolean expressions with a logical XOR (`^`).
  ///
  /// The resulting expression is `true` if the left-hand side (`lhs`) and the right-hand side
  /// (`rhs`) have different boolean values.
  ///
  /// ```swift
  /// // Find books that are in the "Dystopian" genre OR have a rating of 5.0, but not both.
  /// firestore.pipeline()
  ///   .collection("books")
  ///   .where(
  ///     Field("genre").equal("Dystopian") ^ Field("rating").equal(5.0)
  ///   )
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The left-hand boolean expression.
  ///   - rhs: The right-hand boolean expression.
  /// - Returns: A new `BooleanExpression` representing the logical XOR.
  public static func ^ (lhs: BooleanExpression,
                        rhs: @autoclosure () throws -> BooleanExpression) rethrows
    -> BooleanExpression {
    try BooleanExpression("xor", [lhs, rhs()])
  }

  /// Negates a boolean expression with a logical NOT (`!`).
  ///
  /// The resulting expression is `true` if the original expression is `false`, and vice versa.
  ///
  /// ```swift
  /// // Find books that are NOT in the "Science Fiction" genre
  /// firestore.pipeline()
  ///   .collection("books")
  ///   .where(!Field("genre").equal("Science Fiction"))
  /// ```
  ///
  /// - Parameter lhs: The boolean expression to negate.
  /// - Returns: A new `BooleanExpression` representing the logical NOT.
  public static prefix func ! (lhs: BooleanExpression) -> BooleanExpression {
    return BooleanExpression("not", [lhs])
  }
}
