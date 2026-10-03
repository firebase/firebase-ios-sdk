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

import FirebaseAppCheck
import FirebaseAppCheckInterop
import FirebaseCore
import FirebaseCoreExtension
import FirebaseCoreInternal
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Testing

// MARK: - Test Doubles

private final class MockURLProtocol: URLProtocol {
  typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

  private static let handlers = UnfairLock<[String: Handler]>([:])

  static func setHandler(for urlString: String, handler: @escaping Handler) {
    handlers.withLock { $0[urlString] = handler }
  }

  static func reset() {
    handlers.withLock { $0.removeAll() }
  }

  override class func canInit(with request: URLRequest) -> Bool {
    guard let urlString = request.url?.absoluteString else { return false }
    return handlers.withLock { $0[urlString] != nil }
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let urlString = request.url?.absoluteString,
          let handler = Self.handlers.withLock({ $0[urlString] }) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

private extension URLRequest {
  var bodyData: Data? {
    if let httpBody { return httpBody }
    guard let stream = httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while true {
      let readCount = stream.read(&buffer, maxLength: buffer.count)
      if readCount < 0 {
        return nil
      } else if readCount == 0 {
        break
      }
      data.append(contentsOf: buffer[..<readCount])
    }
    return data
  }
}

private final class FakeAppCheckProvider: AppCheckProvider, Sendable {
  struct State: Sendable {
    var getTokenCallCount = 0
    var getLimitedUseTokenCallCount = 0
    var tokenResult: Result<AppCheckToken, any Error>
    var limitedUseTokenResult: Result<AppCheckToken, any Error>
  }

  let state: UnfairLock<State>

  init(tokenResult: Result<AppCheckToken, any Error>,
       limitedUseTokenResult: Result<AppCheckToken, any Error>? = nil) {
    state = UnfairLock(
      State(
        tokenResult: tokenResult,
        limitedUseTokenResult: limitedUseTokenResult ?? tokenResult
      )
    )
  }

  func getToken() async throws -> AppCheckToken {
    let result = state.withLock { state -> Result<AppCheckToken, any Error> in
      state.getTokenCallCount += 1
      return state.tokenResult
    }
    return try result.get()
  }

  func getLimitedUseToken() async throws -> AppCheckToken {
    let result = state.withLock { state -> Result<AppCheckToken, any Error> in
      state.getLimitedUseTokenCallCount += 1
      return state.limitedUseTokenResult
    }
    return try result.get()
  }
}

private struct DefaultFallbackAppCheckProvider: AppCheckProvider {
  let token: AppCheckToken

  func getToken() async throws -> AppCheckToken {
    token
  }
}

private struct SelectiveAppCheckProviderFactory: AppCheckProviderFactory {
  let excludedAppNameSubstring: String
  let provider: any AppCheckProvider

  func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    if app.name.contains(excludedAppNameSubstring) {
      return nil
    }
    return provider
  }
}

// MARK: - Tests

@Suite("FirebaseAppCheck Portable Tests", .serialized)
struct FirebaseAppCheckPortableTests {
  init() {
    FirebaseApp.resetApps()
    FirebaseComponentContainer.removeAllRegistrations()
    AppCheck.setAppCheckProviderFactory(nil)
    MockURLProtocol.reset()
  }

  private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
  }

  private func makeValidOptions() -> FirebaseOptions {
    let options = FirebaseOptions(googleAppID: "1:123:ios:abc", gcmSenderID: "123")
    options.apiKey = "AIzaSyTestKey1234567890"
    options.projectID = "test-project"
    return options
  }

  // MARK: - AppCheckDebugProvider Tests

  @Test
  func debugProviderInitValidation() throws {
    let validOptions = makeValidOptions()
    FirebaseApp.configure(name: "ValidApp", options: validOptions)
    let validApp = try #require(FirebaseApp.app(name: "ValidApp"))

    let missingAPIKeyOptions = makeValidOptions()
    missingAPIKeyOptions.apiKey = nil
    FirebaseApp.configure(name: "MissingAPIKeyApp", options: missingAPIKeyOptions)
    let missingAPIKeyApp = try #require(FirebaseApp.app(name: "MissingAPIKeyApp"))

    let missingProjectIDOptions = makeValidOptions()
    missingProjectIDOptions.projectID = nil
    FirebaseApp.configure(name: "MissingProjectIDApp", options: missingProjectIDOptions)
    let missingProjectIDApp = try #require(FirebaseApp.app(name: "MissingProjectIDApp"))

    let missingAppIDOptions = FirebaseOptions(googleAppID: "", gcmSenderID: "123")
    missingAppIDOptions.apiKey = "AIzaSyTestKey1234567890"
    missingAppIDOptions.projectID = "test-project"
    FirebaseApp.configure(name: "MissingAppIDApp", options: missingAppIDOptions)
    let missingAppIDApp = try #require(FirebaseApp.app(name: "MissingAppIDApp"))

    #expect(AppCheckDebugProvider(app: validApp) != nil)
    #expect(AppCheckDebugProvider(app: missingAPIKeyApp) == nil)
    #expect(AppCheckDebugProvider(app: missingProjectIDApp) == nil)
    #expect(AppCheckDebugProvider(app: missingAppIDApp) == nil)
  }

