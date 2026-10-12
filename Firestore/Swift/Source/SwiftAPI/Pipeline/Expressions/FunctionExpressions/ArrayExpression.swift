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

/// An expression that represents an array of values.
///
/// `ArrayExpression` is used to construct an array from a list of `Sendable`
/// values, which can include literals (like numbers and strings) as well as other
/// `Expression` instances. This allows for the creation of dynamic arrays within

/// a pipeline.
///
/// Example:
/// ```swift
/// ArrayExpression([
///   1,
///   2,
///   Field("genre"),
///   Field("rating").multiply(10),
///   ArrayExpression([Field("title")]),
///   MapExpression(["published": Field("published")]),
/// ]).as("metadataArray")
/// ```
public class ArrayExpression: FunctionExpression, @unchecked Sendable {
  var result: [Expression] = []
  public init(_ elements: [Sendable]) {
    for element in elements {
      result.append(Helper.sendableToExpr(element))
    }

    super.init(functionName: "array", args: result)
  }
}
