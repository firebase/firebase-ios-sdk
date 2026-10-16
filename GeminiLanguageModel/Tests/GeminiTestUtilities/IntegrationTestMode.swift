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

/// The network mode used by integration tests, selected with `INTEGRATION_TEST_MODE`.
///
/// In `record` and `replay` modes, requests are routed through a local
/// [test-server](https://github.com/google/test-server) proxy started by
/// `scripts/test-server.sh`.
package enum IntegrationTestMode: String, Sendable, CaseIterable {
  /// Sends requests directly to the live backends (the default).
  case live

  /// Proxies requests to the live backends through test-server, which records each interaction.
  case record

  /// Serves previously recorded interactions from test-server without network access or
  /// credentials.
  case replay

  /// The environment variable that selects the integration test mode.
  package static let environmentVariable = "INTEGRATION_TEST_MODE"

  /// Indicates whether requests are routed through the local test-server proxy.
  package var usesTestServer: Bool {
    self != .live
  }
}

extension IntegrationTestEnvironment {
  /// The integration test mode resolved from `INTEGRATION_TEST_MODE`.
  ///
  /// Defaults to `.live` when the variable is unset or empty. Unrecognized values stop the test
  /// process rather than silently falling back to live requests (or skipping every test in CI).
  package var integrationTestMode: IntegrationTestMode {
    guard let value = variables[IntegrationTestMode.environmentVariable], !value.isEmpty else {
      return .live
    }
    guard let mode = IntegrationTestMode(rawValue: value.lowercased()) else {
      let supportedValues = IntegrationTestMode.allCases.map(\.rawValue).joined(separator: ", ")
      preconditionFailure(
        "Unsupported \(IntegrationTestMode.environmentVariable) value '\(value)'; expected one "
          + "of: \(supportedValues)."
      )
    }
    return mode
  }
}

// MARK: - Test Server Configuration

/// Constants shared with the test-server configuration in `Tests/TestServer/test-server.yml`.
package enum TestServerConfiguration {
  /// The local port that proxies `generativelanguage.googleapis.com`.
  package static let developerAPIPort = 1443

  /// The local port that proxies `firebasevertexai.googleapis.com`.
  package static let firebaseAILogicPort = 1444

  /// The host name of the local test-server proxy.
  package static let host = "localhost"

  /// The request header test-server uses to name recording files.
  package static let recordingNameHeader = "Test-Name"

  /// The placeholder test-server substitutes for values listed in `TEST_SERVER_SECRETS`.
  ///
  /// Recorded URLs contain this placeholder instead of the Firebase project ID, so replayed
  /// requests use it as the project ID.
  package static let redactedPlaceholder = "REDACTED"
}
