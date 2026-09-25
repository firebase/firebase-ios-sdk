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
import XCTest

@testable import CrashlyticsTelemetry

/// A thread-safe, actor-based mock conforming to `RecoveredTelemetryExporter`.
final actor MockRecoveryManager: RecoveredTelemetryExporter {

  private(set) var uploadedBatches: [[RecoveredSpan]] = []
  private var uploadExpectation: XCTestExpectation?

  func setUploadExpectation(_ expectation: XCTestExpectation?) {
    self.uploadExpectation = expectation
  }

  func uploadRecoveredSpans(spans: [RecoveredSpan]) async {
    uploadedBatches.append(spans)
    uploadExpectation?.fulfill()
  }

  func reset() {
    uploadedBatches.removeAll()
    uploadExpectation = nil
  }
}
