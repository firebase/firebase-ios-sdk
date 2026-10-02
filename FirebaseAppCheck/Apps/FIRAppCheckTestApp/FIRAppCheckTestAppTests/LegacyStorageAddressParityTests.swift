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

#if canImport(Testing)
  import FirebaseAppCheck
  import FirebaseCore
  import Foundation
  import Testing

  /// MIG-12: verifies that v12 addresses stored state exactly where v11 did.
  ///
  /// Decoding compatibility and address compatibility are independent failure
  /// modes, and only the first is covered by unarchiving tests. If the derived
  /// key drifts, the decoder remains perfectly correct while reading from an
  /// address nothing was ever written to, so every upgrading user silently
  /// loses their cached token and re-attests.
  ///
  /// Serialized because `AppCheck.setAppCheckProviderFactory` and the Keychain
  /// are process-global.
  @Suite(.serialized, .tags(.integration, .migration))
  struct `Legacy storage address parity` {
    // MARK: - Golden literals

    /// Pins the composed addresses against full expected strings.
    ///
    /// This guards the harness itself. `LegacyStorageAddress` is the test's
    /// record of the v11 contract, so a typo there would quietly weaken every
    /// migration assertion that depends on it.
    @Test func `Composed addresses match the v11 contract`() {
      let resolved = LegacyStorageAddress.resolve(
        appName: "__FIRAPP_DEFAULT",
        projectID: "test-project",
        googleAppID: "1:123456789:ios:abc123"
      )

      #expect(resolved.serviceName == "FirebaseApp:__FIRAPP_DEFAULT")
      #expect(resolved.resourceName == "projects/test-project/apps/1:123456789:ios:abc123")
      #expect(
        resolved.keySuffix
          == "FirebaseApp:__FIRAPP_DEFAULT.projects/test-project/apps/1:123456789:ios:abc123"
      )
      #expect(
        resolved.tokenKey
          == "app_check_token.FirebaseApp:__FIRAPP_DEFAULT.projects/test-project/apps/1:123456789:ios:abc123"
      )
      #expect(
        resolved.artifactKey
          == "app_check_app_attest_artifact.FirebaseApp:__FIRAPP_DEFAULT.projects/test-project/apps/1:123456789:ios:abc123"
      )
      #expect(
        resolved.keyIDKey
          == "app_attest_keyID.FirebaseApp:__FIRAPP_DEFAULT.projects/test-project/apps/1:123456789:ios:abc123"
      )
    }

    /// Service and suite identifiers are frozen and must never be renamed.
    @Test func `Storage service identifiers are unchanged`() {
      #expect(LegacyStorageAddress.tokenKeychainService == "com.google.app_check_core.token_storage")
      #expect(
        LegacyStorageAddress.artifactKeychainService
          == "com.firebase.app_check.app_attest_artifact_storage"
      )
      #expect(LegacyStorageAddress.keyIDSuiteName == "com.firebase.GACAppAttestKeyIDStorage")
      #expect(LegacyStorageAddress.errorDomain == "com.google.app_check_core")
    }

    // MARK: - Black-box placement

    // Excluded on macOS and Mac Catalyst, where Keychain writes prompt for a
    // provisioning profile. See go/firebase-macos-keychain-popups.
    #if !os(macOS) && !targetEnvironment(macCatalyst)
      /// MIG-07: Corrupted token payload in Keychain is treated as cache miss
      /// and recovers safely without crashing.
      @Test func `Corrupted token in keychain is recovered safely`() async throws {
        let appName = "AppCheckTest-MIG07-\(UUID().uuidString.prefix(8))"
        let projectID = "appcheck-harness"
        let googleAppID = "1:123456789:ios:abc123"

        let address = LegacyStorageAddress.resolve(
          appName: appName,
          projectID: projectID,
          googleAppID: googleAppID
        )

        // Seed garbage data into Keychain
        let garbageData = "corrupted_garbage_bytes".data(using: .utf8)!
        KeychainProbe.write(
          garbageData,
          service: LegacyStorageAddress.tokenKeychainService,
          account: address.tokenKey
        )
        defer {
          KeychainProbe.remove(
            service: LegacyStorageAddress.tokenKeychainService,
            account: address.tokenKey
          )
        }

        TestProviderRegistry.shared.register(
          StubAppCheckProvider(),
          forAppNamed: appName
        )
        defer { TestProviderRegistry.shared.unregisterApp(named: appName) }

        let options = FirebaseOptions(
          googleAppID: googleAppID,
          gcmSenderID: "123456789"
        )
        options.projectID = projectID
        options.apiKey = "mig07-api-key"
        FirebaseApp.configure(name: appName, options: options)

        let app = try #require(FirebaseApp.app(name: appName))
        defer {
          Task { await withCheckedContinuation { c in app.delete { _ in c.resume() } } }
        }

        let appCheck = try #require(AppCheck.appCheck(app: app))

        // Unarchiving garbage data should fail gracefully and fetch a fresh token from provider
        let token = try await appCheck.token(forcingRefresh: false)
        #expect(token.token == StubAppCheckProvider.tokenValue)
      }

      /// MIG-12: Confirms the SDK physically writes to the v11 Keychain address.
      ///
      /// Reads through `SecItemCopyMatching` rather than the SDK so the
      /// assertion cannot be satisfied by a self-consistent but relocated
      /// implementation. Uses a stub provider, so it needs no backend, no
      /// credentials, and no hardware.
      @Test func `Token lands at the v11 keychain address`() async throws {
        let appName = "mig12_\(UUID().uuidString.prefix(8))"
        let projectID = "mig12-project"
        // The final component must be hexadecimal or `FirebaseApp.configure`
        // rejects the app ID. Uniqueness comes from the app name.
        let googleAppID = "1:123456789:ios:abc123"

        let address = LegacyStorageAddress.resolve(
          appName: appName,
          projectID: projectID,
          googleAppID: googleAppID
        )

        // Start from a known-empty address so a stale item cannot pass this.
        KeychainProbe.remove(
          service: LegacyStorageAddress.tokenKeychainService,
          account: address.tokenKey
        )
        #expect(
          !KeychainProbe.exists(
            service: LegacyStorageAddress.tokenKeychainService,
            account: address.tokenKey
          ),
          "Precondition: address must be empty before the SDK writes"
        )

        defer {
          KeychainProbe.remove(
            service: LegacyStorageAddress.tokenKeychainService,
            account: address.tokenKey
          )
        }

        // Bind to this app's name rather than installing a global factory.
        // A global install here races every other suite: Swift Testing runs
        // suites concurrently, and the factory is process-wide, so whichever
        // suite installs last wins for every app that has not yet made its
        // first token request.
        TestProviderRegistry.shared.register(
          StubAppCheckProvider(),
          forAppNamed: appName
        )
        defer { TestProviderRegistry.shared.unregisterApp(named: appName) }

        let options = FirebaseOptions(
          googleAppID: googleAppID,
          gcmSenderID: "123456789"
        )
        options.projectID = projectID
        options.apiKey = "mig12-api-key"
        FirebaseApp.configure(name: appName, options: options)

        let app = try #require(FirebaseApp.app(name: appName))
        let appCheck = try #require(AppCheck.appCheck(app: app))

        let token = try await appCheck.token(forcingRefresh: true)
        #expect(token.token == StubAppCheckProvider.tokenValue)

        #expect(
          KeychainProbe.exists(
            service: LegacyStorageAddress.tokenKeychainService,
            account: address.tokenKey
          ),
          """
          Token absent at the v11 address \(address.tokenKey). \
          The key derivation has drifted, which orphans cached tokens on upgrade.
          """
        )
      }
    #endif  // !os(macOS) && !targetEnvironment(macCatalyst)
  }

  // MARK: - Stub provider

  /// Returns a fixed token without touching the network, so storage placement
  /// can be verified with no backend or credentials.
  final class StubAppCheckProvider: NSObject, AppCheckProvider {
    static let tokenValue = "mig12-stub-token"

    func getToken() async throws -> AppCheckToken {
      AppCheckToken(token: Self.tokenValue, expirationDate: .distantFuture)
    }

    func getLimitedUseToken() async throws -> AppCheckToken {
      AppCheckToken(token: Self.tokenValue, expirationDate: .distantFuture)
    }
  }
#endif  // canImport(Testing)
