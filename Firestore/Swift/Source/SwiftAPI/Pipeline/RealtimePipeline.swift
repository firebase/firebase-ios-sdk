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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct PipelineListenOptions: Sendable, Equatable, Hashable {
  /// Defines how to handle server-generated timestamps that are not yet known locally
  /// during latency compensation.
  struct ServerTimestampBehavior: Sendable, Equatable, Hashable {
    /// The raw string value for the behavior, used for implementation and hashability.
    let rawValue: String
    /// Creates a new behavior with a private raw value.
    private init(rawValue: String) {
      self.rawValue = rawValue
    }

    /// Fields dependent on server timestamps will be `nil` until the value is
    /// confirmed by the server.
    public static let none = ServerTimestampBehavior(rawValue: "none")

    /// Fields dependent on server timestamps will receive a local, client-generated
    /// time estimate until the value is confirmed by the server.
    public static let estimate = ServerTimestampBehavior(rawValue: "estimate")

    /// Fields dependent on server timestamps will hold the value from the last
    /// server-confirmed write until the new value is confirmed.
    public static let previous = ServerTimestampBehavior(rawValue: "previous")
  }

  // MARK: - Stored Properties

  /// The desired behavior for handling pending server timestamps.
  public let serverTimestamps: ServerTimestampBehavior?

  /// Whether to include snapshots that only contain metadata changes.
  public let includeMetadataChanges: Bool?

  /// What source of changes to listen to.
  public let source: ListenSource?

  let bridge: __PipelineListenOptionsBridge

  /// Creates a new set of listen options to customize snapshot behavior.
  /// - Parameters:
  ///   - serverTimestamps: The desired behavior for handling pending server timestamps.
  ///   - includeMetadataChanges: Whether to include snapshots that only contain
  ///     metadata changes. Set to `true` to observe the `hasPendingWrites` state.
  public init(serverTimestamps: ServerTimestampBehavior? = nil,
              includeMetadataChanges: Bool? = nil,
              source: ListenSource? = nil) {
    self.serverTimestamps = serverTimestamps
    self.includeMetadataChanges = includeMetadataChanges
    self.source = source
    bridge = __PipelineListenOptionsBridge(
      serverTimestampBehavior: PipelineListenOptions
        .toRawValue(servertimestamp: self.serverTimestamps ?? .none),
      includeMetadata: self.includeMetadataChanges ?? false,
      source: self.source ?? ListenSource.default
    )
  }

  private static func toRawValue(servertimestamp: ServerTimestampBehavior) -> String {
    switch servertimestamp {
    case .none:
      return "none"
    case .estimate:
      return "estimate"
    case .previous:
      return "previous"
    default:
      fatalError("Unknown server timestamp behavior")
    }
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct RealtimePipeline: @unchecked Sendable {
  private var stages: [Stage]

  let bridge: RealtimePipelineBridge
  let db: Firestore

  init(stages: [Stage], db: Firestore) {
    self.stages = stages
    self.db = db
    bridge = RealtimePipelineBridge(stages: stages.map { $0.bridge }, db: db)
  }

  struct Snapshot: Sendable {
    /// An array of all the results in the `PipelineSnapshot`.
    let results_cache: [PipelineResult]

    public let changes: [PipelineResultChange]
    public let metadata: SnapshotMetadata

    let bridge: __RealtimePipelineSnapshotBridge

    init(_ bridge: __RealtimePipelineSnapshotBridge) {
      self.bridge = bridge
      metadata = bridge.metadata
      results_cache = self.bridge.results.map { PipelineResult($0) }
      changes = self.bridge.changes.map { PipelineResultChange($0) }
    }

    public func results() -> [PipelineResult] {
      return results_cache
    }
  }

  private func addSnapshotListener(options: PipelineListenOptions,
                                   listener: @escaping (RealtimePipeline.Snapshot?, Error?) -> Void)
    -> ListenerRegistration {
    return bridge.addSnapshotListener(options: options.bridge) { snapshotBridge, error in
      listener(
        RealtimePipeline.Snapshot(
          // TODO(pipeline): this needs to be fixed
          snapshotBridge!
        ),
        error
      )
    }
  }

  public func snapshotStream(options: PipelineListenOptions? = nil)
    -> AsyncThrowingStream<RealtimePipeline.Snapshot, Error> {
    AsyncThrowingStream { continuation in
      let listener = self.addSnapshotListener(
        options: options ?? PipelineListenOptions()
      ) { snapshot, error in
        if let snapshot = snapshot {
          continuation.yield(snapshot)
        } else if let error = error {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }

  /// Filters documents from previous stages, including only those matching the specified
  /// `BooleanExpr`.
  ///
  /// This stage applies conditions similar to a "WHERE" clause in SQL.
  /// Filter documents based on field values using `BooleanExpr` implementations, such as:
  /// - Field comparators: `Function.eq`, `Function.lt` (less than), `Function.gt` (greater than).
  /// - Logical operators: `Function.and`, `Function.or`, `Function.not`.
  /// - Advanced functions: `Function.regexMatch`, `Function.arrayContains`.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// let filteredPipeline = pipeline.where(
  ///     Field("rating").gt(4.0)   // Rating greater than 4.0.
  ///     && Field("genre").eq("Science Fiction") // Genre is "Science Fiction".
  /// )
  /// // let results = try await filteredPipeline.execute()
  /// ```
  ///
  /// - Parameter condition: The `BooleanExpr` to apply.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func `where`(_ condition: BooleanExpression) -> RealtimePipeline {
    return RealtimePipeline(stages: stages + [Where(condition: condition)], db: db)
  }

  /// Limits the maximum number of documents returned by previous stages to `limit`.
  ///
  /// A negative input number might count back from the end of the result set,
  /// depending on backend behavior. This stage helps retrieve a controlled subset of data.
  /// It's often used for:
  /// - **Pagination:** With `offset` to retrieve specific pages.
  /// - **Limiting Data Retrieval:** To improve performance with large collections.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Limit results to the top 10 highest-rated books.
  /// let topTenPipeline = pipeline
  ///                      .sort(Descending(Field("rating")))
  ///                      .limit(10)
  /// // let results = try await topTenPipeline.execute()
  /// ```
  ///
  /// - Parameter limit: The maximum number of documents to return (a `Int32` value).
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func limit(_ limit: Int32) -> RealtimePipeline {
    return RealtimePipeline(stages: stages + [Limit(limit)], db: db)
  }

  /// Sorts documents from previous stages based on one or more `Ordering` criteria.
  ///
  /// Specify multiple `Ordering` instances for multi-field sorting (ascending/descending).
  /// If documents are equal by one criterion, the next is used. If all are equal,
  /// relative order is unspecified.
  ///
  /// ```swift
  /// // let pipeline: Pipeline = ... // Assume initial pipeline.
  /// // Sort books by rating (descending), then by title (ascending).
  /// let sortedPipeline = pipeline.sort(
  ///   Ascending("rating"),
  ///   Descending("title")  // or Field("title").ascending() for ascending.
  /// )
  /// // let results = try await sortedPipeline.execute()
  /// ```
  ///
  /// - Parameter ordering: The primary `Ordering` criterion.
  /// - Parameter additionalOrdering: Optional additional `Ordering` criteria for secondary sorting,
  /// etc.
  /// - Returns: A new `Pipeline` object with this stage appended.
  public func sort(_ ordering: Ordering, _ additionalOrdering: Ordering...) -> RealtimePipeline {
    let orderings = [ordering] + additionalOrdering
    return RealtimePipeline(stages: stages + [Sort(orderings: orderings)], db: db)
  }
}
