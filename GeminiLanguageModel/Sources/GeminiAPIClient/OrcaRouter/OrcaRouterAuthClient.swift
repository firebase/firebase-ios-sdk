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

package import Foundation
import Synchronization

#if canImport(Darwin)
  import Foundation
#else
  import FoundationNetworking
#endif

// MARK: - Authorization

/// One PKCE authorization attempt.
///
/// The verifier is created here, held only here, and presented only at exchange. It never appears
/// in a URL, a log, an error, or a snapshot.
package struct OrcaRouterAuthorizationAttempt: Sendable {
  /// A value identifying this attempt, used to reject a response that belongs to an older one.
  package let identifier: UInt64

  /// The opaque `state` that must come back unchanged.
  package let state: String

  /// The S256 challenge sent to the consent screen.
  package let challenge: String

  /// The callback URL the caller asked the consent screen to deliver to.
  package let callbackURL: String

  /// The verifier. Never sent anywhere except the exchange endpoint.
  private let verifier: String

  /// Builds an attempt.
  ///
  /// - Parameters:
  ///   - identifier: The attempt identifier.
  ///   - callbackURL: The callback URL, or `oob` for the out-of-band flow.
  /// - Throws: `OrcaRouterPKCEError.randomnessUnavailable` if the generator cannot be read.
  package init(identifier: UInt64, callbackURL: String = OrcaRouterAuthClient.outOfBandCallback)
  throws {
    self.identifier = identifier
    self.callbackURL = callbackURL
    self.state = try OrcaRouterPKCE.makeState()
    let verifier = try OrcaRouterPKCE.makeVerifier()
    self.verifier = verifier
    self.challenge = OrcaRouterPKCE.challenge(forVerifier: verifier)
  }

  /// The verifier to present at exchange.
  package var codeVerifierForExchange: String { verifier }
}

// MARK: - Auth Client

