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

  /// Section 7 of the v12 E2E plan: DeviceCheck provider integration.
  ///
  /// Verifies behavior on Simulator (where DeviceCheck is unsupported)
  /// and live hardware exchange when credentials and physical device are available.
  @Suite(.serialized, .tags(.integration, .deviceCheck))
  struct `DeviceCheck provider tests` {
    /// Precondition for DVC-01: DeviceCheckProvider instantiates with a configured
    /// FirebaseApp.
    @Test func `DeviceCheck provider initializes successfully`() throws {
      let live = try LiveApp(caseID: "DVC01")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = DeviceCheckProvider(app: app)
      #expect(provider != nil, "DeviceCheckProvider should initialize with configured app.")
    }

    /// DVC-02: a direct token request on Simulator fails with App Check Core's
    /// `unsupported` error (code 4).
    ///
    /// On Simulator, DCDevice is unprovisioned for DeviceCheck attestation
    /// so the request fails safely without crashing.
    @Test(
      .enabled(if: !AppCheckTestEnvironment.isPhysicalDevice, "Simulator only")
    )
    func `DeviceCheck returns unsupported on Simulator`() async throws {
      let live = try LiveApp(caseID: "DVC02")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(DeviceCheckProvider(app: app))
      await #expect {
        _ = try await provider.getToken()
      } throws: { error in
        isUnsupportedProviderError(error)
      }
    }

    /// DVC-01: on physical hardware, live DeviceCheck token generation and
    /// backend exchange.
    @Test(
      .enabled(if: AppCheckTestEnvironment.isPhysicalDevice, "Physical hardware only")
    )
    func `DeviceCheck provider requests token on physical hardware`() async throws {
      let live = try LiveApp(caseID: "DVC03")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(DeviceCheckProvider(app: app))
      let token = try await provider.getToken()
      #expect(!token.token.isEmpty, "DeviceCheck token should not be empty")
      #expect(token.expirationDate > Date(), "DeviceCheck token should have valid expiration")
    }

    /// DVC-02 (limited-use): a limited-use request on Simulator fails with
    /// `unsupported` (code 4).
    @Test(
      .enabled(if: !AppCheckTestEnvironment.isPhysicalDevice, "Simulator only")
    )
    func `DeviceCheck provider limited-use fails safely on Simulator`() async throws {
      let live = try LiveApp(caseID: "DVC04")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(DeviceCheckProvider(app: app))
      await #expect {
        _ = try await provider.getLimitedUseToken()
      } throws: { error in
        isUnsupportedProviderError(error)
      }
    }

    /// DVC-01 (limited-use): on physical hardware, limited-use DeviceCheck token
    /// acquisition.
    @Test(
      .enabled(if: AppCheckTestEnvironment.isPhysicalDevice, "Physical hardware only")
    )
    func `DeviceCheck provider requests limited use token on physical hardware`() async throws {
      let live = try LiveApp(caseID: "DVC05")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(DeviceCheckProvider(app: app))
      let token = try await provider.getLimitedUseToken()
      #expect(!token.token.isEmpty, "Limited-use DeviceCheck token should not be empty")
      #expect(token.expirationDate > Date(), "Limited-use DeviceCheck token should have valid expiration")
    }
  }
#endif  // canImport(Testing) && !os(macOS) && !targetEnvironment(macCatalyst)
