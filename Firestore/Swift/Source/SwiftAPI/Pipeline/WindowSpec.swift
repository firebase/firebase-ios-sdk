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

/// Represents a boundary in a window frame specification: an integer or floating-point offset,
/// an `Expression`, `.unbounded`, or `.current`.
///
/// Integer and floating-point literals can be used directly wherever a `WindowBound` is expected,
/// e.g. `.documents(preceding: 2, following: .current)` or `.range(preceding: 1.5, following: 1.5)`.
/// To pass a variable, use `WindowBound(_:)`.
public struct WindowBound: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, Sendable {
  /// The underlying value of a window frame boundary.
  public enum Value: Sendable {
    /// An unbounded frame boundary extending to the start or end of the partition.
    case unbounded
    /// The current document boundary. See `WindowBound.current`.
    case current
    /// An integer offset.
    case integer(Int)
    /// A floating-point offset. Only meaningful for `range` frames.
    case double(Double)
    /// An offset computed from an expression.
    case expression(Expression)
  }

  public let rawValue: Value

  /// An unbounded frame boundary extending to the start or end of the partition.
  public static let unbounded = WindowBound(.unbounded)

  /// The current document boundary.
  ///
  /// - In a `documents` frame, `.current` refers to the current document's position only
  ///   (documents that tie on the sort value(s) at other positions are not included).
  /// - In a `range` frame, `.current` is peer-inclusive (like SQL `CURRENT ROW` in `RANGE` mode):
  ///   it includes all documents whose sort value(s) tie with the current document, making it
  ///   equivalent to an offset of `0`.
  public static let current = WindowBound(.current)

  public init(_ value: Value) {
    rawValue = value
  }

  /// Creates a boundary from an expression that evaluates to an offset.
  public init(_ expression: Expression) {
    rawValue = .expression(expression)
  }

  /// Creates an integer offset boundary.
  public init(_ int: Int) {
    rawValue = .integer(int)
  }

  /// Creates a floating-point offset boundary. Only meaningful for `range` frames.
  public init(_ double: Double) {
    rawValue = .double(double)
  }

  public init(integerLiteral value: Int) {
    rawValue = .integer(value)
  }

  public init(floatLiteral value: Double) {
    rawValue = .double(value)
  }

  var bridgeValue: Any {
    switch rawValue {
    case .unbounded:
      return "unbounded"
    case .current:
      return "current"
    case let .integer(int):
      return int
    case let .double(double):
      return double
    case let .expression(expr):
      return expr.toBridge()
    }
  }
}

/// Window specification for window functions.
///
/// Defines how documents are partitioned, sorted, and framed when evaluating window functions in
/// an `addWindowFields` stage.
///
/// - Default frame behavior:
///   - If `sort` is not specified, the default frame is `documents` from `.unbounded` preceding to
///     `.unbounded` following (the entire partition).
///   - If `sort` is specified without an explicit `documents` or `range` frame, the default frame
///     is `range` from `.unbounded` preceding to `.current`.
public struct WindowSpec: Sendable {
  let groups: [Expression]
  let sort: [Ordering]?
  let preceding: WindowBound?
  let following: WindowBound?
  let type: String?
  let unit: Sendable?

  /// Creates an empty window specification representing a single global partition covering the
  /// entire result set, with no sort and no explicit frame.
  public init() {
    self.init(groups: [], sort: nil, preceding: nil, following: nil, type: nil, unit: nil)
  }

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
      groups: groups,
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

  /// Specifies the sort order of documents within each partition.
  ///
  /// - For document-based (`documents`) window frames, `sort` is optional; if no `sort` expressions
  ///   are specified, documents are processed in incoming stream (fetch) order.
  /// - For range-based (`range`) window frames, one or more `sort` expressions are required.
  /// - Setting `sort` without an explicit `documents` or `range` frame changes the default window
  ///   frame to `range(preceding: .unbounded, following: .current)`.
  ///
  /// Multiple sort orderings and string or boolean sort fields are supported for `documents` frames
  /// and for `range` frames whose bounds are only `.current` or `.unbounded` (without a `unit`).
  /// `range` frames with numeric or time offsets require exactly one sort ordering on a numeric or
  /// timestamp field.
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