/// Performs the OAuth 2.0 + PKCE authorization that issues an OrcaRouter API key.
///
/// This type implements Flow B (out-of-band code) and Flow A (loopback redirect). There is no
/// client secret anywhere in the flow, and no redirect URI to pre-register: PKCE binds the code to
/// this process because the verifier never leaves it.
package final class OrcaRouterAuthClient: Sendable {
  /// The literal callback value that selects the out-of-band flow.
  package static let outOfBandCallback = "oob"

  /// The application name shown on the consent screen.
  package let appName: String

  /// The origin authorization and exchange requests are sent to.
  package let authBaseURL: URL

  /// The response bounds applied to the exchange.
  package struct Limits: Sendable, Equatable {
    /// The request timeout.
    package var timeout: TimeInterval = 30
    /// The maximum number of response bytes read.
    package var maximumResponseBytes = 256 * 1024
  }

  private let sessionConfiguration: URLSessionConfiguration
  private let limits: Limits
  private let attemptCounter = Mutex<UInt64>(0)

  /// Creates an auth client.
  ///
  /// - Parameters:
  ///   - provider: The provider whose authentication origin and name to use.
  ///   - appName: The name shown on the consent screen.
  ///   - sessionConfiguration: The session configuration to use.
  ///   - limits: The response bounds.
  init(
    provider: OrcaRouterProvider,
    appName: String,
    sessionConfiguration: URLSessionConfiguration = .ephemeral,
    limits: Limits = Limits()
  ) {
    self.authBaseURL = provider.authBaseURL
    self.appName = appName
    self.sessionConfiguration = sessionConfiguration
    self.limits = limits
  }

  /// Starts a fresh authorization attempt.
  ///
  /// Every call draws a new verifier and a new `state`; nothing is reused between attempts.
  ///
  /// - Parameter callbackURL: Where the code should be delivered. The default selects the
  ///   out-of-band flow.
  /// - Returns: The attempt to authorize.
  /// - Throws: `OrcaRouterPKCEError.randomnessUnavailable` if the generator cannot be read.
  package func beginAttempt(
    callbackURL: String = OrcaRouterAuthClient.outOfBandCallback
  ) throws -> OrcaRouterAuthorizationAttempt {
    let identifier = attemptCounter.withLock { counter -> UInt64 in
      counter += 1
      return counter
    }
    return try OrcaRouterAuthorizationAttempt(
      identifier: identifier,
      callbackURL: callbackURL
    )
  }

  /// Builds the URL the user opens to authorize.
  ///
  /// The challenge is always S256, including for a redirect flow: a user of a redirect flow may
  /// still choose "show me a code" on the consent screen, which puts the code into human hands.
  ///
  /// - Parameter attempt: The attempt to authorize.
  /// - Returns: The authorize URL, on the authentication origin.
  package func authorizationURL(for attempt: OrcaRouterAuthorizationAttempt) throws -> URL {
    let url = try OrcaRouterOriginPolicy.makeURL(
      base: authBaseURL,
      path: OrcaRouterProvider.authorizePath
    )
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw URLError(.badURL)
    }
    components.queryItems = [
      URLQueryItem(name: "callback_url", value: attempt.callbackURL),
      URLQueryItem(name: "code_challenge", value: attempt.challenge),
      URLQueryItem(name: "code_challenge_method", value: OrcaRouterPKCE.challengeMethod),
      URLQueryItem(name: "state", value: attempt.state),
      URLQueryItem(name: "app_name", value: appName),
      URLQueryItem(name: "scope", value: OrcaRouterProvider.scope),
    ]
    guard let result = components.url else { throw URLError(.badURL) }
    return result
  }

  /// Exchanges an authorization code for an API key.
  ///
  /// - Parameters:
  ///   - code: The one-time code, either returned to a loopback listener or typed by the user.
  ///   - attempt: The attempt that produced the code.
  ///   - acquisition: How to label the resulting credential.
  /// - Returns: A credential carrying a durable `sk-orca-…` key. The key is not a refresh token and
  ///   there is no refresh grant to call later.
  /// - Throws: `OrcaRouterCredentialError` describing why the exchange failed.
  package func exchange(
    code: String,
    attempt: OrcaRouterAuthorizationAttempt,
    acquisition: OrcaRouterCredential.Acquisition = .account
  ) async throws -> OrcaRouterCredential {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw OrcaRouterCredentialError.malformedResponse }

    let request = try makeExchangeRequest(code: trimmed, attempt: attempt)
    let session = URLSession(configuration: sessionConfiguration)
    defer { session.finishTasksAndInvalidate() }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError where error.code == .timedOut {
      throw OrcaRouterCredentialError.authorizationExpired
    } catch {
      throw OrcaRouterCredentialError.malformedResponse
    }

    guard let http = response as? HTTPURLResponse else {
      throw OrcaRouterCredentialError.malformedResponse
    }
    guard data.count <= limits.maximumResponseBytes else {
      throw OrcaRouterCredentialError.malformedResponse
    }

    switch http.statusCode {
    case 200:
      break
    case 400:
      // The challenge method was unrecognised, or it differed from the one sent at authorize
      // time.
      throw OrcaRouterCredentialError.malformedResponse
    case 403:
      // Unknown, expired, already used, or the verifier did not match.
      throw OrcaRouterCredentialError.codeRejected
    case 429:
      throw OrcaRouterCredentialError.tooManyAuthorizations
    default:
      throw OrcaRouterCredentialError.authorizationRefused(statusCode: http.statusCode)
    }

    guard let payload = try? JSONDecoder().decode(OrcaRouterExchangeResponse.self, from: data),
      let key = payload.key, !key.isEmpty
    else {
      throw OrcaRouterCredentialError.malformedResponse
    }

    // Read the granted scope back. It is what was granted, not what was requested.
    return OrcaRouterCredential(
      apiKey: key,
      acquisition: acquisition,
      scope: payload.scope,
      accountIdentifier: payload.userID
    )
  }

  /// The granted scope, when it is narrower than what the caller needs.
  ///
  /// - Parameter credential: The credential returned by an exchange.
  /// - Returns: `true` when the origin reported a scope that does not cover this integration's
  ///   use. An absent scope is not treated as a downgrade.
  package static func hasScopeDowngrade(_ credential: OrcaRouterCredential) -> Bool {
    guard let scope = credential.scope else { return false }
    let granted = Set(
      scope.split(whereSeparator: { $0 == " " || $0 == "," }).map {
        $0.trimmingCharacters(in: .whitespaces).lowercased()
      }
    )
    if granted.isEmpty { return false }
    return !granted.contains(OrcaRouterProvider.scope)
  }

  /// Extracts the authorization code from a loopback callback.
  ///
  /// - Parameters:
  ///   - query: The callback query string.
  ///   - expectedState: The `state` that was sent.
  ///   - attempt: The attempt the callback should belong to.
  /// - Returns: The authorization code.
  /// - Throws: A `OrcaRouterCredentialError` describing why the callback was refused.
  package static func authorizationCode(
    fromCallbackQuery query: String,
    expectedState: String,
    attempt: OrcaRouterAuthorizationAttempt
  ) throws -> String {
    _ = attempt
    var urlComponents = URLComponents()
    urlComponents.query = query

    let items = urlComponents.queryItems ?? []
    func value(_ name: String) -> String? {
      items.first { $0.name == name }?.value
    }

    // Compare the state before anything else: it is the only thing standing between this client and
    // a code dropped on it by somebody else's page.
    guard let returnedState = value("state"),
      OrcaRouterPKCE.constantTimeEquals(returnedState, expectedState)
    else {
      throw OrcaRouterCredentialError.stateMismatch
    }

    if let error = value("error") {
      throw error == "access_denied"
        ? OrcaRouterCredentialError.authorizationDenied
        : OrcaRouterCredentialError.authorizationRefused(statusCode: 0)
    }

    guard let code = value("code"), !code.isEmpty else {
      throw OrcaRouterCredentialError.malformedResponse
    }
    return code
  }

  /// Builds the code-exchange request.
  ///
  /// The path is `/api/v1/auth/keys` on the authentication origin. It is never derived from the
  /// inference origin, which serves only `/v1`.
  func makeExchangeRequest(
    code: String,
    attempt: OrcaRouterAuthorizationAttempt
  ) throws -> URLRequest {
    let url = try OrcaRouterOriginPolicy.makeURL(
      base: authBaseURL,
      path: OrcaRouterProvider.exchangePath
    )
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = limits.timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let body = OrcaRouterExchangeRequest(
      code: code,
      codeVerifier: attempt.codeVerifierForExchange,
      codeChallengeMethod: OrcaRouterPKCE.challengeMethod
    )
    request.httpBody = try JSONEncoder().encode(body)
    return request
  }
}

