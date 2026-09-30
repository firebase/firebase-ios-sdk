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
import Synchronization

// MARK: - Credential

/// A usable OrcaRouter credential, however it was obtained.
///
/// Both authentication entries converge on this one value: an `sk-orca-…` API key belonging to the
/// user, billed to their account and revocable by them. Nothing downstream of this type needs to
/// know which entry produced it.
package struct OrcaRouterCredential: Sendable, Equatable {
  /// How the credential was obtained.
  package enum Acquisition: String, Sendable, Equatable, Codable {
    /// The user supplied an existing key.
    case apiKey
    /// An authorization exchange issued the key.
    case account
  }

  /// The `sk-orca-…` API key.
  ///
  /// - Warning: Never log, print, persist outside the credential store, or place this value in a
  ///   URL, error message, or telemetry payload. Use ``maskedKey`` for anything user-visible.
  package let apiKey: String

  /// How this credential was obtained.
  package let acquisition: Acquisition

  /// The scope the authorization actually granted, when the credential came from an exchange.
  ///
  /// This is what was **granted**, not what was requested. A `nil` value means the origin did not
  /// report a scope.
  package let scope: String?

  /// An opaque identifier for the account the credential belongs to, when known.
  package let accountIdentifier: String?

  /// The credential generation that produced this value.
  ///
  /// Generations increase monotonically. A late failure must only be able to invalidate the exact
  /// generation that made the rejected request, never a credential issued afterwards.
  package let generation: UInt64

  /// Creates a credential value.
  package init(
    apiKey: String,
    acquisition: Acquisition,
    scope: String? = nil,
    accountIdentifier: String? = nil,
    generation: UInt64 = 0
  ) {
    self.apiKey = apiKey
    self.acquisition = acquisition
    self.scope = scope
    self.accountIdentifier = accountIdentifier
    self.generation = generation
  }

  /// A redacted rendering safe for logs, errors, and user interfaces.
  ///
  /// The key never appears here beyond its last four characters.
  package var maskedKey: String {
    let key = apiKey
    guard key.count > 4 else { return "sk-orca-\u{2022}\u{2022}\u{2022}\u{2022}" }
    return "sk-orca-\u{2022}\u{2022}\u{2022}\u{2022}\(key.suffix(4))"
  }
}

// MARK: - Credential Source

/// The single seam through which a credential is obtained.
///
/// Pasting an API key and completing an OAuth 2.0 + PKCE authorization are two adapters of this
/// one interface. Provider requests, model discovery, and every AI entry point consume only the
/// resulting ``OrcaRouterCredential``; none of them re-implement authentication.
package protocol OrcaRouterCredentialSource: Sendable {
  /// Obtains a credential.
  ///
  /// Implementations may return a stored credential or start an interactive authorization.
  ///
  /// - Returns: The credential to use for inference.
  /// - Throws: A source-specific error. Interactive sources must surface denial, timeout,
  ///   cancellation, and network failures rather than hanging.
  func acquire() async throws -> OrcaRouterCredential
}

// MARK: - API Key Adapter

