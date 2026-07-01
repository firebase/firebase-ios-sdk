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
public enum FacetBucket: Equatable, Sendable {
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

  public static func == (lhs: FacetBucket, rhs: FacetBucket) -> Bool {
    switch (lhs, rhs) {
    case let (.scalar(lVal), .scalar(rVal)):
      return areSendablesEqual(lVal, rVal)
    case let (.range(lMin, lMinType, lMax, lMaxType), .range(rMin, rMinType, rMax, rMaxType)):
      return lMinType == rMinType && lMaxType == rMaxType &&
        areSendablesEqual(lMin, rMin) && areSendablesEqual(lMax, rMax)
    case (.default, .default):
      return true
    default:
      return false
    }
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

// MARK: - Equatable Helpers for Type-Erased Sendables

private func areSendablesEqual(_ lhs: Sendable, _ rhs: Sendable) -> Bool {
  if let l = lhs as? String, let r = rhs as? String { return l == r }
  if let l = lhs as? Bool, let r = rhs as? Bool { return l == r }
  if let l = lhs as? Date, let r = rhs as? Date { return l == r }
  if let l = lhs as? Timestamp, let r = rhs as? Timestamp { return l == r }
  if let l = lhs as? GeoPoint, let r = rhs as? GeoPoint { return l == r }
  if let l = lhs as? DocumentReference, let r = rhs as? DocumentReference { return l == r }
  if let l = lhs as? Data, let r = rhs as? Data { return l == r }

  // Handle numeric comparison
  if let lNum = asDouble(lhs), let rNum = asDouble(rhs) {
    return lNum == rNum
  }

  return false
}

private func asDouble(_ value: Sendable) -> Double? {
  if let d = value as? Double { return d }
  if let f = value as? Float { return Double(f) }
  if let i = value as? Int { return Double(i) }
  if let i64 = value as? Int64 { return Double(i64) }
  if let i32 = value as? Int32 { return Double(i32) }
  if let u = value as? UInt { return Double(u) }
  return nil
}


