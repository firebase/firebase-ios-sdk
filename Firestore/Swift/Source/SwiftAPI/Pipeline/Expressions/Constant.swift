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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

///
/// A `Constant` is an `Expression` that represents a fixed, literal value within a Firestore
/// pipeline.
///
/// `Constant`s are used to introduce literal values into a query, which can be useful for:
/// - Comparing a field to a specific value in a `where` clause.
/// - Adding new fields with fixed values using `addFields`.
/// - Providing literal arguments to functions like `sum` or `average`.
///
/// Example of using a `Constant` to add a new field:
/// ```swift
/// // Add a new field "source" with the value "manual" to each document
/// firestore.pipeline()
///   .collection("entries")
///   .addFields([
///     Constant("manual").as("source")
///   ])
/// ```
public struct Constant: Expression, BridgeWrapper, @unchecked Sendable {
  let bridge: ExprBridge

  let value: Any?

  // Initializer for optional values (including nil)
  init(_ value: Any?) {
    self.value = value
    if value == nil {
      bridge = ConstantBridge(NSNull())
    } else {
      bridge = ConstantBridge(value!)
    }
  }

  /// Creates a new `Constant` expression from an integer literal.
  ///
  /// - Parameter value: The integer value.
  public init(_ value: Int) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a double-precision floating-point literal.
  ///
  /// - Parameter value: The double value.
  public init(_ value: Double) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a string literal.
  ///
  /// - Parameter value: The string value.
  public init(_ value: String) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a boolean literal.
  ///
  /// - Parameter value: The boolean value.
  public init(_ value: Bool) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a `Data` (bytes) literal.
  ///
  /// - Parameter value: The `Data` value.
  public init(_ value: Data) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a `GeoPoint` literal.
  ///
  /// - Parameter value: The `GeoPoint` value.
  public init(_ value: GeoPoint) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a `Timestamp` literal.
  ///
  /// - Parameter value: The `Timestamp` value.
  public init(_ value: Timestamp) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a `Date` literal.
  ///
  /// The `Date` will be converted to a `Timestamp` internally.
  ///
  /// - Parameter value: The `Date` value.
  public init(_ value: Date) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a `DocumentReference` literal.
  ///
  /// - Parameter value: The `DocumentReference` value.
  public init(_ value: DocumentReference) {
    self.init(value as Any)
  }

  /// Creates a new `Constant` expression from a `VectorValue` literal.
  ///
  /// - Parameter value: The `VectorValue` value.
  public init(_ value: VectorValue) {
    self.init(value as Any)
  }

  /// A `Constant` representing a `nil`  value.
  public static let `nil` = Constant(nil)
}
