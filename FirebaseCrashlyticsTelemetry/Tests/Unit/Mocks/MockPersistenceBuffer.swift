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

@testable import CrashlyticsTelemetry

final class MockPersistenceBuffer: PersistenceBuffer, @unchecked Sendable {

  struct SetAttributeCall: Equatable {
    let spanId: UInt64
    let key: String
    let value: String
  }

  var addedSpans: [PersistenceSpan] = []
  var setAttributeCalls: [SetAttributeCall] = []
  var removedSpanIds: [UInt64] = []

  func add(_ span: PersistenceSpan) {
    addedSpans.append(span)
  }

  func setAttribute(_ value: String, forKey key: String, onSpanId spanId: UInt64) {
    setAttributeCalls.append(.init(spanId: spanId, key: key, value: value))
  }

  func removeSpanId(_ spanId: UInt64) {
    removedSpanIds.append(spanId)
  }
}