// MARK: - Wire Types

/// The code-exchange request body.
package struct OrcaRouterExchangeRequest: Encodable, Sendable, Equatable {
  package let code: String
  package let codeVerifier: String
  package let codeChallengeMethod: String

  enum CodingKeys: String, CodingKey {
    case code
    case codeVerifier = "code_verifier"
    case codeChallengeMethod = "code_challenge_method"
  }
}

/// The code-exchange response body.
package struct OrcaRouterExchangeResponse: Decodable, Sendable {
  package let key: String?
  package let userID: String?
  package let scope: String?

  enum CodingKeys: String, CodingKey {
    case key
    case userID = "user_id"
    case scope
  }
}

// MARK: - Login Lifecycle

/// Owns the browser/authorization login lifecycle for one provider entry.
///
/// Only one authorization may be in flight at a time, and every asynchronous step confirms it still
/// belongs to the current generation before it changes credential or UI state. This is what stops a
/// late response from an earlier attempt appearing under a later one.
///
/// Every terminal path releases the busy state: success, denial, exchange failure, timeout, an
/// explicit cancel, a provider switch, and a page hide.
package final class OrcaRouterLoginSession: Sendable {
  /// What the caller should show while a login is in flight.
  package struct Status: Sendable, Equatable {
    /// Whether a login is currently in flight.
    package var isBusy: Bool
    /// The URL the user should open, once it is known.
    package var authorizationURL: URL?
    /// A short instruction, when one is useful.
    package var hint: String?
    /// The attempt currently in flight.
    package var attemptIdentifier: UInt64?

    /// An idle status.
    package static let idle = Status(
      isBusy: false,
      authorizationURL: nil,
      hint: nil,
      attemptIdentifier: nil
    )
  }

  private struct State: Sendable {
    var generation: UInt64 = 0
    var status: Status = OrcaRouterLoginSession.Status.idle
    var pending: OrcaRouterAuthorizationAttempt?
    var isCancelled: Bool = false
  }

  private let state = Mutex(State())
  private let presenter: any OrcaRouterAuthorizationPresenter
  private let client: OrcaRouterAuthClient

  /// Creates a login session.
  ///
  /// - Parameters:
  ///   - client: The auth client that performs the flow.
  ///   - presenter: The host adapter that shows the URL and collects the code.
  package init(
    client: OrcaRouterAuthClient,
    presenter: any OrcaRouterAuthorizationPresenter
  ) {
    self.client = client
    self.presenter = presenter
  }

  /// The current status.
  package var status: Status {
    state.withLock { $0.status }
  }

  /// The generation currently in flight, or the last one used.
  package var generation: UInt64 {
    state.withLock { $0.generation }
  }

  /// Runs one authorization to completion.
  ///
  /// - Returns: A credential carrying the issued key.
  /// - Throws: `OrcaRouterCredentialError.authorizationCancelled` when a cancel, a page hide, or a
  ///   newer attempt superseded this one; otherwise the flow's own error.
  package func start() async throws -> OrcaRouterCredential {
    let generation: UInt64
    let attempt: OrcaRouterAuthorizationAttempt
    do {
      attempt = try client.beginAttempt()
    } catch {
      throw error
    }

    generation = state.withLock { current in
      current.generation += 1
      current.isCancelled = false
      current.pending = attempt
      current.status = Status(
        isBusy: true,
        authorizationURL: nil,
        hint: "Waiting for authorization in your browser.",
        attemptIdentifier: attempt.identifier
      )
      return current.generation
    }

    let url = try client.authorizationURL(for: attempt)
    guard isCurrent(generation) else {
      throw OrcaRouterCredentialError.authorizationCancelled
    }
    state.withLock { current in
      guard current.generation == generation else { return }
      current.status.authorizationURL = url
    }

    do {
      try await presenter.present(url: url, appName: client.appName)

      let code = try await presenter.collectAuthorizationCode(attempt: attempt, authorizeURL: url)

      guard isCurrent(generation) else {
        throw OrcaRouterCredentialError.authorizationCancelled
      }

      let credential = try await client.exchange(code: code, attempt: attempt)
      guard isCurrent(generation) else {
        throw OrcaRouterCredentialError.authorizationCancelled
      }
      // Read the granted scope back and surface a narrower grant rather than assuming the wider one
      // was approved.
      let downgraded = OrcaRouterAuthClient.hasScopeDowngrade(credential)
      finish(generation, hint: downgraded ? "OrcaRouter granted a narrower scope than requested." : nil)
      return credential
    } catch {
      // A denial, a timeout, an explicit cancel, an exchange failure, and a superseding attempt all
      // land here, and every one of them must leave the session idle rather than busy. The clear is
      // generation-guarded, so an attempt that was superseded cannot clear a newer attempt's state.
      finish(generation, hint: nil)
      throw error
    }
  }

  /// Cancels the attempt in flight, if any.
  ///
  /// This is the path an explicit Cancel button, a provider switch, and a modal close all take. It
  /// releases both halves of the login: the UI state here, and the server-side work through the
  /// presenter, so a parked authorization cannot be left waiting.
  package func cancel() {
    let pending = state.withLock { current -> UInt64? in
      let identifier = current.pending?.identifier
      current.generation += 1
      current.isCancelled = true
      current.pending = nil
      current.status = OrcaRouterLoginSession.Status.idle
      return identifier
    }
    presenter.cancelServerSideWork(attemptIdentifier: pending, useKeepalive: false)
  }

  /// Handles a page hide.
  ///
  /// Browsers may put the page into the back-forward cache, where no `finally` block runs and
  /// nothing remounts. The busy flag and the hint are therefore cleared **synchronously, here**,
  /// rather than relying on the invalidated attempt's own cleanup, which is guarded and will
  /// correctly refuse to touch state.
  ///
  /// - Returns: The cancelled attempt identifier, so the caller can tell the server to stop.
  @discardableResult
  package func handlePageHide() -> UInt64? {
    let pending = state.withLock { current -> UInt64? in
      let identifier = current.pending?.identifier
      current.generation += 1
      current.isCancelled = true
      current.pending = nil
      current.status = OrcaRouterLoginSession.Status.idle
      return identifier
    }
    presenter.cancelServerSideWork(attemptIdentifier: pending, useKeepalive: true)
    return pending
  }

  /// Handles a component teardown.
  ///
  /// Unlike ``handlePageHide()`` this does not write any UI state, because there is no view left to
  /// update; it only stops the work.
  package func handleUnmount() {
    let pending = state.withLock { current -> UInt64? in
      let identifier = current.pending?.identifier
      current.generation += 1
      current.isCancelled = true
      current.pending = nil
      return identifier
    }
    presenter.cancelServerSideWork(attemptIdentifier: pending, useKeepalive: false)
  }

  /// Whether a generation still owns the login.
  ///
  /// - Parameter generation: The generation to test.
  package func isCurrent(_ generation: UInt64) -> Bool {
    state.withLock { $0.generation == generation && !$0.isCancelled }
  }

  /// Clears the busy state, but only for the generation that owns it.
  private func finish(_ generation: UInt64, hint: String?) {
    state.withLock { current in
      guard current.generation == generation else { return }
      current.pending = nil
      current.status = Status(
        isBusy: false,
        authorizationURL: nil,
        hint: hint,
        attemptIdentifier: nil
      )
    }
  }
}