  @Test
  func debugProviderCurrentDebugTokenPriority() {
    let provider1 = AppCheckDebugProvider(
      projectID: "p",
      googleAppID: "a",
      apiKey: "k",
      environment: [
        "AppCheckDebugToken": "token-1",
        "FIRAAppCheckDebugToken": "token-2",
        "APP_CHECK_DEBUG_TOKEN": "token-3",
      ],
      localDebugToken: "local-uuid"
    )
    let provider2 = AppCheckDebugProvider(
      projectID: "p",
      googleAppID: "a",
      apiKey: "k",
      environment: [
        "FIRAAppCheckDebugToken": "token-2",
        "APP_CHECK_DEBUG_TOKEN": "token-3",
      ],
      localDebugToken: "local-uuid"
    )
    let provider3 = AppCheckDebugProvider(
      projectID: "p",
      googleAppID: "a",
      apiKey: "k",
      environment: [
        "APP_CHECK_DEBUG_TOKEN": "token-3",
      ],
      localDebugToken: "local-uuid"
    )
    let provider4 = AppCheckDebugProvider(
      projectID: "p",
      googleAppID: "a",
      apiKey: "k",
      environment: [:],
      localDebugToken: "local-uuid"
    )

    #expect(provider1.currentDebugToken() == "token-1")
    #expect(provider2.currentDebugToken() == "token-2")
    #expect(provider3.currentDebugToken() == "token-3")
    #expect(provider4.currentDebugToken() == "local-uuid")
    #expect(provider4.localDebugToken() == "local-uuid")
  }

  @Test
  func debugProviderExchangeDebugTokenSuccess() async throws {
    struct CapturedBody: Decodable, Sendable {
      let debugToken: String
      let limitedUse: Bool
    }

    let endpoint =
      "https://firebaseappcheck.googleapis.com/v1/projects/my-proj/apps/1:99:ios:abc:exchangeDebugToken"
    let capturedRequest = UnfairLock<URLRequest?>(nil)
    let capturedBody = UnfairLock<CapturedBody?>(nil)

    MockURLProtocol.setHandler(for: endpoint) { request in
      capturedRequest.withLock { $0 = request }
      if let bodyData = request.bodyData,
         let decoded = try? JSONDecoder().decode(CapturedBody.self, from: bodyData) {
        capturedBody.withLock { $0 = decoded }
      }
      let responseJSON = #"{"token":"exchanged-jwt-token","ttl":"1800s"}"#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let provider = AppCheckDebugProvider(
      projectID: "my-proj",
      googleAppID: "1:99:ios:abc",
      apiKey: "my-api-key",
      session: makeMockSession(),
      environment: ["FIRAAppCheckDebugToken": "my-secret-debug-token"]
    )

    let before = Date()
    let token = try await provider.getToken()
    let request = try #require(capturedRequest.withLock { $0 })
    let body = try #require(capturedBody.withLock { $0 })

    #expect(token.token == "exchanged-jwt-token")
    #expect(token.expirationDate >= before.addingTimeInterval(1790))
    #expect(token.expirationDate <= Date().addingTimeInterval(1810))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "my-api-key")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(body.debugToken == "my-secret-debug-token")
    #expect(body.limitedUse == false)
  }

  @Test
  func debugProviderExchangeLimitedUseDebugTokenSuccess() async throws {
    let endpoint =
      "https://firebaseappcheck.googleapis.com/v1/projects/my-proj/apps/1:99:ios:abc:exchangeDebugToken"
    let capturedLimitedUse = UnfairLock<Bool?>(nil)

    MockURLProtocol.setHandler(for: endpoint) { request in
      if let bodyData = request.bodyData,
         let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
        capturedLimitedUse.withLock { $0 = json["limitedUse"] as? Bool }
      }
      let responseJSON = #"{"token":"limited-use-jwt-token"}"#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let provider = AppCheckDebugProvider(
      projectID: "my-proj",
      googleAppID: "1:99:ios:abc",
      apiKey: "my-api-key",
      session: makeMockSession(),
      environment: ["APP_CHECK_DEBUG_TOKEN": "my-secret-debug-token"]
    )

