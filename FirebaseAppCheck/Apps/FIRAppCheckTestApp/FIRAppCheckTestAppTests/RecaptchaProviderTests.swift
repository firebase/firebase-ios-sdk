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

#if canImport(Testing) && (os(iOS) || os(visionOS)) && !targetEnvironment(macCatalyst)
  import FirebaseAppCheck
  import FirebaseCore
  import Foundation
  import Testing

  /// Section 7 of the v12 E2E plan: reCAPTCHA Enterprise provider integration.
  ///
  /// Verifies SDK linkage detection, provider factory initialization, and
  /// live token generation against the reCAPTCHA Enterprise backend using
  /// the project site key provided at runtime.
  @Suite(.serialized, .tags(.integration, .recaptcha))
  struct `Recaptcha provider tests` {
    /// RCP-01: Verifies token generation with a valid site key and configured FirebaseApp.
    @Test(
      .enabled(if: AppCheckTestEnvironment.isPhysicalDevice, "Physical hardware only")
    )
    func `Recaptcha provider initializes and requests token`() async throws {
      let siteKey = try #require(AppCheckTestEnvironment.recaptchaSiteKey)

      let live = try LiveApp(caseID: "RCP01")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let factory = RecaptchaProviderFactory(siteKey: siteKey)
      let provider = try #require(factory.createProvider(with: app))

      // Direct provider token request asserts the provider initializes and communicates
      // with reCAPTCHA Enterprise and App Check backend.
      let token = try await provider.getToken()
      #expect(!token.token.isEmpty, "Returned App Check token should not be empty")
      #expect(token.expirationDate > Date(), "Token should not be expired")
    }

    /// RCP-02 (linked half): when RecaptchaEnterprise is linked, RecaptchaProvider
    /// can be instantiated. The unlinked half needs a build without the SDK.
    @Test func `Recaptcha provider initializes when linked`() throws {
      let live = try LiveApp(caseID: "RCP02")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let siteKey = AppCheckTestEnvironment.recaptchaSiteKey ?? "placeholder-site-key"
      let provider = RecaptchaProvider(app: app, siteKey: siteKey)
      #expect(provider != nil, "RecaptchaProvider should initialize when RecaptchaEnterprise is linked.")
    }

    /// RCP-01 (limited-use): limited-use token generation via RecaptchaProvider.
    @Test(
      .enabled(if: AppCheckTestEnvironment.isPhysicalDevice, "Physical hardware only")
    )
    func `Recaptcha provider requests limited use token`() async throws {
      let siteKey = try #require(AppCheckTestEnvironment.recaptchaSiteKey)

      let live = try LiveApp(caseID: "RCP03")
      defer { Task { await live.tearDown() } }
      let app = live.app

      let provider = try #require(RecaptchaProvider(app: app, siteKey: siteKey))

      let token = try await provider.getLimitedUseToken()
      #expect(!token.token.isEmpty, "Returned limited-use App Check token should not be empty")
      #expect(token.expirationDate > Date(), "Limited-use token should not be expired")
    }
  }
#endif  // canImport(Testing) && (os(iOS) || os(visionOS)) && !targetEnvironment(macCatalyst)
