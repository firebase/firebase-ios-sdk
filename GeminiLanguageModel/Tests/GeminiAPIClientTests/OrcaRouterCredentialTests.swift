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
import Testing

@testable import GeminiAPIClient

/// Verifies both authentication adapters, the credential seam they share, and the lifecycle rules a
/// durable key must follow.
@Suite("OrcaRouter Credential Tests")
struct OrcaRouterCredentialTests {
  // MARK: - Both adapters produce the same result

  @Test
  func apiKeyAdapterProducesAUsableCredential() async throws {
    let source = OrcaRouterAPIKeySource(apiKey: "  sk-orca-presented-key  ")
    let credential = try await source.acquire()
    // Surrounding whitespace from a paste is trimmed rather than treated as part of the key.
    #expect(credential.apiKey == "sk-orca-presented-key")
    #expect(credential.acquisition == .apiKey)
  }

  @Test
  func bothAdaptersYieldTheSameCredentialShape() async throws {
    let pasted = try await OrcaRouterAPIKeySource(apiKey: "sk-orca-aaa").acquire()
    let authorized = OrcaRouterCredential(
      apiKey: "sk-orca-bbb",
      acquisition: .account,
      scope: "api"
    )

    // The seam is the credential, not the route taken to it.
    #expect(type(of: pasted) == type(of: authorized))
    #expect(pasted.acquisition != authorized.acquisition)
    #expect(pasted.apiKey.hasPrefix("sk-orca-"))
    #expect(authorized.apiKey.hasPrefix("sk-orca-"))
  }

