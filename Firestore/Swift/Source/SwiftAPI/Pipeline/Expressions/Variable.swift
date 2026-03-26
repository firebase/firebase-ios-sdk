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

/// A `Variable` is an `Expression` that retrieves the value of a variable bound via
/// `Pipeline.define`.
///
/// Variables are typically defined in a `define` stage and can be referenced in subsequent
/// stages.
///
/// Example:
/// ```swift
/// firestore.pipeline().collection("products")
///     .define([Field("price").multiply(0.9).as("discountedPrice")])
///     .where(Variable("discountedPrice") < 100)
///     .select([Field("name"), Variable("discountedPrice")])
/// ```
public struct Variable: Expression, BridgeWrapper {
  let bridge: ExprBridge

  let name: String

  /// Creates a new `Variable` expression from a variable name.
  ///
  /// - Parameter name: The name of the variable.
  public init(_ name: String) {
    self.name = name
    bridge = VariableBridge(name: name)
  }
}