// MARK: - PKCE Adapter

/// The authorization adapter: `Connect with OrcaRouter` yields a key.
///
/// This is the second adapter of ``OrcaRouterCredentialSource``. ``OrcaRouterAPIKeySource`` covers a
/// key the user already holds; this one covers a key an authorization issues. Both produce exactly
/// the same ``OrcaRouterCredential``, so neither inference nor model discovery ever branches on
/// which entry the user chose.
package struct OrcaRouterPKCECredentialSource: OrcaRouterCredentialSource {
  /// The login session that performs the browser or device authorization.
  package let session: OrcaRouterLoginSession

  /// Creates a PKCE credential source.
  ///
  /// - Parameter session: The login session to drive.
  package init(session: OrcaRouterLoginSession) {
    self.session = session
  }

  package func acquire() async throws -> OrcaRouterCredential {
    try await session.start()
  }
}

// MARK: - Authorization Presenter

/// The host-side half of an authorization: showing the URL and getting a code back.
///
/// A terminal host prints the URL and reads a line from standard input; a graphical host opens a
/// browser and reads the loopback callback. Keeping this behind a protocol is what lets the flow be
/// exercised end to end against a fake authorization server without a human approving anything.
package protocol OrcaRouterAuthorizationPresenter: Sendable {
  /// Shows the authorization URL to the user.
  ///
  /// - Parameters:
  ///   - url: The authorize URL, on the authentication origin.
  ///   - appName: The application name the consent screen will show.
  func present(url: URL, appName: String) async throws

  /// Obtains the authorization code.
  ///
  /// - Parameters:
  ///   - attempt: The attempt the code should belong to.
  ///   - authorizeURL: The URL that was presented.
  /// - Returns: The one-time code.
  /// - Throws: `OrcaRouterCredentialError.authorizationDenied`,
  ///   `.authorizationCancelled`, or `.authorizationExpired` to end the attempt.
  func collectAuthorizationCode(
    attempt: OrcaRouterAuthorizationAttempt,
    authorizeURL: URL
  ) async throws -> String

  /// Tells the host to stop any server-side work for an abandoned attempt.
  ///
  /// - Parameters:
  ///   - attemptIdentifier: The attempt to abandon, if one is known.
  ///   - useKeepalive: Whether the cancellation may be sent with a keepalive-capable request. This
  ///     is `true` on a page hide, where the page may be discarded, and `false` on an unmount.
  func cancelServerSideWork(attemptIdentifier: UInt64?, useKeepalive: Bool)
}
