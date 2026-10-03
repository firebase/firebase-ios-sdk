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
import FirebaseAuth
import FirebaseAuthInterop
import FirebaseCore
import FirebaseCoreExtension
import FirebaseCoreInternal
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Testing

// MARK: - Test Doubles

private final class MockAuthURLProtocol: URLProtocol {
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

extension URLRequest {
  fileprivate var bodyData: Data? {
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

private struct FakeAppCheckTokenResult: FIRAppCheckTokenResultInterop {
  let token: String
  let error: (any Error)?
}

private final class FakeAppCheckInterop: AppCheckInterop {
  let token: String

  init(token: String) {
    self.token = token
  }

  func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop {
    FakeAppCheckTokenResult(token: token, error: nil)
  }

  func getLimitedUseToken() async -> any FIRAppCheckTokenResultInterop {
    FakeAppCheckTokenResult(token: token, error: nil)
  }

  func tokenDidChangeNotificationName() -> String {
    "FIRAppCheckAppCheckTokenDidChangeNotification"
  }

  func notificationTokenKey() -> String {
    "FIRAppCheckTokenNotificationKey"
  }

  func notificationAppNameKey() -> String {
    "FIRAppCheckAppNameNotificationKey"
  }
}

// MARK: - Tests

@Suite("FirebaseAuth Portable Tests", .serialized)
struct FirebaseAuthPortableTests {
  init() {
    FirebaseApp.resetApps()
    FirebaseComponentContainer.removeAllRegistrations()
    MockAuthURLProtocol.reset()
  }

  private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockAuthURLProtocol.self]
    return URLSession(configuration: config)
  }

  private func makeValidOptions(apiKey: String = "test-api-key") -> FirebaseOptions {
    let options = FirebaseOptions(googleAppID: "1:123:ios:abc", gcmSenderID: "123")
    options.apiKey = apiKey
    options.projectID = "test-project"
    return options
  }