    let before = Date()
    let token = try await provider.getLimitedUseToken()

    #expect(token.token == "limited-use-jwt-token")
    #expect(token.expirationDate >= before.addingTimeInterval(3590))
    #expect(capturedLimitedUse.withLock { $0 } == true)
  }

  @Test
  func debugProviderErrorMapping() async {
    let endpoint =
      "https://firebaseappcheck.googleapis.com/v1/projects/my-proj/apps/1:99:ios:abc:exchangeDebugToken"
    let provider = AppCheckDebugProvider(
      projectID: "my-proj",
      googleAppID: "1:99:ios:abc",
      apiKey: "my-api-key",
      session: makeMockSession(),
      environment: ["AppCheckDebugToken": "my-secret"]
    )

    MockURLProtocol.setHandler(for: endpoint) { _ in
      throw URLError(.notConnectedToInternet)
    }

    do {
      _ = try await provider.getToken()
      Issue.record("Expected serverUnreachable error")
    } catch {
      let nsError = error as NSError
      #expect(nsError.domain == AppCheckErrorDomain)
      #expect(nsError.code == AppCheckErrorCode.serverUnreachable.rawValue)
    }

    MockURLProtocol.setHandler(for: endpoint) { request in
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 403,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(#"{"error":"forbidden"}"#.utf8))
    }

    do {
      _ = try await provider.getToken()
      Issue.record("Expected unknown error on HTTP 403")
    } catch {
      let nsError = error as NSError
      #expect(nsError.domain == AppCheckErrorDomain)
      #expect(nsError.code == AppCheckErrorCode.unknown.rawValue)
    }
  }

  // MARK: - AppCheck Caching & Interop Tests

  @Test
  func appCheckTokenCachingAndForcingRefresh() async throws {
    let initialToken = AppCheckToken(
      token: "cached-token-1",
      expirationDate: Date().addingTimeInterval(3600)
    )
    let provider = FakeAppCheckProvider(tokenResult: .success(initialToken))
    let appCheck = AppCheck(appName: "TestApp", provider: provider)

    let first = try await appCheck.token(forcingRefresh: false)
    let second = try await appCheck.token(forcingRefresh: false)

    let refreshedToken = AppCheckToken(
      token: "refreshed-token-2",
      expirationDate: Date().addingTimeInterval(3600)
    )
    provider.state.withLock { $0.tokenResult = .success(refreshedToken) }

    let third = try await appCheck.token(forcingRefresh: false)
    let forced = try await appCheck.token(forcingRefresh: true)
    let afterForced = try await appCheck.token(forcingRefresh: false)

    #expect(first.token == "cached-token-1")
    #expect(second.token == "cached-token-1")
    #expect(third.token == "cached-token-1")
    #expect(forced.token == "refreshed-token-2")
    #expect(afterForced.token == "refreshed-token-2")
    #expect(provider.state.withLock { $0.getTokenCallCount } == 2)
  }

  @Test
  func appCheckRefreshesNearExpirationToken() async throws {
    let expiringSoonToken = AppCheckToken(
      token: "expiring-soon",
      expirationDate: Date().addingTimeInterval(60)
    )
    let provider = FakeAppCheckProvider(tokenResult: .success(expiringSoonToken))
    let appCheck = AppCheck(appName: "TestApp", provider: provider)

    let first = try await appCheck.token(forcingRefresh: false)

    let freshToken = AppCheckToken(
      token: "fresh-token",
      expirationDate: Date().addingTimeInterval(3600)
    )
    provider.state.withLock { $0.tokenResult = .success(freshToken) }

    let second = try await appCheck.token(forcingRefresh: false)

    #expect(first.token == "expiring-soon")
    #expect(second.token == "fresh-token")
    #expect(provider.state.withLock { $0.getTokenCallCount } == 2)
  }

  @Test
  func appCheckLimitedUseTokenBypassesCache() async throws {
    let standardToken = AppCheckToken(
      token: "standard-token",
      expirationDate: Date().addingTimeInterval(3600)
    )
    let limitedToken = AppCheckToken(
      token: "limited-token",
      expirationDate: Date().addingTimeInterval(3600)
    )
    let provider = FakeAppCheckProvider(
      tokenResult: .success(standardToken),
      limitedUseTokenResult: .success(limitedToken)
    )
    let appCheck = AppCheck(appName: "TestApp", provider: provider)

    let limited1 = try await appCheck.limitedUseToken()
    let limited2 = try await appCheck.limitedUseToken()
    let standard = try await appCheck.token(forcingRefresh: false)

    let fallbackProvider = DefaultFallbackAppCheckProvider(token: standardToken)
    let fallbackToken = try await fallbackProvider.getLimitedUseToken()

    #expect(limited1.token == "limited-token")
    #expect(limited2.token == "limited-token")
    #expect(standard.token == "standard-token")
    #expect(fallbackToken.token == "standard-token")
    #expect(provider.state.withLock { $0.getLimitedUseTokenCallCount } == 2)
    #expect(provider.state.withLock { $0.getTokenCallCount } == 1)
  }

  @Test
  func appCheckInteropReturnsPlaceholderTokenOnFailure() async {
    let expectedError = AppCheckErrorUtil.error(
      code: .serverUnreachable,
      message: "Network failure"
    )
    let provider = FakeAppCheckProvider(tokenResult: .failure(expectedError))
    let appCheck = AppCheck(appName: "TestApp", provider: provider)

    let tokenResult = await appCheck.getToken(forcingRefresh: false)
    let limitedResult = await appCheck.getLimitedUseToken()

    #expect(tokenResult.token == AppCheck.placeholderToken)
    #expect((tokenResult.error as? NSError)?.code == AppCheckErrorCode.serverUnreachable.rawValue)
    #expect(limitedResult.token == AppCheck.placeholderToken)
    #expect((limitedResult.error as? NSError)?.code == AppCheckErrorCode.serverUnreachable.rawValue)
  }

  @Test
  func appCheckPostsNotificationOnTokenRefresh() async throws {
    let token = AppCheckToken(
      token: "notified-token",
      expirationDate: Date().addingTimeInterval(3600)
    )
    let provider = FakeAppCheckProvider(tokenResult: .success(token))
    let appCheck = AppCheck(appName: "NotificationApp", provider: provider)
    let receivedInfo = UnfairLock<[String: String]?>(nil)

    let observer = NotificationCenter.default.addObserver(
      forName: .AppCheckTokenDidChange,
      object: appCheck,
      queue: nil
    ) { notification in
      let tokenValue = notification.userInfo?[AppCheckTokenNotificationKey] as? String
      let appNameValue = notification.userInfo?[AppCheckAppNameNotificationKey] as? String
      if let tokenValue, let appNameValue {
        receivedInfo.withLock {
          $0 = [
            AppCheckTokenNotificationKey: tokenValue,
            AppCheckAppNameNotificationKey: appNameValue,
          ]
        }
      }
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    _ = try await appCheck.token(forcingRefresh: false)
    let info = try #require(receivedInfo.withLock { $0 })

    #expect(info[AppCheckTokenNotificationKey] == "notified-token")
    #expect(info[AppCheckAppNameNotificationKey] == "NotificationApp")
    #expect(
      appCheck.tokenDidChangeNotificationName() == Notification.Name.AppCheckTokenDidChange.rawValue
    )
    #expect(appCheck.notificationTokenKey() == AppCheckTokenNotificationKey)
    #expect(appCheck.notificationAppNameKey() == AppCheckAppNameNotificationKey)
  }

  @Test
  func containerRegistrationAndSelectiveProviderFactory() async throws {
    let validToken = AppCheckToken(
      token: "container-token",
      expirationDate: Date().addingTimeInterval(3600)
    )
    let provider = FakeAppCheckProvider(tokenResult: .success(validToken))
    let factory = SelectiveAppCheckProviderFactory(
      excludedAppNameSubstring: "appCheckNotConfigured",
      provider: provider
    )
    AppCheck.setAppCheckProviderFactory(factory)

    let options = makeValidOptions()
    FirebaseApp.configure(options: options)
    FirebaseApp.configure(name: "appCheckNotConfigured", options: options)

    let defaultApp = try #require(FirebaseApp.app())
    let unconfiguredApp = try #require(FirebaseApp.app(name: "appCheckNotConfigured"))

    let resolvedDefault = ComponentType<any AppCheckInterop>.instance(
      for: (any AppCheckInterop).self,
      in: defaultApp.container
    )
    let resolvedUnconfigured = ComponentType<any AppCheckInterop>.instance(
      for: (any AppCheckInterop).self,
      in: unconfiguredApp.container
    )

    let defaultResult = await resolvedDefault?.getToken(forcingRefresh: false)

    #expect(resolvedDefault != nil)
    #expect(AppCheck.appCheck(app: defaultApp) != nil)
    #expect(defaultResult?.token == "container-token")
    #expect(defaultResult?.error == nil)
    #expect(resolvedUnconfigured == nil)
    #expect(AppCheck.appCheck(app: unconfiguredApp) == nil)
  }
}
