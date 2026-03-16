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

/// Represents the distance measure to be used in a vector similarity search.
public struct DistanceMeasure: Sendable, Equatable, Hashable {
  let kind: Kind

  enum Kind: String {
    case euclidean
    case cosine
    case dotProduct = "dot_product"
  }

  /// The Euclidean distance measure.
  public static let euclidean: DistanceMeasure = .init(kind: .euclidean)

  /// The Cosine distance measure.
  public static let cosine: DistanceMeasure = .init(kind: .cosine)

  /// The Dot Product distance measure.
  public static let dotProduct: DistanceMeasure = .init(kind: .dotProduct)

  init(kind: Kind) {
    self.kind = kind
  }
}
