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
  import DeviceCheck
  import FirebaseAppCheck
  import FirebaseCore
  import Foundation
  import Testing

  /// Section 7 of the v12 E2E plan: App Attest provider integration.
  ///
  /// Verifies initialization, simulator fallback behavior, and live token
  /// generation against Apple App Attest service and Firebase backend.
  @Suite(.serialized, .tags(.integration, .appAttest))
  struct `App Attest provider tests` {
    /// Precondition for ATT-01 and ATT-03: AppAttestProvider instantiates with a
    /// configured FirebaseApp.
    @Test func `App Attest provider initializes successfully`() throws {
      let live = try LiveApp(caseID: "ATT01")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = AppAttestProvider(app: app)
      #expect(provider != nil, "AppAttestProvider should initialize with configured app.")
    }

    /// ATT-09: a direct token request on Simulator fails with App Check Core's
    /// `unsupported` error (code 4).
    ///
    /// On Simulator, DCAppAttestService is unprovisioned for production attestation
    /// so the attestation request fails safely without crashing.
    @Test(
      .enabled(if: !AppCheckTestEnvironment.isPhysicalDevice, "Simulator only")
    )
    func `App Attest provider fails safely on Simulator`() async throws {
      let live = try LiveApp(caseID: "ATT02")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(AppAttestProvider(app: app))
      await #expect {
        _ = try await provider.getToken()
      } throws: { error in
        isUnsupportedProviderError(error)
      }
    }

    /// ATT-01: on physical hardware, App Attest key generation, attestation, and
    /// token exchange. On a device that already attested, this exercises the
    /// ATT-02 assertion path instead.
    @Test(
      .enabled(if: AppCheckTestEnvironment.isPhysicalDevice, "Physical hardware only")
    )
    func `App Attest provider requests token on physical hardware`() async throws {
      let live = try LiveApp(caseID: "ATT03")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(AppAttestProvider(app: app))
      let token = try await provider.getToken()
      #expect(!token.token.isEmpty, "App Attest token should not be empty")
      #expect(token.expirationDate > Date(), "App Attest token should have valid expiration")
    }

    /// ATT-09 (limited-use): a limited-use request on Simulator fails with
    /// `unsupported` (code 4).
    @Test(
      .enabled(if: !AppCheckTestEnvironment.isPhysicalDevice, "Simulator only")
    )
    func `App Attest provider limited-use fails safely on Simulator`() async throws {
      let live = try LiveApp(caseID: "ATT04")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(AppAttestProvider(app: app))
      await #expect {
        _ = try await provider.getLimitedUseToken()
      } throws: { error in
        isUnsupportedProviderError(error)
      }
    }

    /// ATT-03: on physical hardware, limited-use App Attest token acquisition.
    @Test(
      .enabled(if: AppCheckTestEnvironment.isPhysicalDevice, "Physical hardware only")
    )
    func `App Attest provider requests limited use token on physical hardware`() async throws {
      let live = try LiveApp(caseID: "ATT05")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(AppAttestProvider(app: app))
      let token = try await provider.getLimitedUseToken()
      #expect(!token.token.isEmpty, "Limited-use App Attest token should not be empty")
      #expect(token.expirationDate > Date(), "Limited-use App Attest token should have valid expiration")
    }
  }
#endif  // canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
