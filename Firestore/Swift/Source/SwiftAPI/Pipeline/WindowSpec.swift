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

/// Protocol representing a finalized window specification that can be serialized.
public protocol FinalWindowSpec: Sendable {
  func toBridge() -> WindowSpecBridge
}

/// Factory class for constructing window specifications.
public class WindowSpec: @unchecked Sendable {
  public static let CURRENT = "current"
  public static let UNBOUNDED = "unbounded"

  /** Creates a partition/group spec (no sorting or frames supported). */
  public static func overPartition(_ groups: [Expression]) -> GroupWindowSpec {
    return GroupWindowSpec(groups: groups)
  }

  /** Creates a partition/group spec using field names. */
  public static func overPartition(_ groups: [String]) -> GroupWindowSpec {
    return GroupWindowSpec(groups: groups.map { Field($0) })
  }

  /** Creates a partition/group spec using a single field name. */
  public static func overPartition(_ group: String) -> GroupWindowSpec {
    return overPartition([group])
  }


  /** Creates a document-count based window spec (sort and boundaries are required). */
  public static func overDocuments(sort: Ordering, preceding: Any, following: Any) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: [sort], preceding: preceding, following: following)
  }

  /** Creates a document-count based window spec with multiple sorts. */
  public static func overDocuments(sort: [Ordering], preceding: Any, following: Any) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: sort, preceding: preceding, following: following)
  }

  /** Convenience factory for default documents spec (unbounded preceding to current). */
  public static func overDocuments(sort: Ordering) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: [sort], preceding: UNBOUNDED, following: CURRENT)
  }

  public static func overDocuments(sort: [Ordering]) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: sort, preceding: UNBOUNDED, following: CURRENT)
  }

  /** Creates a range-value based window spec (sort and boundaries are required). */
  public static func overRange(sort: Ordering, preceding: Any, following: Any) -> RangeWindowSpec {
    return RangeWindowSpec(sort: sort, preceding: preceding, following: following)
  }

  /** Convenience factory for default range spec (unbounded preceding to current). */
  public static func overRange(sort: Ordering) -> RangeWindowSpec {
    return RangeWindowSpec(sort: sort, preceding: UNBOUNDED, following: CURRENT)
  }
}

/// Window specification for group/partition aggregations without sorting or frames.
public class GroupWindowSpec: WindowSpec, FinalWindowSpec, @unchecked Sendable {
  let groups: [Expression]

  init(groups: [Expression]) {
    self.groups = groups
  }

  /** Specify range-value based window frame on top of this partition. */
  public func overRange(sort: Ordering, preceding: Any, following: Any) -> RangeWindowSpec {
    return RangeWindowSpec(sort: sort, preceding: preceding, following: following, groups: groups)
  }

  /** Specify range-value based default window frame on top of this partition. */
  public func overRange(sort: Ordering) -> RangeWindowSpec {
    return RangeWindowSpec(sort: sort, preceding: WindowSpec.UNBOUNDED, following: WindowSpec.CURRENT, groups: groups)
  }

  /** Specify document-count based window frame on top of this partition. */
  public func overDocuments(sort: Ordering, preceding: Any, following: Any) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: [sort], preceding: preceding, following: following, groups: groups)
  }

  /** Specify document-count based window frame with multiple sorts on top of this partition. */
  public func overDocuments(sort: [Ordering], preceding: Any, following: Any) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: sort, preceding: preceding, following: following, groups: groups)
  }

  /** Specify document-count based default window frame on top of this partition. */
  public func overDocuments(sort: Ordering) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: [sort], preceding: WindowSpec.UNBOUNDED, following: WindowSpec.CURRENT, groups: groups)
  }

  /** Specify document-count based default window frame with multiple sorts on top of this partition. */
  public func overDocuments(sort: [Ordering]) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: sort, preceding: WindowSpec.UNBOUNDED, following: WindowSpec.CURRENT, groups: groups)
  }

  public func toBridge() -> WindowSpecBridge {
    return WindowSpecBridge(
      groups: groups.map { $0.toBridge() },
      sort: nil,
      preceding: nil,
      following: nil,
      type: nil,
      unit: nil
    )
  }
}

