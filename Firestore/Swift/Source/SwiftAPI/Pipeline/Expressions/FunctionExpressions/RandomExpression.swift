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

/// A `RandomExpression` is a `FunctionExpression` that generates a random floating-point
/// number between 0.0 (inclusive) and 1.0 (exclusive).
///
/// This expression is useful when you need to introduce a random value into a pipeline,
/// for example, to randomly sample a subset of documents.
///
/// Example of using `RandomExpression` to sample documents:
/// ```swift
/// // Create a query to sample approximately 10% of the documents in a collection
/// firestore.pipeline()
///   .collection("users")
///   .where(rand().lessThan(0.1))
/// ```
public class RandomExpression: FunctionExpression, @unchecked Sendable {
  /// Creates a new `RandomExpression` that generates a random number.
  public init() {
    super.init(functionName: "rand", args: [])
  }
}

/// Creates an expression that generates a random number between 0.0 and 1.0 but not including 1.0.
///
/// ```swift
/// // Generate a random number between 0.0 and 1.0.
/// rand()
/// ```
///
/// - Returns: A new `RandomExpression` representing the random number generator.
public func rand() -> RandomExpression {
  return RandomExpression()
}