  /// Specifies the sort order of documents within each partition.
  ///
  /// - For document-based (`documents`) window frames, `sort` is optional; if no `sort` expressions
  ///   are specified, documents are processed in incoming stream (fetch) order.
  /// - For range-based (`range`) window frames, one or more `sort` expressions are required.
  /// - Setting `sort` without an explicit `documents` or `range` frame changes the default window
  ///   frame to `range(preceding: .unbounded, following: .current)`.
  ///
  /// Multiple sort orderings and string or boolean sort fields are supported for `documents` frames
  /// and for `range` frames whose bounds are only `.current` or `.unbounded` (without a `unit`).
  /// `range` frames with numeric or time offsets require exactly one sort ordering on a numeric or
  /// timestamp field.
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
  /// Defines frame boundaries relative to the current document's position within the partition using
  /// document counts. In a `documents` frame, `.current` refers strictly to the current document's
  /// position (documents that tie on the sort value(s) at other positions are not included).
  ///
  /// - Note: `sort` is optional for document-count frames; if no `sort` is specified on the window,
  ///   documents are processed in incoming stream (fetch) order.
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
  /// Defines frame boundaries relative to the sort key value(s) of the current document within the
  /// partition.
  ///
  /// In a `range` frame, `.current` is peer-inclusive (like SQL `CURRENT ROW` in `RANGE` mode): it
  /// includes all documents whose sort value(s) tie with the current document, making `.current`
  /// equivalent to an offset of `0`. For example, given sort values `[10, 10, 20]` and
  /// `.range(preceding: .unbounded, following: .current)`, the frame for each `10` document includes
  /// both `10`s, and the frame for `20` includes all three documents.
  ///
  /// - When both bounds are `.current` or `.unbounded` (and `unit` is `nil`), the window may specify
  ///   multiple sort orderings and may sort on string or boolean fields.
  /// - When numeric or time offsets are used, `range` requires exactly one sort ordering on a numeric
  ///   or timestamp field. Specifying a `unit` on a string or boolean sort field is an error.
  ///
  /// - Note: One or more `sort` expressions are required when using a range-value based window frame.
  ///   For time-based range frames, the backend only accepts duration units: `.microsecond`,
  ///   `.millisecond`, `.second`, `.minute`, `.hour`, `.day`, `.week`, `.month`, `.quarter`, `.year`
  ///   (or matching strings). Day-of-week week variants (such as `.weekMonday` through `.weekSunday`)
  ///   and `.isoweek`/`.isoyear` are only for timestamp truncation, not window range duration frames,
  ///   and will be rejected by the backend.
  ///
  /// - Parameters:
  ///   - preceding: The starting boundary of the window frame. Can be `.unbounded`, `.current`, an integer or floating-point offset,
  ///     or an `Expression`. A positive offset subtracts from the current document's sort value (looking into the past).
  ///     A negative offset adds to the current document's sort value (shifting the lower boundary past the current document).
  ///   - following: The ending boundary of the window frame. Can be `.unbounded`, `.current`, an integer or floating-point offset,
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
      unit: unit
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

