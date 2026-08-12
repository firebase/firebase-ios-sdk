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
  /// The underlying value of a window frame boundary.
  public enum Value: Sendable {
    case unbounded
    case current
    case integer(Int)
    case expression(Expression)
  }

  public let rawValue: Value

  public static let unbounded = WindowBound(.unbounded)
  public static let current = WindowBound(.current)

  public init(_ value: Value) {
    self.rawValue = value
  }

  public init(_ expression: Expression) {
    self.rawValue = .expression(expression)
  }

  public init(_ int: Int) {
    self.rawValue = .integer(int)
  }

  public init(integerLiteral value: Int) {
    self.rawValue = .integer(value)
  }

  public init(stringLiteral value: String) {
    switch value.lowercased() {
    case "unbounded":
      self.rawValue = .unbounded
    case "current":
      self.rawValue = .current
    default:
      fatalError("Invalid WindowBound string literal: \"\(value)\". Expected \"unbounded\" or \"current\".")
    }
  }

  var bridgeValue: Any {
    switch rawValue {
    case .unbounded:
      return "unbounded"
    case .current:
      return "current"
    case let .integer(int):
      return int
    case let .expression(expr):
      return expr.toBridge()
    }
  }
}

/// Window specification for window functions.
public struct WindowSpec: Sendable {
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

  /// Specifies a document-count based window frame (row-based frame).
  ///
  /// Defines frame boundaries relative to the current document within the partition using document counts.
  ///
  /// - Parameters:
  ///   - preceding: The starting boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive integer (e.g. `2`) includes up to that many documents before the current document.
  ///     A negative integer (e.g. `-1`) indicates a boundary following the current document, enabling frames that start
  ///     after the current document.
  ///   - following: The ending boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive integer (e.g. `2`) includes up to that many documents after the current document.
  ///     A negative integer (e.g. `-1`) indicates a boundary preceding the current document, enabling frames that end
  ///     before the current document (e.g. excluding the current document).
  /// - Returns: A new `WindowSpec` with the document-count based window frame configured.
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

  public func documents(preceding: Expression, following: WindowBound) -> WindowSpec {
    return documents(preceding: WindowBound(preceding), following: following)
  }

  public func documents(preceding: WindowBound, following: Expression) -> WindowSpec {
    return documents(preceding: preceding, following: WindowBound(following))
  }

  /// Specifies a range-value based window frame (value-based frame).
  ///
  /// Defines frame boundaries relative to the sort key value of the current document within the partition.
  ///
  /// - Parameters:
  ///   - preceding: The starting boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive offset subtracts from the current document's sort value (looking into the past).
  ///     A negative offset adds to the current document's sort value (shifting the lower boundary past the current document).
  ///   - following: The ending boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive offset adds to the current document's sort value (looking into the future).
  ///     A negative offset subtracts from the current document's sort value (shifting the upper boundary before the current document).
  ///   - unit: An optional date/time granularity unit (such as `TimeGranularity.day`) when computing range offsets over timestamp fields.
  /// - Returns: A new `WindowSpec` with the range-value based window frame configured.
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

  public func range(
    preceding: Expression,
    following: WindowBound,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return range(
      preceding: WindowBound(preceding),
      following: following,
      unit: unit
    )
  }

  public func range(
    preceding: WindowBound,
    following: Expression,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return range(
      preceding: preceding,
      following: WindowBound(following),
      unit: unit
    )
  }

  public func toBridge() -> WindowSpecBridge {
    let bridgePreceding: Any? = preceding?.bridgeValue
    let bridgeFollowing: Any? = following?.bridgeValue
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

  /// Creates a partition/group specification.
  public static func partition(_ groups: [Expression]) -> WindowSpec {
    return WindowSpec(groups: groups)
  }

  public static func partition(_ groups: [String]) -> WindowSpec {
    return WindowSpec(groups: groups.map { Field($0) })
  }

  /// Creates a sort specification.
  public static func sort(_ sort: Ordering) -> WindowSpec {
    return WindowSpec(sort: [sort])
  }

  public static func sort(_ sort: [Ordering]) -> WindowSpec {
    return WindowSpec(sort: sort)
  }

  /// Creates a document-count based window specification (row-based frame).
  ///
  /// Defines frame boundaries relative to the current document within the partition using document counts.
  ///
  /// - Parameters:
  ///   - preceding: The starting boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive integer (e.g. `2`) includes up to that many documents before the current document.
  ///     A negative integer (e.g. `-1`) indicates a boundary following the current document, enabling frames that start
  ///     after the current document.
  ///   - following: The ending boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive integer (e.g. `2`) includes up to that many documents after the current document.
  ///     A negative integer (e.g. `-1`) indicates a boundary preceding the current document, enabling frames that end
  ///     before the current document (e.g. excluding the current document).
  /// - Returns: A new `WindowSpec` with the document-count based window frame.
  public static func documents(preceding: WindowBound, following: WindowBound) -> WindowSpec {
    return WindowSpec(preceding: preceding, following: following, type: "documents")
  }

  public static func documents(preceding: Expression, following: Expression) -> WindowSpec {
    return documents(preceding: WindowBound(preceding), following: WindowBound(following))
  }

  public static func documents(preceding: Expression, following: WindowBound) -> WindowSpec {
    return documents(preceding: WindowBound(preceding), following: following)
  }

  public static func documents(preceding: WindowBound, following: Expression) -> WindowSpec {
    return documents(preceding: preceding, following: WindowBound(following))
  }

  /// Creates a range-value based window specification (value-based frame).
  ///
  /// Defines frame boundaries relative to the sort key value of the current document within the partition.
  ///
  /// - Parameters:
  ///   - preceding: The starting boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive offset subtracts from the current document's sort value (looking into the past).
  ///     A negative offset adds to the current document's sort value (shifting the lower boundary past the current document).
  ///   - following: The ending boundary of the window frame. Can be `.unbounded`, `.current`, an integer offset,
  ///     or an `Expression`. A positive offset adds to the current document's sort value (looking into the future).
  ///     A negative offset subtracts from the current document's sort value (shifting the upper boundary before the current document).
  ///   - unit: An optional date/time granularity unit (such as `TimeGranularity.day`) when computing range offsets over timestamp fields.
  /// - Returns: A new `WindowSpec` with the range-value based window frame.
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

  public static func range(
    preceding: Expression,
    following: WindowBound,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return range(preceding: WindowBound(preceding), following: following, unit: unit)
  }

  public static func range(
    preceding: WindowBound,
    following: Expression,
    unit: Sendable? = nil
  ) -> WindowSpec {
    return range(preceding: preceding, following: WindowBound(following), unit: unit)
  }
}
