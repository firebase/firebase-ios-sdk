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

import Foundation

public struct FindNearestOptions {
  let field: Field
  let vectorValue: [VectorValue]
  let distanceMeasure: DistanceMeasure
  let limit: Int?
  let distanceField: String?
}

public struct DistanceMeasure: Sendable, Equatable, Hashable {
  enum Kind: String {
    case euclidean
    case cosine
    case dotProduct = "dot_product"
  }

  public static var euclidean: DistanceMeasure {
    return self.init(kind: .euclidean)
  }

  public static var cosine: DistanceMeasure {
    return self.init(kind: .cosine)
  }

  public static var dotProduct: DistanceMeasure {
    return self.init(kind: .dotProduct)
  }

  /// Returns the raw string representation of the `DistanceMeasure` value.
  public let rawValue: String

  init(kind: Kind) {
    rawValue = kind.rawValue
  }

  public init(rawValue: String) {
    if Kind(rawValue: rawValue) == nil {
      // impl
    }
    self.rawValue = rawValue
  }
}
