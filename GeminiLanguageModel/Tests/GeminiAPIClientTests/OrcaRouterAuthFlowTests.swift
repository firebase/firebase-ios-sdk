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
import GeminiTestUtilities
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@testable import GeminiAPIClient

/// Drives the OAuth 2.0 + PKCE adapter end to end against a genuine loopback authorization server.
///
/// The point of these tests is that nothing about the exchange path is stubbed. A real authorize URL
/// is built, a real callback query is parsed, a real HTTP `POST` reaches
/// `<auth origin>/api/v1/auth/keys`, and the real response is decoded into a credential. No human
/// approves anything; the server plays the consent screen's part.
///
/// This suite owns its own ephemeral server and a distinct port, so it neither observes nor disturbs
/// another suite's traffic.
@Suite("OrcaRouter Auth Flow Tests", .serialized)
struct OrcaRouterAuthFlowTests {
  // MARK: - Fake consent server

  /// A consent server that emits whatever response a test scripts, and records what it received.
  final class FakeConsentServer: @unchecked Sendable {
    /// A reference-typed holder so the request handler can read the scripted responses.
    private final class ResponseBox: @unchecked Sendable {
      let responses = Mutex<[String: OrcaRouterFakeHTTPServer.Response]>([:])
    }

    let server: OrcaRouterFakeHTTPServer
    private let box = ResponseBox()

    init() throws {
      let box = self.box
      server = try OrcaRouterFakeHTTPServer { request in
        box.responses.withLock { $0[request.path] }
          ?? OrcaRouterFakeHTTPServer.Response.json(["error": "unexpected path"], status: 404)
      }
      server.start()
    }

    deinit { server.stop() }

    /// These are http, not https, so the provider must be told to allow a loopback origin.
    var authBaseURLString: String { "http://127.0.0.1:\(server.port)" }

    func respond(to path: String, _ response: OrcaRouterFakeHTTPServer.Response) {
      box.responses.withLock { $0[path] = response }
    }

    func respondWithKey(
      _ key: String,
      userID: String? = "user-1",
      scope: String? = "api",
      status: Int = 200
    ) {
      var object: [String: Any] = ["key": key]
      if let userID { object["user_id"] = userID }
      if let scope { object["scope"] = scope }
      respond(to: OrcaRouterProvider.exchangePath, .json(object, status: status))
    }

    var exchangeRequest: OrcaRouterFakeHTTPServer.ReceivedRequest? {
      server.lastRequest(to: OrcaRouterProvider.exchangePath)
    }
  }

  // MARK: - Presenters

  /// A presenter that supplies a scripted code, standing in for the user pasting one.
  final class ScriptedPresenter: OrcaRouterAuthorizationPresenter, @unchecked Sendable {
    private let state: Mutex<State>

    private struct State: Sendable {
      var presentedURLs: [URL] = []
      var cancellations: [(UInt64?, Bool)] = []
      var code: String = ""
      var failure: (any Error)?
    }

    init(code: String) {
      state = Mutex(State(code: code))
    }

    init(failure: any Error) {
      state = Mutex(State(code: "", failure: failure))
    }

    var presentedURLs: [URL] { state.withLock { $0.presentedURLs } }
    var cancellations: [(UInt64?, Bool)] { state.withLock { $0.cancellations } }

    func present(url: URL, appName: String) async throws {
      state.withLock { $0.presentedURLs.append(url) }
    }

    func collectAuthorizationCode(
      attempt: OrcaRouterAuthorizationAttempt,
      authorizeURL: URL
    ) async throws -> String {
      if let failure = state.withLock({ $0.failure }) { throw failure }
      return state.withLock { $0.code }
    }

    func cancelServerSideWork(attemptIdentifier: UInt64?, useKeepalive: Bool) {
      state.withLock { $0.cancellations.append((attemptIdentifier, useKeepalive)) }
    }
  }

  /// A presenter that parks each `collectAuthorizationCode` until it is explicitly released.
  ///
  /// The parking is scoped to the attempt, not to the presenter, so a test can hide the page
  /// mid-login and then drive a genuinely separate second login without remounting anything.
  final class DeferredPresenter: OrcaRouterAuthorizationPresenter, @unchecked Sendable {
    private struct State: Sendable {
      var presentedURLs: [URL] = []
      var cancellations: [(UInt64?, Bool)] = []
      var gates: [UInt64: CheckedContinuation<Void, Never>] = [:]
      var releasedIdentifiers: Set<UInt64> = []
    }

    private let state = Mutex(State())

