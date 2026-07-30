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

/// Represents a boundary in a window frame specification (e.g. integer offset, expression, `.unbounded`, or `.current`).
public struct WindowBound: ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, Sendable {
  public let rawValue: Sendable

  public static let unbounded = WindowBound("unbounded")
  public static let current = WindowBound("current")

  public init(_ value: Sendable) {
    self.rawValue = value
  }

  public init(_ expression: Expression) {
    self.rawValue = expression
  }

  public init(integerLiteral value: Int) {
    self.rawValue = value
  }

  public init(stringLiteral value: String) {
    self.rawValue = value
  }
}

/// Window specification for window functions.
public class WindowSpec: @unchecked Sendable {
  let groups: [Expression]
  let sort: [Ordering]?
  let preceding: WindowBound?
  let following: WindowBound?
  let type: String?
  let unit: Sendable?

  init(
    groups: [Expression] = [],
    sort: [Ordering]? = nil,
    preceding: WindowBound? = nil,
    following: WindowBound? = nil,
    type: String? = nil,
    unit: Sendable? = nil
  ) {
    self.groups = groups
    self.sort = sort
    self.preceding = preceding
    self.following = following
    self.type = type
    self.unit = unit
  }

  /** Specify group/partition configuration on top of this spec. */
  public func partition(_ groups: [Expression]) -> WindowSpec {
    return WindowSpec(
      groups: self.groups + groups,
      sort: sort,
      preceding: preceding,
      following: following,
      type: type,
      unit: unit
    )
  }

  /** Specify group/partition configuration using field names. */
  public func partition(_ groups: [String]) -> WindowSpec {
    return partition(groups.map { Field($0) })
  }

  /** Specify sort order for this window spec. */
  public func sort(_ sort: Ordering) -> WindowSpec {
    return WindowSpec(
      groups: groups,
      sort: [sort],
      preceding: preceding,
      following: following,
      type: type,
      unit: unit
    )
  }

  public func sort(_ sort: [Ordering]) -> WindowSpec {
    return WindowSpec(
      groups: groups,
      sort: sort,
      preceding: preceding,
      following: following,
      type: type,
      unit: unit
    )
  }

  /** Specify document-count based window frame. */
  public func documents(preceding: WindowBound, following: WindowBound) -> WindowSpec {
    return WindowSpec(
      groups: groups,
      sort: sort,
      preceding: preceding,
      following: following,
      type: "documents",
      unit: nil
    )
  }

  public func documents(preceding: Expression, following: Expression) -> WindowSpec {
    return documents(preceding: WindowBound(preceding), following: WindowBound(following))
  }

  /** Specify range-value based window frame. */
  public func range(
    preceding: WindowBound,
    following: WindowBound,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return WindowSpec(
      groups: groups,
      sort: sort,
      preceding: preceding,
      following: following,
      type: "range",
      unit: unit ?? self.unit
    )
  }

  public func range(
    preceding: Expression,
    following: Expression,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return range(
      preceding: WindowBound(preceding),
      following: WindowBound(following),
      unit: unit
    )
  }

  public func toBridge() -> WindowSpecBridge {
    let bridgePreceding: Any? = (preceding?.rawValue as? Expression)?.toBridge() ?? preceding?.rawValue
    let bridgeFollowing: Any? = (following?.rawValue as? Expression)?.toBridge() ?? following?.rawValue
    let bridgeUnit: Any? = (unit as? TimeGranularity)?.rawValue ?? (unit as? Expression)?.toBridge() ?? unit
    return WindowSpecBridge(
      groups: groups.map { $0.toBridge() },
      sort: sort?.map { $0.bridge },
      preceding: bridgePreceding,
      following: bridgeFollowing,
      type: type,
      unit: bridgeUnit
    )
  }

  // MARK: - Factory Methods

  /** Creates a partition/group spec. */
  public static func partition(_ groups: [Expression]) -> WindowSpec {
    return WindowSpec(groups: groups)
  }

  public static func partition(_ groups: [String]) -> WindowSpec {
    return WindowSpec(groups: groups.map { Field($0) })
  }

  /** Creates a sort spec. */
  public static func sort(_ sort: Ordering) -> WindowSpec {
    return WindowSpec(sort: [sort])
  }

  public static func sort(_ sort: [Ordering]) -> WindowSpec {
    return WindowSpec(sort: sort)
  }

  /** Creates a document-count based window spec. */
  public static func documents(preceding: WindowBound, following: WindowBound) -> WindowSpec {
    return WindowSpec(preceding: preceding, following: following, type: "documents")
  }

  public static func documents(preceding: Expression, following: Expression) -> WindowSpec {
    return documents(preceding: WindowBound(preceding), following: WindowBound(following))
  }

  /** Creates a range-value based window spec. */
  public static func range(
    preceding: WindowBound,
    following: WindowBound,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return WindowSpec(preceding: preceding, following: following, type: "range", unit: unit)
  }

  public static func range(
    preceding: Expression,
    following: Expression,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return range(preceding: WindowBound(preceding), following: WindowBound(following), unit: unit)
  }
}
