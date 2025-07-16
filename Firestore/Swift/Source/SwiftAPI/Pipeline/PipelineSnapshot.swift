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
public struct PipelineSnapshot: Sendable {
  /// The Pipeline on which `execute()` was called to obtain this `PipelineSnapshot`.
  public let pipeline: Pipeline

  /// An array of all the results in the `PipelineSnapshot`.
  public let results: [PipelineResult]

  /// The time at which the pipeline producing this result was executed.
  public let executionTime: Timestamp

  let bridge: __PipelineSnapshotBridge

  init(_ bridge: __PipelineSnapshotBridge, pipeline: Pipeline) {
    self.bridge = bridge
    self.pipeline = pipeline
    executionTime = self.bridge.execution_time
    results = self.bridge.results.map { PipelineResult($0) }
  }
}