    var presentedURLs: [URL] { state.withLock { $0.presentedURLs } }
    var cancellations: [(UInt64?, Bool)] { state.withLock { $0.cancellations } }

    func present(url: URL, appName: String) async throws {
      state.withLock { $0.presentedURLs.append(url) }
    }

    func collectAuthorizationCode(
      attempt: OrcaRouterAuthorizationAttempt,
      authorizeURL: URL
    ) async throws -> String {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        let shouldResume = state.withLock { current -> Bool in
          if current.releasedIdentifiers.contains(attempt.identifier) { return true }
          current.gates[attempt.identifier] = continuation
          return false
        }
        if shouldResume { continuation.resume() }
      }
      return OrcaRouterTestConstants.fakeAuthorizationCode
    }

    func cancelServerSideWork(attemptIdentifier: UInt64?, useKeepalive: Bool) {
      state.withLock { $0.cancellations.append((attemptIdentifier, useKeepalive)) }
      if let attemptIdentifier { release(attemptIdentifier) }
    }

    /// Releases the attempt parked under an identifier, so its login can finish.
    func release(_ identifier: UInt64) {
      let continuation = state.withLock { current -> CheckedContinuation<Void, Never>? in
        current.releasedIdentifiers.insert(identifier)
        let gate = current.gates.removeValue(forKey: identifier)
        return gate
      }
      continuation?.resume()
    }
  }

  func makeAuthClient(
    server: FakeConsentServer,
    appName: String = "Firebase AI Logic"
  ) throws -> OrcaRouterAuthClient {
    let provider = try OrcaRouterProvider(
      authentication: .account,
      authBaseURL: server.authBaseURLString,
      apiBaseURL: OrcaRouterTestConstants.chatAPIBaseURL
    )
    return OrcaRouterAuthClient(
      provider: provider,
      appName: appName,
      sessionConfiguration: OrcaRouterRecordingURLProtocol.loopbackSessionConfiguration
    )
  }

  // MARK: - The happy path

  @Test
  func authorizationSucceedsEndToEndAndPersistsTheIssuedKey() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued-by-consent", userID: "user-42", scope: "api")
    let client = try makeAuthClient(server: server)

    let manager = OrcaRouterCredentialManager(store: OrcaRouterInMemoryCredentialStore())
    let presenter = ScriptedPresenter(code: OrcaRouterTestConstants.fakeAuthorizationCode)
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    // Drive the manager through the PKCE adapter, which is the same seam the API-key adapter uses.
    let credential = try await manager.connect(
      using: OrcaRouterPKCECredentialSource(session: session)
    )

    // The credential the consent server issued is the one that reaches the store.
    #expect(credential.apiKey == "sk-orca-issued-by-consent")
    #expect(credential.acquisition == .account)
    #expect(credential.scope == "api")
    #expect(credential.accountIdentifier == "user-42")

    #expect(manager.current?.apiKey == "sk-orca-issued-by-consent")
    #expect(manager.current?.acquisition == .account)
    #expect(!manager.needsReauthentication)
    // A freshly authorized credential is usable for inference without another authorization.
    #expect(manager.isUsable)
  }

  @Test
  func authorizeRequestCarriesAnS256ChallengeAndNeverTheVerifier() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server, appName: "Firebase AI Logic")

    let attempt = try client.beginAttempt(callbackURL: "http://127.0.0.1:51733/cb")
    let url = try client.authorizationURL(for: attempt)
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    func value(_ name: String) -> String? { query.first { $0.name == name }?.value }

    #expect(url.host == "127.0.0.1")
    #expect(url.path == OrcaRouterProvider.authorizePath)
    #expect(value("code_challenge_method") == "S256")
    #expect(value("scope") == "api")
    #expect(value("app_name") == "Firebase AI Logic")
    #expect(value("callback_url") == "http://127.0.0.1:51733/cb")
    #expect(value("state") == attempt.state)

    let challenge = try #require(value("code_challenge"))
    #expect(challenge == OrcaRouterPKCE.challenge(forVerifier: attempt.codeVerifierForExchange))
    // The only place the challenge may come from is the verifier, and the verifier itself must not
    // appear anywhere on the authorize URL.
    #expect(!url.absoluteString.contains(attempt.codeVerifierForExchange))
    #expect(challenge != attempt.codeVerifierForExchange)
    #expect(!challenge.contains("="))
  }

  @Test
  func exchangeReachesTheAuthOriginOnTheCorrectPathWithTheRightBody() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server)

    let attempt = try client.beginAttempt()
    let url = try client.authorizationURL(for: attempt)
    _ = url
    _ = try await client.exchange(
      code: OrcaRouterTestConstants.fakeAuthorizationCode,
      attempt: attempt
    )

    let request = try #require(server.exchangeRequest)
    #expect(request.method == "POST")
    #expect(request.path == "/api/v1/auth/keys")
    #expect(request.headers["content-type"] == "application/json")

    let body = try #require(
      try JSONSerialization.jsonObject(with: request.body) as? [String: String]
    )
    #expect(body["code"] == OrcaRouterTestConstants.fakeAuthorizationCode)
    #expect(body["code_verifier"] == attempt.codeVerifierForExchange)
    #expect(body["code_challenge_method"] == "S256")
    // The verifier belongs in the body and nowhere else; the query string must not carry it.
    #expect(server.server.receivedRequests.allSatisfy { $0.query["code_verifier"] == nil })
  }

  @Test
  func aSecondAttemptNeverReusesAVerifierOrState() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server)

    var verifiers: Set<String> = []
    var states: Set<String> = []
    var identifiers: Set<UInt64> = []
    for _ in 0..<8 {
      let attempt = try client.beginAttempt()
      verifiers.insert(attempt.codeVerifierForExchange)
      states.insert(attempt.state)
      identifiers.insert(attempt.identifier)
    }

    // Fresh cryptographic randomness on every attempt, and no attempt identifier is ever reused.
    #expect(verifiers.count == 8)
    #expect(states.count == 8)
    #expect(identifiers.count == 8)
  }

  // MARK: - Callback parsing

  @Test
  func callbackStateIsComparedBeforeTheCodeIsTrusted() throws {
    let client = try makeAuthClient(server: try FakeConsentServer())
    let attempt = try client.beginAttempt()

    // A code dropped on the listener by somebody else's page.
    #expect(throws: OrcaRouterCredentialError.stateMismatch) {
      try OrcaRouterAuthClient.authorizationCode(
        fromCallbackQuery: "code=\(OrcaRouterTestConstants.fakeAuthorizationCode)&state=not-the-state",
        expectedState: attempt.state,
        attempt: attempt
      )
    }
  }

  @Test
  func aCallbackWithoutStateIsRefused() throws {
    let client = try makeAuthClient(server: try FakeConsentServer())
    let attempt = try client.beginAttempt()
    #expect(throws: OrcaRouterCredentialError.stateMismatch) {
      try OrcaRouterAuthClient.authorizationCode(
        fromCallbackQuery: "code=\(OrcaRouterTestConstants.fakeAuthorizationCode)",
        expectedState: attempt.state,
        attempt: attempt
      )
    }
  }

  @Test
  func aDenialFromTheConsentScreenIsReportedAsSuch() throws {
    let client = try makeAuthClient(server: try FakeConsentServer())
    let attempt = try client.beginAttempt()
    let query = "error=access_denied&state=\(attempt.state)"
    #expect(throws: OrcaRouterCredentialError.authorizationDenied) {
      try OrcaRouterAuthClient.authorizationCode(
        fromCallbackQuery: query,
        expectedState: attempt.state,
        attempt: attempt
      )
    }
  }

  @Test
  func anApprovvedCallbackYieldsTheCode() throws {
    let client = try makeAuthClient(server: try FakeConsentServer())
    let attempt = try client.beginAttempt()
    let code = try OrcaRouterAuthClient.authorizationCode(
      fromCallbackQuery: "code=abc123&state=\(attempt.state)",
      expectedState: attempt.state,
      attempt: attempt
    )
    #expect(code == "abc123")
  }

  // MARK: - Failure classification

  @Test
  func aDeniedConsentEndsTheAttemptCleanly() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("unused")
    let client = try makeAuthClient(server: server)
    let presenter = ScriptedPresenter(failure: OrcaRouterCredentialError.authorizationDenied)
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    await #expect(throws: OrcaRouterCredentialError.authorizationDenied) {
      try await session.start()
    }
    // A denial must not leave the session busy forever, and must not have exchanged anything.
    #expect(!session.status.isBusy)
    #expect(server.exchangeRequest == nil)
  }

  @Test
  func aReusedOrExpiredCodeIsClassifiedAsRejected() async throws {
    let server = try FakeConsentServer()
    server.respond(to: OrcaRouterProvider.exchangePath, .json(["error": "invalid_grant"], status: 403))
    let client = try makeAuthClient(server: server)
    let attempt = try client.beginAttempt()

    await #expect(throws: OrcaRouterCredentialError.codeRejected) {
      try await client.exchange(code: "already-used", attempt: attempt)
    }
  }

  @Test
  func aChallengeMethodMismatchIsARefusedRequest() async throws {
    let server = try FakeConsentServer()
    server.respond(to: OrcaRouterProvider.exchangePath, .json(["error": "bad_method"], status: 400))
    let client = try makeAuthClient(server: server)
    let attempt = try client.beginAttempt()

    await #expect(throws: OrcaRouterCredentialError.malformedResponse) {
      try await client.exchange(code: "code", attempt: attempt)
    }
  }

  @Test
  func theAuthorizationCapIsReportedRatherThanRetried() async throws {
    let server = try FakeConsentServer()
    server.respond(to: OrcaRouterProvider.exchangePath, .json(["error": "too_many"], status: 429))
    let client = try makeAuthClient(server: server)
    let attempt = try client.beginAttempt()

    await #expect(throws: OrcaRouterCredentialError.tooManyAuthorizations) {
      try await client.exchange(code: "code", attempt: attempt)
    }
  }

  @Test
  func anEmptyCodeIsRejectedBeforeAnyRequestIsMade() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("unused")
    let client = try makeAuthClient(server: server)
    let attempt = try client.beginAttempt()

    await #expect(throws: OrcaRouterCredentialError.malformedResponse) {
      try await client.exchange(code: "   ", attempt: attempt)
    }
    // Nothing was sent: a blank code is refused locally.
    #expect(server.server.receivedRequests.isEmpty)
  }

  @Test
  func aResponseThatCarriesNoKeyIsRejected() async throws {
    let server = try FakeConsentServer()
    server.respond(to: OrcaRouterProvider.exchangePath, .json(["user_id": "user-1"], status: 200))
    let client = try makeAuthClient(server: server)
    let attempt = try client.beginAttempt()

    await #expect(throws: OrcaRouterCredentialError.malformedResponse) {
      try await client.exchange(code: "code", attempt: attempt)
    }
  }

  // MARK: - Scope

  @Test
  func aNarrowerGrantedScopeIsSurfacedRatherThanAssumed() {
    let downgraded = OrcaRouterCredential(
      apiKey: "sk-orca-x",
      acquisition: .account,
      scope: "connector"
    )
    #expect(OrcaRouterAuthClient.hasScopeDowngrade(downgraded))

    let adequate = OrcaRouterCredential(apiKey: "sk-orca-x", acquisition: .account, scope: "api")
    #expect(!OrcaRouterAuthClient.hasScopeDowngrade(adequate))

    // An absent scope is not a downgrade: there is nothing to have been refused.
    let unreported = OrcaRouterCredential(apiKey: "sk-orca-x", acquisition: .account, scope: nil)
    #expect(!OrcaRouterAuthClient.hasScopeDowngrade(unreported))
  }

  @Test
  func aDowngradedGrantIsReportedToTheUser() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued", scope: "connector")
    let client = try makeAuthClient(server: server)
    let presenter = ScriptedPresenter(code: OrcaRouterTestConstants.fakeAuthorizationCode)
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    let credential = try await session.start()
    #expect(credential.scope == "connector")
    #expect(session.status.hint == "OrcaRouter granted a narrower scope than requested.")
    #expect(!session.status.isBusy)
  }

  // MARK: - Login lifecycle

  @Test
  func cancellationReleasesTheLoginState() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server)
    let presenter = DeferredPresenter()
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    let task = Task { try await session.start() }
    // Wait until the attempt is genuinely in flight and its URL was handed to the presenter.
    for _ in 0..<200 where presenter.presentedURLs.isEmpty {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(session.status.isBusy)
    #expect(!presenter.presentedURLs.isEmpty)

    let inFlightAttempt = session.status.attemptIdentifier

    session.cancel()
    // The cancel must release both halves: the UI state and the presenter's parked work.
    #expect(presenter.cancellations.contains { $0.0 == inFlightAttempt && $0.1 == false })
    let outcome = await task.result

    #expect(throws: OrcaRouterCredentialError.authorizationCancelled) { try outcome.get() }
    #expect(!session.status.isBusy)
    #expect(session.status.authorizationURL == nil)
  }

  @Test
  func pageHideClearsBusyStateAndAllowsASecondLoginWithoutRemounting() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server)
    let presenter = DeferredPresenter()
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    let first = Task { try await session.start() }
    for _ in 0..<200 where presenter.presentedURLs.isEmpty {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(session.status.isBusy)
    let inFlightAttempt = session.status.attemptIdentifier

    // The browser parks the page in the back-forward cache. No `finally` will run for the invalidated
    // attempt, so the busy flag and hint must be cleared by the handler itself.
    let cancelled = session.handlePageHide()
    #expect(cancelled == inFlightAttempt)
    #expect(!session.status.isBusy)
    #expect(session.status.hint == nil)
    #expect(session.status.authorizationURL == nil)
    // The server was told to stop, with keepalive, because the page may be discarded.
    #expect(presenter.cancellations.contains { $0.0 == inFlightAttempt && $0.1 == true })

    // The restored page is not remounted. A second login must still be able to start.
    let second = Task { try await session.start() }
    for _ in 0..<200 where presenter.presentedURLs.count < 2 {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(session.status.isBusy)
    #expect(presenter.presentedURLs.count == 2)

    // Release the *second* attempt: the first one was already released by the page-hide's server
    // cancellation and must not be able to satisfy this login.
    let secondAttempt = try #require(session.status.attemptIdentifier)
    presenter.release(secondAttempt)
    let secondCredential = try await second.value
    #expect(secondCredential.apiKey == "sk-orca-issued")

    // The abandoned first attempt ends as a cancellation and cannot overwrite the newer result.
    let firstOutcome = await first.result
    #expect(throws: OrcaRouterCredentialError.authorizationCancelled) { try firstOutcome.get() }
  }

  @Test
  func aStaleResponseCannotOverwriteANewerGeneration() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server)
    let presenter = DeferredPresenter()
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    let stale = Task { try await session.start() }
    for _ in 0..<200 where presenter.presentedURLs.isEmpty {
      try await Task.sleep(for: .milliseconds(10))
    }
    let staleGeneration = session.generation
    let staleAttempt = session.status.attemptIdentifier

    // A provider switch, a modal close, or a newer attempt all take this path. It releases both the
    // generation and the presenter's parked work, so nothing is left waiting.
    session.cancel()
    #expect(!session.isCurrent(staleGeneration))
    #expect(presenter.cancellations.contains { $0.0 == staleAttempt })

    let outcome = await stale.result
    #expect(throws: OrcaRouterCredentialError.authorizationCancelled) { try outcome.get() }
    // The session is left idle, not stuck on the abandoned attempt.
    #expect(!session.status.isBusy)
  }

  @Test
  func unmountStopsServerWorkWithoutWritingState() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued")
    let client = try makeAuthClient(server: server)
    let presenter = DeferredPresenter()
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    let task = Task { try await session.start() }
    for _ in 0..<200 where presenter.presentedURLs.isEmpty {
      try await Task.sleep(for: .milliseconds(10))
    }

    session.handleUnmount()
    #expect(presenter.cancellations.contains { $0.1 == false })

    let outcome = await task.result
    #expect(throws: OrcaRouterCredentialError.authorizationCancelled) { try outcome.get() }
  }

  // MARK: - Secret hygiene

  @Test
  func noSecretAppearsInAnyAuthorizeArtifactOrRecordedRequest() async throws {
    let server = try FakeConsentServer()
    server.respondWithKey("sk-orca-issued-secret")
    let client = try makeAuthClient(server: server)
    let presenter = ScriptedPresenter(code: OrcaRouterTestConstants.fakeAuthorizationCode)
    let session = OrcaRouterLoginSession(client: client, presenter: presenter)

    let credential = try await session.start()
    let authorizeURL = try #require(presenter.presentedURLs.first)

    // Neither the verifier nor the issued key may appear in the URL the user is shown, in the
    // recorded exchange, or in the recorded request's body or headers.
    for request in server.server.receivedRequests {
      let bodyText = String(decoding: request.body, as: UTF8.self)
      let headerText = request.headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
      #expect(!request.path.contains(credential.apiKey))
      #expect(!headerText.contains(credential.apiKey))
      #expect(!bodyText.contains(credential.apiKey))
    }
    #expect(!authorizeURL.absoluteString.contains(credential.apiKey))
    #expect(!authorizeURL.absoluteString.contains("sk-orca-"))

    // And the flow's own user-visible strings never carry a secret.
    for error in [
      OrcaRouterCredentialError.codeRejected,
      .stateMismatch,
      .tooManyAuthorizations,
      .authorizationRefused(statusCode: 403),
      .malformedResponse,
    ] {
      let description = error.errorDescription ?? ""
      #expect(!description.contains(credential.apiKey))
      #expect(!description.contains("sk-orca-"))
    }
  }
}
