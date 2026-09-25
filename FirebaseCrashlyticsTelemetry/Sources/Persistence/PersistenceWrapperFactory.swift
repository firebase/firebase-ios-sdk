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
import PersistenceWrapper

internal enum PersistenceWrapperFactory {

  #if DEBUG
  /// Test-only hook to inject a mock buffer and recovered spans during unit tests.
  nonisolated(unsafe) internal static var mockBuffer: PersistenceBuffer?
  nonisolated(unsafe) internal static var mockRecoveredSpans: [PersistenceSpan] = []
  nonisolated(unsafe) internal static var simulateBufferFailure: Bool = false
  nonisolated(unsafe) internal static var captureInitFilePath: String?
  nonisolated(unsafe) internal static var captureInitBufferSize: PersistenceBufferSize?

  /// Resets test-only configuration state back to default.
  internal static func reset() {
    mockBuffer = nil
    mockRecoveredSpans = []
    simulateBufferFailure = false
    captureInitFilePath = nil
    captureInitBufferSize = nil
  }
  #endif

  /// Initializes and returns the storage buffer.
  ///
  /// - Parameters:
  ///   - filePath: Path to the mmap storage file.
  ///   - bufferSize:Sizing constraints.
  ///   - outRecoveredSpans: Inout parameter containing any harvested spans from a prior session.
  /// - Returns: A `SpanBufferProtocol` instance, or nil if creation failed.
  internal static func initialize(
    filePath: String,
    bufferSize: PersistenceBufferSize,
    recoveredSpans outRecoveredSpans: inout NSArray?
  ) -> PersistenceBuffer? {
    #if DEBUG
    if mockBuffer != nil || simulateBufferFailure {
      captureInitFilePath = filePath
      captureInitBufferSize = bufferSize
      outRecoveredSpans = mockRecoveredSpans as NSArray
      return mockBuffer
    }
    #endif

    return PersistenceBufferWrapper.initialize(
      withFilePath: filePath,
      bufferSize: bufferSize,
      recoveredSpans: &outRecoveredSpans
    )
  }
}
