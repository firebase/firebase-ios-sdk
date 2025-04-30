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
public struct RealtimePipelineSnapshot: Sendable {
  /// The Pipeline on which `execute()` was called to obtain this `PipelineSnapshot`.
  public let pipeline: RealtimePipeline

  /// An array of all the results in the `PipelineSnapshot`.
  let results_cache: [PipelineResult]

  public let changes: [PipelineResultChange]
  public let metadata: SnapshotMetadata

  let bridge: __RealtimePipelineSnapshotBridge

  init(_ bridge: __RealtimePipelineSnapshotBridge, pipeline: RealtimePipeline) {
    self.bridge = bridge
    self.pipeline = pipeline
    metadata = bridge.metadata
    results_cache = self.bridge.results.map { PipelineResult($0) }
    changes = self.bridge.changes.map { PipelineResultChange($0) }
  }

  public func results() -> [PipelineResult] {
    return results_cache
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct PipelineResultChange: Sendable {
  public enum ChangeType {
    case added, modified, removed
  }

  let bridge: __PipelineResultChangeBridge
  public let result: PipelineResult

  public let oldIndex: UInt?
  public let newIndex: UInt?

  init(_ bridge: __PipelineResultChangeBridge) {
    self.bridge = bridge
    result = PipelineResult(self.bridge.result)
    oldIndex = self.bridge.oldIndex == NSNotFound ? nil : self.bridge.oldIndex
    newIndex = self.bridge.newIndex == NSNotFound ? nil : self.bridge.newIndex
  }

  public var type: ChangeType {
    switch bridge.type {
    case .added:
      return .added
    case .modified:
      return .modified
    case .removed:
      return .removed
    }
  }
}
