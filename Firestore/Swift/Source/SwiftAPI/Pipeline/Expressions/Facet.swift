// Copyright 2026 Google LLC
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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

/// Defines the boundary types for a range bucket.
///
/// - Note: This API is in beta.
public enum RangeBoundType: String, Sendable {
  case open
  case closed
}

/// Represents a single bucket within a search facet.
///
/// - Note: This API is in beta.
public enum FacetBucket: Sendable {
  case scalar(Sendable)
  case range(
    lowerBound: Sendable,
    lowerBoundType: RangeBoundType,
    upperBound: Sendable,
    upperBoundType: RangeBoundType
  )
  case `default`

  /// Creates a range facet bucket with a closed lower bound and open upper bound.
  ///
  /// - Parameters:
  ///   - lowerBound: The lower bound value.
  ///   - upperBound: The upper bound value.
  /// - Returns: A `FacetBucket` representing the range.
  public static func range(lowerBound: Sendable, upperBound: Sendable) -> FacetBucket {
    return .range(
      lowerBound: lowerBound,
      lowerBoundType: .closed,
      upperBound: upperBound,
      upperBoundType: .open
    )
  }
}

/// Represents the definition of a search facet.
///
/// - Note: This API is in beta.
public struct FacetDefinition: Sendable {
  public let fieldName: String
  public let buckets: [FacetBucket]

  public init(fieldName: String, buckets: [FacetBucket]) {
    self.fieldName = fieldName
    self.buckets = buckets
  }
}

