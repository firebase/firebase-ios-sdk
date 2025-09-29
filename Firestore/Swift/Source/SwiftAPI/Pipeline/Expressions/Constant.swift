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

  // Initializer for integer
  public init(_ value: Int) {
    self.init(value as Any)
  }

  // Initializer for double
  public init(_ value: Double) {
    self.init(value as Any)
  }

  // Initializer for strings
  public init(_ value: String) {
    self.init(value as Any)
  }

  // Initializer for boolean values
  public init(_ value: Bool) {
    self.init(value as Any)
  }

  // Initializer for Bytes
  public init(_ value: Data) {
    self.init(value as Any)
  }

  // Initializer for GeoPoint values
  public init(_ value: GeoPoint) {
    self.init(value as Any)
  }

  // Initializer for Timestamp values
  public init(_ value: Timestamp) {
    self.init(value as Any)
  }

  // Initializer for Date values
  public init(_ value: Date) {
    self.init(value as Any)
  }

  // Initializer for DocumentReference
  public init(_ value: DocumentReference) {
    self.init(value as Any)
  }

  // Initializer for vector values
  public init(_ value: VectorValue) {
    self.init(value as Any)
  }

  public static let `nil` = Constant(nil)
}