  @Test
  func downstreamConsumersDoNotDependOnTheAcquisitionRoute() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.credentialAPIBaseURL + "/models",
      .json(["object": "list", "data": []])
    )
    // Both a pasted key and an authorized key drive the same catalog request.
    for credential in [
      OrcaRouterCredential(apiKey: OrcaRouterTestConstants.fakeAPIKey, acquisition: .apiKey),
      OrcaRouterCredential(
        apiKey: OrcaRouterTestConstants.fakeAPIKey,
        acquisition: .account,
        scope: "api"
      ),
    ] {
      let provider = try OrcaRouterProvider(
        authentication: credential.acquisition == .apiKey ? .apiKey : .account,
        authBaseURL: OrcaRouterTestConstants.authBaseURL,
        apiBaseURL: OrcaRouterTestConstants.credentialAPIBaseURL
      )
      let client = OrcaRouterModelCatalogClient(
        provider: provider,
        credentialSource: OrcaRouterStaticCredentialSource(credential: credential),
        sessionConfiguration: OrcaRouterRecordingURLProtocol.sessionConfiguration
      )
      let catalog = await client.catalog(
        for: OrcaRouterModelRequirement(capability: .chat(requiredInputModalities: [.image]))
      )
      #expect(catalog.provenance == .live)
      let recorded = try #require(
        OrcaRouterRecordingURLProtocol.lastRequest(
          host: OrcaRouterTestConstants.credentialAPIHost,
          pathSuffix: "/models"
        )
      )
      #expect(recorded.headers["authorization"]?.hasPrefix("Bearer sk-orca-") == true)
    }
  }

  @Test
  func emptyAPIKeyIsRejected() async {
    await #expect(throws: OrcaRouterCredentialError.emptyAPIKey) {
      try await OrcaRouterAPIKeySource(apiKey: "   ").acquire()
    }
  }

  @Test
  func keyFormatCheckIsAdvisoryOnly() {
    #expect(OrcaRouterAPIKeySource.isPlausibleKey("sk-orca-abc"))
    #expect(!OrcaRouterAPIKeySource.isPlausibleKey("sk-other"))
    #expect(!OrcaRouterAPIKeySource.isPlausibleKey("sk-orca-"))
    // A well-formed prefix is not proof of validity, and normalizing never rejects on format.
    #expect(OrcaRouterAPIKeySource.normalize("  sk-weird-but-present  ") == "sk-weird-but-present")
    #expect(OrcaRouterAPIKeySource.normalize("  ") == nil)
  }

  // MARK: - Redaction

  @Test
  func theKeyIsRedactedEverywhereItIsDisplayed() {
    let credential = OrcaRouterCredential(
      apiKey: "sk-orca-notarealkeyREDACTED0000",
      acquisition: .apiKey
    )
    let masked = credential.maskedKey
    #expect(!masked.contains("notarealkeyREDACTED"))
    #expect(masked.hasSuffix("0000"))
    #expect(masked.hasPrefix("sk-orca-"))
    #expect(masked.contains("\u{2022}"))
  }

  @Test
  func aShortOrDamagedKeyIsStillFullyRedacted() {
    let credential = OrcaRouterCredential(apiKey: "abc", acquisition: .apiKey)
    #expect(!credential.maskedKey.contains("abc"))
  }

  @Test
  func noCredentialErrorEchoesTheKey() {
    let secret = "sk-orca-notarealsecretVALUE000"
    for error in [
      OrcaRouterCredentialError.emptyAPIKey,
      .authorizationDenied,
      .authorizationExpired,
      .authorizationCancelled,
      .stateMismatch,
      .codeRejected,
      .authorizationRefused(statusCode: 403),
      .tooManyAuthorizations,
      .malformedResponse,
      .reauthenticationRequired,
    ] {
      let description = error.errorDescription ?? ""
      #expect(!description.contains(secret))
      #expect(!description.contains("sk-orca-"))
    }
  }

  // MARK: - Store

  @Test
  func storeSavesLoadsAndClears() throws {
    let store = OrcaRouterInMemoryCredentialStore()
    let record = OrcaRouterStoredCredential(
      apiKey: OrcaRouterTestConstants.fakeAPIKey,
      acquisition: .account,
      scope: "api",
      generation: 3
    )
    try store.save(record)
    #expect(try store.load() == record)
    try store.clear()
    #expect(try store.load() == nil)
  }

  @Test
  func storedCredentialRoundTripsThroughEncoding() throws {
    let record = OrcaRouterStoredCredential(
      apiKey: OrcaRouterTestConstants.fakeAPIKey,
      acquisition: .account,
      scope: "api",
      accountIdentifier: "user-1",
      generation: 7
    )
    let data = try JSONEncoder().encode(record)
    let decoded = try JSONDecoder().decode(OrcaRouterStoredCredential.self, from: data)
    #expect(decoded == record)
  }

  // MARK: - Manager lifecycle

  @Test
  func managerReusesAStoredCredentialRatherThanMintingAnother() async throws {
    let store = OrcaRouterInMemoryCredentialStore(
      credential: OrcaRouterStoredCredential(
        apiKey: "sk-orca-existing",
        acquisition: .account,
        generation: 4
      )
    )
    let manager = OrcaRouterCredentialManager(store: store)

    // A source that would fail loudly if it were consulted at all.
    let credential = try await manager.credential(
      sourcingFrom: OrcaRouterFailingCredentialSource(error: OrcaRouterCredentialError.codeRejected)
    )
    #expect(credential.apiKey == "sk-orca-existing")
    #expect(credential.generation == 4)
  }

  @Test
  func managerStampsAnIncreasingGenerationOnEachConnect() async throws {
    let manager = OrcaRouterCredentialManager(store: OrcaRouterInMemoryCredentialStore())
    let first = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-one")
    )
    let second = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-two")
    )
    #expect(second.generation > first.generation)
    #expect(manager.currentGeneration == second.generation)
  }

  @Test
  func aFailedConnectDoesNotDestroyTheExistingCredential() async throws {
    let manager = OrcaRouterCredentialManager(
      store: OrcaRouterInMemoryCredentialStore(
        credential: OrcaRouterStoredCredential(
          apiKey: "sk-orca-still-good",
          acquisition: .apiKey,
          generation: 1
        )
      )
    )
    _ = try await manager.connect(using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-new"))

    // A later failure must leave the working credential in place.
    await #expect(throws: OrcaRouterCredentialError.authorizationDenied) {
      try await manager.connect(
        using: OrcaRouterFailingCredentialSource(error: OrcaRouterCredentialError.authorizationDenied)
      )
    }
    #expect(manager.current?.apiKey == "sk-orca-new")
  }

  @Test
  func aRejectedCredentialIsNotSilentlyDeleted() async throws {
    let store = OrcaRouterInMemoryCredentialStore(
      credential: OrcaRouterStoredCredential(
        apiKey: "sk-orca-revoked",
        acquisition: .account,
        generation: 2
      )
    )
    let manager = OrcaRouterCredentialManager(store: store)
    #expect(manager.markCurrentCredentialRejected())

    // The secret survives; only its usability changed.
    #expect(try store.load()?.apiKey == "sk-orca-revoked")
    #expect(manager.needsReauthentication)
    #expect(!manager.isUsable)
  }

  @Test
  func rejectionBlocksInferenceInsteadOfRepromptingForever() async {
    let manager = OrcaRouterCredentialManager(
      store: OrcaRouterInMemoryCredentialStore(
        credential: OrcaRouterStoredCredential(
          apiKey: "sk-orca-revoked",
          acquisition: .account,
          generation: 1
        )
      )
    )
    manager.markCurrentCredentialRejected()

    await #expect(throws: OrcaRouterCredentialError.reauthenticationRequired) {
      try await manager.credential(
        sourcingFrom: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-ignored")
      )
    }
  }

  @Test
  func reauthenticationClearsTheRejectedState() async throws {
    let manager = OrcaRouterCredentialManager(
      store: OrcaRouterInMemoryCredentialStore(
        credential: OrcaRouterStoredCredential(
          apiKey: "sk-orca-old",
          acquisition: .account,
          generation: 1
        )
      )
    )
    manager.markCurrentCredentialRejected()
    let replacement = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-fresh", acquisition: .account)
    )
    #expect(!manager.needsReauthentication)
    #expect(manager.isUsable)
    #expect(manager.current?.apiKey == replacement.apiKey)
  }

  @Test
  func aStaleGenerationsFailureCannotBreakANewerCredential() async throws {
    let manager = OrcaRouterCredentialManager(store: OrcaRouterInMemoryCredentialStore())

    let old = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-generation-one")
    )
    let fresh = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-generation-two")
    )
    #expect(fresh.generation > old.generation)

    // A 401 that belongs to the older request arrives late.
    let marked = manager.markNeedsReauthentication(generation: old.generation)

    #expect(!marked)
    // The newly authorized credential is untouched.
    #expect(!manager.needsReauthentication)
    #expect(manager.isUsable)
    #expect(manager.current?.apiKey == "sk-orca-generation-two")
  }

  @Test
  func onlyTheRejectedGenerationIsAffected() async throws {
    let manager = OrcaRouterCredentialManager(store: OrcaRouterInMemoryCredentialStore())
    let credential = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-live")
    )
    #expect(manager.markNeedsReauthentication(generation: credential.generation))
    #expect(manager.rejectedGeneration == credential.generation)
    #expect(manager.needsReauthentication)
  }

  @Test
  func signOutIsExplicitAndClearsTheStore() async throws {
    let store = OrcaRouterInMemoryCredentialStore(
      credential: OrcaRouterStoredCredential(
        apiKey: "sk-orca-signing-out",
        acquisition: .account,
        generation: 1
      )
    )
    let manager = OrcaRouterCredentialManager(store: store)
    try manager.signOut()
    #expect(try store.load() == nil)
    #expect(manager.current == nil)
    #expect(!manager.needsReauthentication)
  }

  @Test
  func noRefreshGrantIsAttemptedOnARejectedKey() async throws {
    // Proving an absence of requests is done against a host this suite alone owns, because other
    // suites are recording their own traffic into the same registry concurrently. A durable key has
    // no refresh endpoint, so a rejected key must produce a credential error and no request at all.
    let manager = OrcaRouterCredentialManager(store: OrcaRouterInMemoryCredentialStore())
    _ = try await manager.connect(
      using: OrcaRouterStaticCredentialSource(apiKey: OrcaRouterTestConstants.fakeAPIKey)
    )
    manager.markCurrentCredentialRejected()
    await #expect(throws: OrcaRouterCredentialError.reauthenticationRequired) {
      try await manager.credential(
        sourcingFrom: OrcaRouterStaticCredentialSource(apiKey: "sk-orca-other")
      )
    }
    #expect(OrcaRouterRecordingURLProtocol.requests(toHost: OrcaRouterTestConstants.probeHost).isEmpty)
  }
}
