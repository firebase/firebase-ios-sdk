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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import Foundation
import Testing

@testable import FirebaseAILogic

struct FirebaseInfoHeadersTests {
  @Test
  func standardHeaders() async throws {
    let firebaseInfo = makeFirebaseInfo()

    let headers = try await firebaseInfo.requestHeaders()

    #expect(headers["Content-Type"] == "application/json")
    #expect(headers["x-goog-api-key"] == "API_KEY")
    #expect(headers["x-ios-bundle-identifier"] == Bundle.main.bundleIdentifier)
    let clientTags = try #require(headers["x-goog-api-client"]?.components(separatedBy: " "))
    #expect(clientTags.contains(Constants.languageTag))
    #expect(clientTags.contains(Constants.firebaseVersionTag))
    #expect(headers["X-Firebase-AppId"] == "My app ID")
    let expectedAppVersion =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    #expect(headers["X-Firebase-AppVersion"] == expectedAppVersion)
    #expect(headers["Authorization"] == nil)
    #expect(headers["X-Firebase-AppCheck"] == nil)
  }

  @Test
  func appCheckHeaders() async throws {
    let appCheck = AppCheckInteropFake(token: "test-app-check-token")
    let firebaseInfo = makeFirebaseInfo(appCheck: appCheck)

    let headers = try await firebaseInfo.requestHeaders()

    #expect(headers["X-Firebase-AppCheck"] == "test-app-check-token")
  }

  @Test
  func appCheckLimitedUseHeaders() async throws {
    let appCheck = AppCheckInteropFake(token: "test-app-check-token")
    let firebaseInfo = makeFirebaseInfo(
      appCheck: appCheck,
      useLimitedUseAppCheckTokens: true
    )

    let headers = try await firebaseInfo.requestHeaders()

    #expect(headers["X-Firebase-AppCheck"] == "limited_use_test-app-check-token")
  }

  @Test
  func appCheckErrorReturnsPlaceholderToken() async throws {
    let appCheck = AppCheckInteropFake(error: AppCheckErrorFake())
    let firebaseInfo = makeFirebaseInfo(appCheck: appCheck)

    let headers = try await firebaseInfo.requestHeaders()

    #expect(headers["X-Firebase-AppCheck"] == AppCheckInteropFake.placeholderTokenValue)
  }

  @Test
  func authHeaders() async throws {
    let auth = AuthInteropFake(token: "test-auth-token")
    let firebaseInfo = makeFirebaseInfo(auth: auth)

    let headers = try await firebaseInfo.requestHeaders()

    #expect(headers["Authorization"] == "Firebase test-auth-token")
  }

  @Test
  func additionalClientTags() async throws {
    let firebaseInfo = makeFirebaseInfo()

    let headers = try await firebaseInfo.requestHeaders(
      additionalClientTags: ["fma", "hybrid"]
    )

    let clientTags = try #require(headers["x-goog-api-client"]?.components(separatedBy: " "))
    #expect(clientTags.contains(Constants.languageTag))
    #expect(clientTags.contains(Constants.firebaseVersionTag))
    #expect(clientTags.contains("fma"))
    #expect(clientTags.contains("hybrid"))
  }

  @Test
  func dataCollectionDisabled() async throws {
    let firebaseInfo = makeFirebaseInfo(privateAppID: true)

    let headers = try await firebaseInfo.requestHeaders()

    #expect(headers["X-Firebase-AppId"] == nil)
    #expect(headers["X-Firebase-AppVersion"] == nil)
  }

  @Test
  func applyHeadersToURLRequest() async throws {
    let auth = AuthInteropFake(token: "test-auth-token")
    let appCheck = AppCheckInteropFake(token: "test-app-check-token")
    let firebaseInfo = makeFirebaseInfo(
      appCheck: appCheck,
      auth: auth
    )
    let url = try #require(URL(string: "https://firebasevertexai.googleapis.com"))
    var request = URLRequest(url: url)

    try await firebaseInfo.applyHeaders(to: &request, additionalClientTags: ["custom-tag"])

    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "API_KEY")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Firebase test-auth-token")
    #expect(request.value(forHTTPHeaderField: "X-Firebase-AppCheck") == "test-app-check-token")
    let clientTags = try #require(
      request.value(forHTTPHeaderField: "x-goog-api-client")?.components(separatedBy: " ")
    )
    #expect(clientTags.contains("custom-tag"))
  }

  @Test
  func defaultErrorDomainResolution() {
    #expect(
      FirebaseInfo.defaultErrorDomain(for: "FirebaseAILogic/GenerativeAIService.swift") ==
        "GenerativeAIService"
    )
    #expect(
      FirebaseInfo.defaultErrorDomain(for: "FirebaseAILogic/LiveSessionService.swift") ==
        "LiveSessionService"
    )
    #expect(
      FirebaseInfo.defaultErrorDomain(for: "FirebaseAILogic/GeminiLanguageModel+Firebase.swift") ==
        "GeminiLanguageModel"
    )
    #expect(
      FirebaseInfo.defaultErrorDomain(for: "SomeFile.swift") == "SomeFile"
    )
    #expect(
      FirebaseInfo.defaultErrorDomain(for: "") == "FirebaseAI"
    )
  }

  @Test
  func explicitErrorDomain() async throws {
    let appCheck = AppCheckInteropFake(token: "test-token")
    let firebaseInfo = makeFirebaseInfo(appCheck: appCheck)

    let headers = try await firebaseInfo.requestHeaders(errorDomain: "CustomErrorDomain")

    #expect(headers["X-Firebase-AppCheck"] == "test-token")
  }

  // MARK: - Private Helpers

  private func makeFirebaseInfo(appCheck: AppCheckInterop? = nil,
                                auth: AuthInterop? = nil,
                                privateAppID: Bool = false,
                                useLimitedUseAppCheckTokens: Bool = false) -> FirebaseInfo {
    let app = FirebaseApp(
      instanceWithName: UUID().uuidString,
      options: FirebaseOptions(googleAppID: "ignore", gcmSenderID: "ignore")
    )
    app.isDataCollectionDefaultEnabled = !privateAppID
    return FirebaseInfo(
      appCheck: appCheck,
      auth: auth,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      firebaseAppID: "My app ID",
      firebaseApp: app,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
  }
}