/// The API-key adapter: the user pastes a key that already exists.
package struct OrcaRouterAPIKeySource: OrcaRouterCredentialSource {
  /// The key the user supplied.
  package let apiKey: String

  /// The generation to stamp on the credential.
  package let generation: UInt64

  /// Creates an API-key source.
  package init(apiKey: String, generation: UInt64 = 0) {
    self.apiKey = apiKey
    self.generation = generation
  }

  /// Reports whether a string is plausibly an OrcaRouter API key.
  ///
  /// This is a lightweight format check to catch obvious mistakes only. A well-formed prefix is
  /// **not** proof that a credential is valid, and this method deliberately performs no network
  /// request: OrcaRouter exposes no non-billing validation endpoint, so validity is established by
  /// the first real request.
  ///
  /// - Parameter candidate: The candidate key.
  package static func isPlausibleKey(_ candidate: String) -> Bool {
    let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("sk-orca-") else { return false }
    return trimmed.count > "sk-orca-".count
  }

  /// Normalizes a pasted key.
  ///
  /// - Parameter candidate: The candidate key.
  /// - Returns: The trimmed key, or `nil` when the value is empty or blank.
  package static func normalize(_ candidate: String) -> String? {
    let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  package func acquire() async throws -> OrcaRouterCredential {
    guard let normalized = Self.normalize(apiKey) else {
      throw OrcaRouterCredentialError.emptyAPIKey
    }
    return OrcaRouterCredential(
      apiKey: normalized,
      acquisition: .apiKey,
      generation: generation
    )
  }
}

// MARK: - Credential Errors

/// Errors raised while acquiring an OrcaRouter credential.
package enum OrcaRouterCredentialError: Error, LocalizedError, Sendable, Equatable {
  /// The submitted API key was empty.
  case emptyAPIKey

  /// The authorization was refused by the user.
  case authorizationDenied

  /// The authorization window closed before it was approved.
  case authorizationExpired

  /// The authorization attempt was cancelled locally.
  case authorizationCancelled

  /// The `state` returned by the callback did not match the value that was sent.
  case stateMismatch

  /// The origin returned a `403`: the code is unknown, expired, or already used, or the verifier
  /// did not match the stored challenge.
  case codeRejected

  /// The authorization origin refused the request before minting a code.
  case authorizationRefused(statusCode: Int)

  /// The origin is rate limiting authorization requests.
  case tooManyAuthorizations

  /// The exchange or authorization response could not be understood.
  case malformedResponse

  /// The credential was revoked or rejected and the account must authorize again.
  case reauthenticationRequired

  package var errorDescription: String? {
    switch self {
    case .emptyAPIKey:
      return "Enter an OrcaRouter API key."
    case .authorizationDenied:
      return "The OrcaRouter authorization request was denied."
    case .authorizationExpired:
      return "The OrcaRouter authorization expired before it was approved. Start again."
    case .authorizationCancelled:
      return "The OrcaRouter authorization was cancelled."
    case .stateMismatch:
      return
        "The OrcaRouter authorization response did not match this request. It was discarded; "
        + "start again."
    case .codeRejected:
      return
        "The OrcaRouter authorization code was rejected: it is unknown, expired, or already used, "
        + "or it belongs to a different authorization request. Start again."
    case .authorizationRefused(let statusCode):
      return "The OrcaRouter authorization request was refused (HTTP \(statusCode))."
    case .tooManyAuthorizations:
      return
        "OrcaRouter is rate limiting authorizations for this account. Reuse the stored key or try "
        + "again later."
    case .malformedResponse:
      return "The OrcaRouter authorization response could not be read."
    case .reauthenticationRequired:
      return
        "The OrcaRouter credential was rejected. Authorize again, or paste a new API key."
    }
  }
}

// MARK: - Stored Credential

/// The durable record of a previously obtained credential.
package struct OrcaRouterStoredCredential: Sendable, Equatable, Codable {
  /// The persisted key.
  package let apiKey: String

  /// How the key was obtained.
  package let acquisition: OrcaRouterCredential.Acquisition

  /// The scope the authorization granted, when known.
  package let scope: String?

  /// An opaque account identifier, when known.
  package let accountIdentifier: String?

  /// The generation the key was issued under.
  package let generation: UInt64

  /// Creates a stored credential.
  package init(
    apiKey: String,
    acquisition: OrcaRouterCredential.Acquisition,
    scope: String? = nil,
    accountIdentifier: String? = nil,
    generation: UInt64 = 0
  ) {
    self.apiKey = apiKey
    self.acquisition = acquisition
    self.scope = scope
    self.accountIdentifier = accountIdentifier
    self.generation = generation
  }

  /// Creates a stored credential from a freshly acquired one.
  ///
  /// - Parameter credential: The credential to persist.
  package init(_ credential: OrcaRouterCredential) {
    self.init(
      apiKey: credential.apiKey,
      acquisition: credential.acquisition,
      scope: credential.scope,
      accountIdentifier: credential.accountIdentifier,
      generation: credential.generation
    )
  }

  /// The credential carried by this record.
  package var credential: OrcaRouterCredential {
    OrcaRouterCredential(
      apiKey: apiKey,
      acquisition: acquisition,
      scope: scope,
      accountIdentifier: accountIdentifier,
      generation: generation
    )
  }
}

// MARK: - Credential Store

/// Where a gained credential is kept between launches.
///
/// The SDK does not ship its own key store. Host applications supply the platform facility the
/// user already trusts — the Keychain on Apple platforms — by conforming to this protocol. The
/// in-memory implementation is provided for tests and for hosts that manage persistence
/// themselves.
package protocol OrcaRouterCredentialStore: Sendable {
  /// Reads the stored credential, if any.
  func load() throws -> OrcaRouterStoredCredential?

  /// Writes a credential, replacing any previous value.
  ///
  /// - Parameter credential: The record to persist.
  func save(_ credential: OrcaRouterStoredCredential) throws

  /// Removes the stored credential.
  ///
  /// Called on sign-out. It is **not** called automatically when a credential is rejected.
  func clear() throws
}

/// A credential store that keeps its value in memory only.
///
/// Suitable for tests and for hosts that own persistence themselves. Values do not survive a
/// process restart.
package final class OrcaRouterInMemoryCredentialStore: OrcaRouterCredentialStore, Sendable {
  private let storage = Mutex<OrcaRouterStoredCredential?>(nil)

  /// Creates an empty in-memory store.
  package init() {}

  /// Creates an in-memory store seeded with a credential.
  ///
  /// - Parameter credential: The record to seed with.
  package init(credential: OrcaRouterStoredCredential?) {
    storage.withLock { $0 = credential }
  }

  package func load() throws -> OrcaRouterStoredCredential? {
    storage.withLock { $0 }
  }

  package func save(_ credential: OrcaRouterStoredCredential) throws {
    storage.withLock { $0 = credential }
  }

  package func clear() throws {
    storage.withLock { $0 = nil }
  }
}

// MARK: - Credential Manager

/// Owns the current credential, its generation counter, and its reauthentication state.
///
/// A PKCE-issued key is durable: it is not an access token and there is no refresh grant. This type
/// therefore never schedules a refresh and never fabricates one. A credential is reused until
/// OrcaRouter revokes it; a rejected credential moves to ``needsReauthentication`` and stays
/// unusable until a new authorization succeeds.
package final class OrcaRouterCredentialManager: Sendable {
  private struct State: Sendable {
    var stored: OrcaRouterStoredCredential?
    var generation: UInt64
    var needsReauthentication: Bool
    var rejectedGeneration: UInt64?
  }

  private let state: Mutex<State>
  private let store: any OrcaRouterCredentialStore

  /// Creates a credential manager.
  ///
  /// - Parameters:
  ///   - store: Where credentials are kept between launches.
  ///   - generation: The generation to start counting from. Defaults to `1`.
  package init(
    store: any OrcaRouterCredentialStore = OrcaRouterInMemoryCredentialStore(),
    generation: UInt64 = 1
  ) {
    self.store = store
    let existing = try? store.load()
    self.state = Mutex(
      State(
        stored: existing,
        generation: max(generation, (existing?.generation ?? 0) + 1),
        needsReauthentication: false,
        rejectedGeneration: nil
      )
    )
  }

  /// The credential currently held, if any.
  package var current: OrcaRouterCredential? {
    state.withLock { $0.stored?.credential }
  }

  /// The generation the manager will stamp on the next issued credential.
  package var currentGeneration: UInt64 {
    state.withLock { $0.generation }
  }

  /// Whether the current credential has been rejected and requires a new authorization.
  package var needsReauthentication: Bool {
    state.withLock { $0.needsReauthentication }
  }

  /// The generation that was rejected, when one has been.
  package var rejectedGeneration: UInt64? {
    state.withLock { $0.rejectedGeneration }
  }

  /// Whether inference may proceed right now.
  package var isUsable: Bool {
    state.withLock { $0.stored != nil && !$0.needsReauthentication }
  }

  /// Returns the stored credential, or acquires and persists a new one.
  ///
  /// A stored credential is reused until it is rejected; this method does not re-authorize on
  /// every call. OrcaRouter caps PKCE-issued keys at ten per user per 24 hours, so a client that
  /// authorizes on every launch locks its own users out.
  ///
  /// - Parameter source: The adapter to use when no usable credential is stored.
  /// - Returns: A usable credential.
  /// - Throws: `OrcaRouterCredentialError.reauthenticationRequired` when the held credential was
  ///   rejected, or a source-specific error from acquisition.
  package func credential(
    sourcingFrom source: any OrcaRouterCredentialSource
  ) async throws -> OrcaRouterCredential {
    let snapshot = state.withLock { $0 }
    if let stored = snapshot.stored, !snapshot.needsReauthentication {
      return stored.credential
    }
    if snapshot.needsReauthentication {
      throw OrcaRouterCredentialError.reauthenticationRequired
    }
    return try await connect(using: source)
  }

  /// Runs an adapter and persists whatever it yields.
  ///
  /// The stored credential is only replaced once the adapter has succeeded, so a transient or
  /// misclassified failure never destroys a credential that still works.
  ///
  /// - Parameter source: The adapter to run.
  /// - Returns: The newly issued credential.
  /// - Throws: A source-specific error.
  @discardableResult
  package func connect(
    using source: any OrcaRouterCredentialSource
  ) async throws -> OrcaRouterCredential {
    let previous = state.withLock { $0 }
    let nextGeneration = previous.generation + 1

    // Run the adapter outside the lock; it may open a browser or wait on a device poll.
    let issued = try await source.acquire()
    let stamped = OrcaRouterCredential(
      apiKey: issued.apiKey,
      acquisition: issued.acquisition,
      scope: issued.scope,
      accountIdentifier: issued.accountIdentifier,
      generation: nextGeneration
    )
    let record = OrcaRouterStoredCredential(stamped)
    try store.save(record)

    state.withLock { current in
      current.stored = record
      current.generation = nextGeneration
      current.needsReauthentication = false
      current.rejectedGeneration = nil
    }
    return stamped
  }

  /// Marks the credential that made a rejected request as requiring reauthorization.
  ///
  /// Only the exact generation that produced the failure is affected. A late failure from a request
  /// issued under an older credential can never mark a credential that was authorized afterwards,
  /// which is what makes the `401` transition generation-safe.
  ///
  /// - Parameter generation: The generation that made the rejected request.
  /// - Returns: `true` if this call marked the current credential.
  @discardableResult
  package func markNeedsReauthentication(generation: UInt64) -> Bool {
    state.withLock { current in
      guard let stored = current.stored, stored.generation == generation else {
        return false
      }
      current.needsReauthentication = true
      current.rejectedGeneration = generation
      return true
    }
  }

  /// Records a rejection reported by the credential currently held.
  ///
  /// - Returns: `true` if a credential was marked.
  @discardableResult
  package func markCurrentCredentialRejected() -> Bool {
    let generation = state.withLock { $0.stored?.generation }
    guard let generation else { return false }
    return markNeedsReauthentication(generation: generation)
  }

  /// Signs out, discarding the stored credential and its rejection state.
  ///
  /// This is an explicit user action. Nothing calls it automatically on a rejection, because
  /// deleting a credential before a replacement succeeds turns a transient failure into permanent
  /// account loss.
  package func signOut() throws {
    try store.clear()
    state.withLock { current in
      current.stored = nil
      current.needsReauthentication = false
      current.rejectedGeneration = nil
      current.generation += 1
    }
  }
}
