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
  /// Creates a new `PipelineSource` to build and execute a data pipeline.
  ///
  /// A pipeline is composed of a sequence of stages. Each stage processes the
  /// output from the previous one, and the final stage's output is the result of the
  /// pipeline's execution.
  ///
  /// Example usage:
  /// ```swift
  /// let pipeline = firestore.pipeline()
  ///   .collection("books")
  ///   .where(Field("rating").isGreaterThan(4.5))
  ///   .sort(Field("rating").descending())
  ///   .limit(2)
  /// ```
  ///
  /// Note on Execution: The stages are conceptual. The Firestore backend may
  /// optimize execution (e.g., reordering or merging stages) as long as the
  /// final result remains the same.
  ///
  /// Important Limitations:
  /// - Pipelines operate on a request/response basis only.
  /// - They do not utilize or update the local SDK cache.
  /// - They do not support realtime snapshot listeners.
  ///
  /// - Returns: A `PipelineSource` to begin defining the pipeline's stages.
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