/// Window specification for document-count based window frames.
public class DocumentWindowSpec: WindowSpec, FinalWindowSpec, @unchecked Sendable {
  let sort: [Ordering]
  let preceding: Any
  let following: Any
  let groups: [Expression]

  init(sort: [Ordering], preceding: Any, following: Any, groups: [Expression] = []) {
    self.sort = sort
    self.preceding = preceding
    self.following = following
    self.groups = groups
  }

  /** Specify group/partition configuration on top of this spec. */
  public func overPartition(_ groups: [Expression]) -> DocumentWindowSpec {
    return DocumentWindowSpec(sort: sort, preceding: preceding, following: following, groups: self.groups + groups)
  }

  /** Specify group/partition configuration using field names. */
  public func overPartition(_ groups: [String]) -> DocumentWindowSpec {
    return overPartition(groups.map { Field($0) })
  }

  /** Specify group/partition configuration using a single field name. */
  public func overPartition(_ group: String) -> DocumentWindowSpec {
    return overPartition([group])
  }


  public func toBridge() -> WindowSpecBridge {
    return WindowSpecBridge(
      groups: groups.map { $0.toBridge() },
      sort: sort.map { $0.bridge },
      preceding: preceding,
      following: following,
      type: "documents",
      unit: nil
    )
  }
}

/// Window specification for range-value based window frames.
public class RangeWindowSpec: WindowSpec, FinalWindowSpec, @unchecked Sendable {
  let sort: Ordering
  let preceding: Any
  let following: Any
  let groups: [Expression]
  var unit: TimeGranularity?

  init(sort: Ordering, preceding: Any, following: Any, groups: [Expression] = [], unit: TimeGranularity? = nil) {
    self.sort = sort
    self.preceding = preceding
    self.following = following
    self.groups = groups
    self.unit = unit
  }

  /** Specify group/partition configuration on top of this spec. */
  public func overPartition(_ groups: [Expression]) -> RangeWindowSpec {
    return RangeWindowSpec(sort: sort, preceding: preceding, following: following, groups: self.groups + groups, unit: unit)
  }

  /** Specify group/partition configuration using field names. */
  public func overPartition(_ groups: [String]) -> RangeWindowSpec {
    return overPartition(groups.map { Field($0) })
  }

  /** Specify group/partition configuration using a single field name. */
  public func overPartition(_ group: String) -> RangeWindowSpec {
    return overPartition([group])
  }


  /** Specify date/time granularity unit for this range spec. */
  public func withUnits(_ unit: TimeGranularity) -> RangeWindowSpec {
    self.unit = unit
    return self
  }

  public func toBridge() -> WindowSpecBridge {
    return WindowSpecBridge(
      groups: groups.map { $0.toBridge() },
      sort: [sort.bridge],
      preceding: preceding,
      following: following,
      type: "range",
      unit: unit?.rawValue
    )
  }
}

// Enable dot-shorthand notation for FinalWindowSpec arguments
extension FinalWindowSpec {
  public static func overPartition(_ groups: [Expression]) -> GroupWindowSpec {
    return WindowSpec.overPartition(groups)
  }
  public static func overPartition(_ groups: [String]) -> GroupWindowSpec {
    return WindowSpec.overPartition(groups)
  }
  public static func overPartition(_ group: String) -> GroupWindowSpec {
    return WindowSpec.overPartition(group)
  }
  public static func overDocuments(sort: Ordering, preceding: Any, following: Any) -> DocumentWindowSpec {
    return WindowSpec.overDocuments(sort: sort, preceding: preceding, following: following)
  }
  public static func overDocuments(sort: [Ordering], preceding: Any, following: Any) -> DocumentWindowSpec {
    return WindowSpec.overDocuments(sort: sort, preceding: preceding, following: following)
  }
  public static func overDocuments(sort: Ordering) -> DocumentWindowSpec {
    return WindowSpec.overDocuments(sort: sort)
  }
  public static func overDocuments(sort: [Ordering]) -> DocumentWindowSpec {
    return WindowSpec.overDocuments(sort: sort)
  }
  public static func overRange(sort: Ordering, preceding: Any, following: Any) -> RangeWindowSpec {
    return WindowSpec.overRange(sort: sort, preceding: preceding, following: following)
  }
  public static func overRange(sort: Ordering) -> RangeWindowSpec {
    return WindowSpec.overRange(sort: sort)
  }
}

