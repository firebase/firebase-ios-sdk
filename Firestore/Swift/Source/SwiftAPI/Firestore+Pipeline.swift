/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

@objc public extension Firestore {
  /// Creates a `PipelineSource` that can be used to build and execute a pipeline of operations on
  /// the Firestore database.
  ///
  /// A pipeline is a sequence of stages that are executed in order. Each stage can perform an
  /// operation on the data, such as filtering, sorting, or transforming it.
  ///
  /// Example usage:
  /// ```swift
  /// let db = Firestore.firestore()
  /// let pipeline = db.pipeline()
  ///   .collection("books")
  ///   .where(Field("rating").isGreaterThan(4.5))
  ///   .sort([Field("rating").descending()])
  ///   .limit(2)
  ///
  /// do {
  ///   let snapshot = try await pipeline.execute()
  ///   for doc in snapshot.results {
  ///     print(doc.data())
  ///   }
  /// } catch {
  ///   print("Error executing pipeline: \(error)")
  /// }
  /// ```
  ///
  /// - Returns: A `PipelineSource` that can be used to build and execute a pipeline.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @nonobjc func pipeline() -> PipelineSource {
    return PipelineSource(db: self) { stages, db in
      Pipeline(stages: stages, db: db)
    }
  }

  /// Creates a `RealtimePipelineSource` for building and executing a realtime pipeline.
  ///
  /// This is an internal method and should not be used directly.
  ///
  /// - Returns: A `RealtimePipelineSource` for building a realtime pipeline.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @nonobjc internal func realtimePipeline() -> RealtimePipelineSource {
    return RealtimePipelineSource(db: self) { stages, db in
      RealtimePipeline(stages: stages, db: db)
    }
  }
}
