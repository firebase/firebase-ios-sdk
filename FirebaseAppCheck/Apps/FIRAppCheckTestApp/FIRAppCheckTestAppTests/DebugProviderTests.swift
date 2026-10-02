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

#if canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
  import FirebaseAppCheck
  import FirebaseCore
  import Foundation
  import Testing

  /// Section 7 of the v12 E2E plan: Debug provider integration.
  ///
  /// Verifies token generation with a registered debug token, and
  /// backend rejection (HTTP 403) with an unregistered debug token.
  @Suite(.serialized, .tags(.integration, .debugProvider))
  struct `Debug provider tests` {
    /// DBG-05 (exchange half): a registered debug token exchanges for an App
    /// Check token against the Firebase backend. Flag persistence across
    /// relaunch is not asserted.
    @Test func `Registered debug token exchanges successfully`() async throws {
      let live = try LiveApp(caseID: "DBG05")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let debugToken = try #require(AppCheckTestEnvironment.debugToken)
      let key = "AppCheckDebugToken"
      let previous = ProcessInfo.processInfo.environment[key]
      setenv(key, debugToken, 1)
      defer {
        if let previous {
          setenv(key, previous, 1)
        } else {
          unsetenv(key)
        }
      }

      let provider = try #require(AppCheckDebugProvider(app: app))
      let token = try await provider.getToken()

      #expect(!token.token.isEmpty, "Exchanged debug token should not be empty")
      #expect(token.expirationDate > Date(), "Exchanged token should not be expired")
    }

    /// DBG-06: Verifies that an invalid/unregistered debug token fails exchange
    /// with an HTTP 403 error.
    @Test func `Unregistered debug token fails exchange with 403`() async throws {
      let live = try LiveApp(caseID: "DBG06")
      defer { Task { await live.tearDown() } }
      let app = live.app

      // We instantiate the debug provider with an unregistered placeholder UUID
      let placeholderUUID = "00000000-0000-0000-0000-000000000000"
      let key = "AppCheckDebugToken"
      let previous = ProcessInfo.processInfo.environment[key]
      setenv(key, placeholderUUID, 1)
      defer {
        if let previous {
          setenv(key, previous, 1)
        } else {
          unsetenv(key)
        }
      }

      let provider = try #require(AppCheckDebugProvider(app: app))
      do {
        _ = try await provider.getToken()
        Issue.record("Expected unregistered debug token to fail exchange.")
      } catch {
        // Direct provider calls return App Check Core's error untranslated.
        // Core reports every non-2xx response as `unknown` (0), with the
        // status in the failure reason. Only a 403 shows the backend actually
        // received the token and rejected it; a network failure or 5xx would
        // also throw.
        let nsError = error as NSError
        #expect(
          nsError.domain == appCheckCoreErrorDomain,
          "Expected App Check Core error domain, got: \(nsError.domain)"
        )
        #expect(nsError.code == 0, "Expected AppCheckCoreErrorCode.unknown, got: \(nsError.code)")
        #expect(
          httpStatusCode(of: error) == 403,
          "Expected HTTP 403 from the token exchange, got: \(error)"
        )
      }
    }
  }
#endif  // canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
