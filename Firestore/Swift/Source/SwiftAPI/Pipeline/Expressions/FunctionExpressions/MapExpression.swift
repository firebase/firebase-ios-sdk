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

/// An expression that represents a map (or dictionary) of key-value pairs.
///
/// `MapExpression` is used to construct a map from a dictionary of `String` keys
/// and `Sendable` values. The values can be literals (like numbers and strings)
/// or other `Expression` instances, allowing for the creation of dynamic nested
/// objects within a pipeline.
///
/// Example:
/// ```swift
/// MapExpression([
///   "genre": Field("genre"),
///   "rating": Field("rating").multiply(10),
///   "nestedArray": ArrayExpression([Field("title")]),
///   "nestedMap": MapExpression(["published": Field("published")]),
/// ]).as("metadata")
/// ```
public class MapExpression: FunctionExpression, @unchecked Sendable {
  var result: [Expression] = []
  public init(_ elements: [String: Sendable]) {
    for element in elements {
      result.append(Constant(element.key))
      result.append(Helper.sendableToExpr(element.value))
    }

    super.init(functionName: "map", args: result)
  }
}
