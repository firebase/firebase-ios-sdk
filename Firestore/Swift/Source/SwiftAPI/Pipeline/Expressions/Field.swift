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

/// A `Field` is an `Expression` that represents a field in a Firestore document.
///
/// It is a central component for building queries and transformations in Firestore pipelines.
/// A `Field` can be used to:
/// - Reference a document field by its name or `FieldPath`.
/// - Create complex `BooleanExpression`s for filtering in a `where` clause.
/// - Perform mathematical operations on numeric fields.
/// - Manipulate string and array fields.
///
/// Example of creating a `Field` and using it in a `where` clause:
/// ```swift
/// // Reference the "price" field in a document
/// let priceField = Field("price")
///
/// // Create a query to find products where the price is greater than 100
/// firestore.pipeline()
///   .collection("products")
///   .where(priceField.greaterThan(100))
/// ```
public struct Field: Expression, Selectable, BridgeWrapper, SelectableWrapper,
  @unchecked Sendable {
  let bridge: ExprBridge

  var alias: String

  var expr: Expression {
    return self
  }

  /// The name of the field.
  public let fieldName: String

  /// Creates a new `Field` expression from a field name.
  ///
  /// - Parameter name: The name of the field.
  public init(_ name: String) {
    let fieldBridge = FieldBridge(name: name)
    bridge = fieldBridge
    fieldName = fieldBridge.field_name()
    alias = fieldName
  }

  /// Creates a new `Field` expression from a `FieldPath`.
  ///
  /// - Parameter path: The `FieldPath` of the field.
  public init(_ path: FieldPath) {
    let fieldBridge = FieldBridge(path: path)
    bridge = fieldBridge
    fieldName = fieldBridge.field_name()
    alias = fieldName
  }
}