  func toBridge() -> __WindowSpecBridge {
    let bridgePreceding: Any? = preceding?.bridgeValue
    let bridgeFollowing: Any? = following?.bridgeValue
    let bridgeUnit: Any? =
      (unit as? TimeGranularity)?.rawValue ?? (unit as? TimeUnit)?.rawValue
        ?? (unit as? Expression)?.toBridge() ?? unit
    return __WindowSpecBridge(
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

  /// Creates a window specification with the given sort order for documents within each partition.
  ///
  /// - For document-based (`documents`) window frames, `sort` is optional; if no `sort` expressions
  ///   are specified, documents are processed in incoming stream (fetch) order.
  /// - For range-based (`range`) window frames, one or more `sort` expressions are required.
  /// - Setting `sort` without an explicit `documents` or `range` frame changes the default window
  ///   frame to `range(preceding: .unbounded, following: .current)`.
  ///
  /// Multiple sort orderings and string or boolean sort fields are supported for `documents` frames
  /// and for `range` frames whose bounds are only `.current` or `.unbounded` (without a `unit`).
  /// `range` frames with numeric or time offsets require exactly one sort ordering on a numeric or
  /// timestamp field.
  public static func sort(_ sort: Ordering) -> WindowSpec {
    return WindowSpec(sort: [sort])
  }

  /// Creates a window specification with the given sort order for documents within each partition.
  ///
  /// - For document-based (`documents`) window frames, `sort` is optional; if no `sort` expressions
  ///   are specified, documents are processed in incoming stream (fetch) order.
  /// - For range-based (`range`) window frames, one or more `sort` expressions are required.
  /// - Setting `sort` without an explicit `documents` or `range` frame changes the default window
  ///   frame to `range(preceding: .unbounded, following: .current)`.
  ///
  /// Multiple sort orderings and string or boolean sort fields are supported for `documents` frames
  /// and for `range` frames whose bounds are only `.current` or `.unbounded` (without a `unit`).
  /// `range` frames with numeric or time offsets require exactly one sort ordering on a numeric or
  /// timestamp field.
  public static func sort(_ sort: [Ordering]) -> WindowSpec {
    return WindowSpec(sort: sort)
  }

  /// Creates a document-count based window specification (row-based frame).
  ///
  /// Defines frame boundaries relative to the current document's position within the partition using
  /// document counts. In a `documents` frame, `.current` refers strictly to the current document's
  /// position (documents that tie on the sort value(s) at other positions are not included).
  ///
  /// - Note: `sort` is optional for document-count frames; if no `sort` is specified on the window,
  ///   documents are processed in incoming stream (fetch) order.
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
  /// Defines frame boundaries relative to the sort key value(s) of the current document within the
  /// partition.
  ///
  /// In a `range` frame, `.current` is peer-inclusive (like SQL `CURRENT ROW` in `RANGE` mode): it
  /// includes all documents whose sort value(s) tie with the current document, making `.current`
  /// equivalent to an offset of `0`. For example, given sort values `[10, 10, 20]` and
  /// `.range(preceding: .unbounded, following: .current)`, the frame for each `10` document includes
  /// both `10`s, and the frame for `20` includes all three documents.
  ///
  /// - When both bounds are `.current` or `.unbounded` (and `unit` is `nil`), the window may specify
  ///   multiple sort orderings and may sort on string or boolean fields.
  /// - When numeric or time offsets are used, `range` requires exactly one sort ordering on a numeric
  ///   or timestamp field. Specifying a `unit` on a string or boolean sort field is an error.
  ///
  /// - Note: One or more `sort` expressions are required when using a range-value based window frame.
  ///   For time-based range frames, the backend only accepts duration units: `.microsecond`,
  ///   `.millisecond`, `.second`, `.minute`, `.hour`, `.day`, `.week`, `.month`, `.quarter`, `.year`
  ///   (or matching strings). Day-of-week week variants (such as `.weekMonday` through `.weekSunday`)
  ///   and `.isoweek`/`.isoyear` are only for timestamp truncation, not window range duration frames,
  ///   and will be rejected by the backend.
  ///
  /// - Parameters:
  ///   - preceding: The starting boundary of the window frame. Can be `.unbounded`, `.current`, an integer or floating-point offset,
  ///     or an `Expression`. A positive offset subtracts from the current document's sort value (looking into the past).
  ///     A negative offset adds to the current document's sort value (shifting the lower boundary past the current document).
  ///   - following: The ending boundary of the window frame. Can be `.unbounded`, `.current`, an integer or floating-point offset,
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