  @Test
  func signInWithEmailAndPasswordSuccess() async throws {
    struct CapturedSignInBody: Decodable, Sendable {
      let email: String
      let password: String
      let returnSecureToken: Bool
      let clientType: String
      let tenantId: String?
    }

    let endpoint =
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key"
    let capturedRequest = UnfairLock<URLRequest?>(nil)
    let capturedBody = UnfairLock<CapturedSignInBody?>(nil)

    MockAuthURLProtocol.setHandler(for: endpoint) { request in
      capturedRequest.withLock { $0 = request }
      if let data = request.bodyData,
         let decoded = try? JSONDecoder().decode(CapturedSignInBody.self, from: data) {
        capturedBody.withLock { $0 = decoded }
      }
      let responseJSON = #"""
      {
        "localId": "user-uid-123",
        "email": "user@example.com",
        "displayName": "Test User",
        "photoUrl": "https://example.com/photo.png",
        "idToken": "initial-id-token",
        "refreshToken": "initial-refresh-token",
        "expiresIn": "3600",
        "registered": true
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let app = FirebaseApp(instanceWithName: "AuthTestApp", options: makeValidOptions())
    let auth = Auth(app: app, session: makeMockSession())
    auth.languageCode = "en-US"
    auth.tenantID = "tenant-42"

    let result = try await auth.signIn(withEmail: "user@example.com", password: "secret-password")
    let request = try #require(capturedRequest.withLock { $0 })
    let body = try #require(capturedBody.withLock { $0 })

    #expect(result.user.uid == "user-uid-123")
    #expect(result.user.email == "user@example.com")
    #expect(result.user.displayName == "Test User")
    #expect(result.user.photoURL == URL(string: "https://example.com/photo.png"))
    #expect(result.user.isAnonymous == false)
    #expect(result.user.isEmailVerified == true)
    #expect(result.user.refreshToken == "initial-refresh-token")
    #expect(auth.currentUser?.uid == "user-uid-123")
    #expect(auth.getUserID() == "user-uid-123")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "X-Firebase-GMPID") == "1:123:ios:abc")
    #expect(request.value(forHTTPHeaderField: "X-Firebase-Locale") == "en-US")
    #expect(body.email == "user@example.com")
    #expect(body.password == "secret-password")
    #expect(body.returnSecureToken == true)
    #expect(body.clientType == "CLIENT_TYPE_IOS")
    #expect(body.tenantId == "tenant-42")
  }

  @Test
  func signInAnonymouslyAndReusesExistingAnonymousUser() async throws {
    struct CapturedSignUpBody: Decodable, Sendable {
      let returnSecureToken: Bool
      let clientType: String
    }

    let endpoint = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-api-key"
    let callCount = UnfairLock<Int>(0)
    let capturedBody = UnfairLock<CapturedSignUpBody?>(nil)

    MockAuthURLProtocol.setHandler(for: endpoint) { request in
      callCount.withLock { $0 += 1 }
      if let data = request.bodyData,
         let decoded = try? JSONDecoder().decode(CapturedSignUpBody.self, from: data) {
        capturedBody.withLock { $0 = decoded }
      }
      let responseJSON = #"""
      {
        "localId": "anon-uid-999",
        "idToken": "anon-id-token",
        "refreshToken": "anon-refresh-token",
        "expiresIn": "3600"
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let app = FirebaseApp(instanceWithName: "AnonTestApp", options: makeValidOptions())
    let auth = Auth(app: app, session: makeMockSession())

    let firstResult = try await auth.signInAnonymously()
    let secondResult = try await auth.signInAnonymously()
    let body = try #require(capturedBody.withLock { $0 })

    #expect(firstResult.user.uid == "anon-uid-999")
    #expect(firstResult.user.isAnonymous == true)
    #expect(secondResult.user.uid == "anon-uid-999")
    #expect(callCount.withLock { $0 } == 1)
    #expect(body.returnSecureToken == true)
    #expect(body.clientType == "CLIENT_TYPE_IOS")
  }

  @Test
  func getTokenCachingRefreshAndSignOut() async throws {
    struct CapturedRefreshBody: Decodable, Sendable {
      let grantType: String
      let refreshToken: String
    }

    let signInEndpoint =
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key"
    let refreshEndpoint = "https://securetoken.googleapis.com/v1/token?key=test-api-key"
    let refreshCallCount = UnfairLock<Int>(0)
    let capturedRefreshBody = UnfairLock<CapturedRefreshBody?>(nil)

    MockAuthURLProtocol.setHandler(for: signInEndpoint) { request in
      let responseJSON = #"""
      {
        "localId": "user-1",
        "email": "user1@example.com",
        "idToken": "cached-id-token-1",
        "refreshToken": "refresh-token-1",
        "expiresIn": "3600"
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    MockAuthURLProtocol.setHandler(for: refreshEndpoint) { request in
      refreshCallCount.withLock { $0 += 1 }
      if let data = request.bodyData,
         let decoded = try? JSONDecoder().decode(CapturedRefreshBody.self, from: data) {
        capturedRefreshBody.withLock { $0 = decoded }
      }
      let responseJSON = #"""
      {
        "id_token": "refreshed-id-token-2",
        "refresh_token": "refresh-token-2",
        "expires_in": "3600"
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let app = FirebaseApp(instanceWithName: "RefreshApp", options: makeValidOptions())
    let auth = Auth(app: app, session: makeMockSession())

    let signedOutToken = try await auth.getToken(forcingRefresh: false)
    #expect(signedOutToken == nil)

    _ = try await auth.signIn(withEmail: "user1@example.com", password: "password")

    let cachedToken1 = try await auth.getToken(forcingRefresh: false)
    let cachedToken2 = try await auth.currentUser?.getIDToken()
    #expect(cachedToken1 == "cached-id-token-1")
    #expect(cachedToken2 == "cached-id-token-1")
    #expect(refreshCallCount.withLock { $0 } == 0)

    let forcedToken = try await auth.getToken(forcingRefresh: true)
    let afterForcedToken = try await auth.getToken(forcingRefresh: false)
    let refreshBody = try #require(capturedRefreshBody.withLock { $0 })

    #expect(forcedToken == "refreshed-id-token-2")
    #expect(afterForcedToken == "refreshed-id-token-2")
    #expect(auth.currentUser?.refreshToken == "refresh-token-2")
    #expect(refreshCallCount.withLock { $0 } == 1)
    #expect(refreshBody.grantType == "refresh_token")
    #expect(refreshBody.refreshToken == "refresh-token-1")

    try auth.signOut()

    #expect(auth.currentUser == nil)
    #expect(auth.getUserID() == nil)
    #expect(try await auth.getToken(forcingRefresh: false) == nil)
  }

  @Test
  func nearExpirationTokenAutomaticallyRefreshes() async throws {
    let signInEndpoint =
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key"
    let refreshEndpoint = "https://securetoken.googleapis.com/v1/token?key=test-api-key"
    let refreshCallCount = UnfairLock<Int>(0)

    MockAuthURLProtocol.setHandler(for: signInEndpoint) { request in
      // expiresIn = 60s is within the 300s expiration buffer.
      let responseJSON = #"""
      {
        "localId": "user-expiring",
        "idToken": "short-lived-token",
        "refreshToken": "refresh-token-exp",
        "expiresIn": "60"
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    MockAuthURLProtocol.setHandler(for: refreshEndpoint) { request in
      refreshCallCount.withLock { $0 += 1 }
      let responseJSON = #"""
      {
        "id_token": "auto-refreshed-token",
        "refresh_token": "refresh-token-exp-2",
        "expires_in": "3600"
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let app = FirebaseApp(instanceWithName: "ExpiringApp", options: makeValidOptions())
    let auth = Auth(app: app, session: makeMockSession())

    _ = try await auth.signIn(withEmail: "exp@example.com", password: "password")
    let token = try await auth.getToken(forcingRefresh: false)

    #expect(token == "auto-refreshed-token")
    #expect(refreshCallCount.withLock { $0 } == 1)
  }

  @Test
  func serverAndNetworkErrorMapping() async {
    let endpoint =
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key"
    let app = FirebaseApp(instanceWithName: "ErrorApp", options: makeValidOptions())
    let auth = Auth(app: app, session: makeMockSession())

    MockAuthURLProtocol.setHandler(for: endpoint) { request in
      let errorJSON = #"""
      {
        "error": {
          "code": 400,
          "message": "INVALID_PASSWORD : The password is invalid."
        }
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 400,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(errorJSON.utf8))
    }

    do {
      _ = try await auth.signIn(withEmail: "user@example.com", password: "wrong")
      Issue.record("Expected wrongPassword error")
    } catch {
      let nsError = error as NSError
      #expect(nsError.domain == AuthErrorDomain)
      #expect(nsError.code == AuthErrorCode.wrongPassword.rawValue)
      #expect(nsError.userInfo[AuthErrorUserInfoNameKey] as? String == "INVALID_PASSWORD")
    }

    MockAuthURLProtocol.setHandler(for: endpoint) { _ in
      throw URLError(.notConnectedToInternet)
    }

    do {
      _ = try await auth.signIn(withEmail: "user@example.com", password: "wrong")
      Issue.record("Expected networkError")
    } catch {
      let nsError = error as NSError
      #expect(nsError.domain == AuthErrorDomain)
      #expect(nsError.code == AuthErrorCode.networkError.rawValue)
    }
  }

  @Test
  func containerRegistrationAndAppCheckHeaderAttachment() async throws {
    let endpoint = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-api-key"
    let capturedAppCheckHeader = UnfairLock<String?>(nil)

    MockAuthURLProtocol.setHandler(for: endpoint) { request in
      capturedAppCheckHeader.withLock {
        $0 = request.value(forHTTPHeaderField: "X-Firebase-AppCheck")
      }
      let responseJSON = #"""
      {
        "localId": "uid-with-appcheck",
        "idToken": "token-with-appcheck",
        "refreshToken": "refresh-with-appcheck",
        "expiresIn": "3600"
      }
      """#
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    FirebaseApp.configure(options: makeValidOptions())
    let defaultApp = try #require(FirebaseApp.app())

    let authFromEntryPoint = Auth.auth()
    let resolvedInterop = ComponentType<any AuthInterop>.instance(
      for: (any AuthInterop).self,
      in: defaultApp.container
    )

    let customApp = FirebaseApp(instanceWithName: "CustomAuthApp", options: makeValidOptions())
    customApp.container.register(
      instance: FakeAppCheckInterop(token: "fac-header-token"),
      for: (any AppCheckInterop).self
    )
    let customAuth = Auth(app: customApp, session: makeMockSession())
    _ = try await customAuth.signInAnonymously()

    #expect(resolvedInterop as? Auth === authFromEntryPoint)
    #expect(authFromEntryPoint.app == defaultApp)
    #expect(capturedAppCheckHeader.withLock { $0 } == "fac-header-token")
  }

  @Test
  func orphanedUserAndCurrentUserRefreshIsolation() async throws {
    struct SignInBody: Decodable {
      let email: String
    }

    struct RefreshBody: Decodable {
      let refreshToken: String
    }

    let signInEndpoint =
      "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test-api-key"
    let refreshEndpoint = "https://securetoken.googleapis.com/v1/token?key=test-api-key"

    MockAuthURLProtocol.setHandler(for: signInEndpoint) { request in
      let data = request.bodyData ?? Data()
      let body = try JSONDecoder().decode(SignInBody.self, from: data)
      let isUserA = body.email == "userA@example.com"
      let responseJSON = """
      {
        "localId": "\(isUserA ? "uid-a" : "uid-b")",
        "email": "\(body.email)",
        "idToken": "\(isUserA ? "id-token-a-1" : "id-token-b-1")",
        "refreshToken": "\(isUserA ? "refresh-a" : "refresh-b")",
        "expiresIn": "60"
      }
      """
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    MockAuthURLProtocol.setHandler(for: refreshEndpoint) { request in
      let data = request.bodyData ?? Data()
      let body = try JSONDecoder().decode(RefreshBody.self, from: data)
      let isUserA = body.refreshToken == "refresh-a"
      let responseJSON = """
      {
        "id_token": "\(isUserA ? "id-token-a-refreshed" : "id-token-b-refreshed")",
        "refresh_token": "\(body.refreshToken)",
        "expires_in": "3600"
      }
      """
      let httpResponse = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (httpResponse, Data(responseJSON.utf8))
    }

    let app = FirebaseApp(instanceWithName: "IsolationApp", options: makeValidOptions())
    let auth = Auth(app: app, session: makeMockSession())

    let orphanedUser = try await auth.signIn(withEmail: "userA@example.com", password: "pw").user
    let activeUser = try await auth.signIn(withEmail: "userB@example.com", password: "pw").user

    async let orphanedRefresh = orphanedUser.getIDToken()
    async let activeRefresh = activeUser.getIDToken()
    let (orphanedToken, activeToken) = try await (orphanedRefresh, activeRefresh)

    #expect(orphanedToken == "id-token-a-refreshed")
    #expect(activeToken == "id-token-b-refreshed")
    #expect(try await auth.getToken(forcingRefresh: false) == "id-token-b-refreshed")
  }
}
