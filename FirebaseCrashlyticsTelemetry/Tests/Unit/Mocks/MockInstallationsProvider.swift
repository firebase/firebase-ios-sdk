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

@testable import FirebaseCrashlyticsTelemetry

struct MockInstallationsProvider: TelemetryInstallationsProvider {
  private enum Behavior: Sendable {
    case success(String)
    case failure(Error)
    case delayed(UInt64, String)
  }

  private let behavior: Behavior

  init(installationId: String) {
    behavior = .success(installationId)
  }

  init(error: Error) {
    behavior = .failure(error)
  }

  init(delayNanoseconds: UInt64, installationId: String) {
    behavior = .delayed(delayNanoseconds, installationId)
  }

  func installationID() async throws -> String {
    switch behavior {
    case let .success(installationId):
      return installationId
    case let .failure(error):
      throw error
    case let .delayed(delayNanoseconds, installationId):
      try await Task.sleep(nanoseconds: delayNanoseconds)
      return installationId
    }
  }
}
