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
import GeminiAPIDataModels
import GeminiTestUtilities
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@testable import GeminiAPIClient

/// Verifies that inference reaches the inference origin, carries a bearer credential, keeps the
/// `vendor/model` identifier verbatim, and maps a rejected credential onto a reauthentication path.
///
/// The suite owns `chat.example.test`, so it never contends with another suite's recordings.
@Suite("OrcaRouter Client Tests", .serialized)
struct OrcaRouterClientTests {
  /// How many inference requests have been recorded so far, so a test can assert on its own delta.
  ///
  /// Every test in this suite shares `chat.example.test`, so an absolute count or an "is empty"
  /// check would observe its neighbours. A before/after delta scopes the assertion to this test.
  static func recordedChatRequestCount() -> Int {
    OrcaRouterRecordingURLProtocol.requests(toHost: OrcaRouterTestConstants.chatAPIHost).count
  }

  func makeClient(
    credentialSource: any OrcaRouterCredentialSource = OrcaRouterStaticCredentialSource(
      apiKey: OrcaRouterTestConstants.fakeAPIKey
    ),
    apiBaseURL: String = OrcaRouterTestConstants.chatAPIBaseURL
  ) throws -> OrcaRouterClient {
    let provider = try OrcaRouterProvider(
      authentication: .apiKey,
      authBaseURL: OrcaRouterTestConstants.authBaseURL,
      apiBaseURL: apiBaseURL
    )
    return OrcaRouterClient(
      provider: provider,
      credentialSource: credentialSource,
      sessionConfiguration: OrcaRouterRecordingURLProtocol.sessionConfiguration
    )
  }

  static func textRequest(
    model: String? = "deepseek/deepseek-v4-pro",
    prompt: String = "Say hello."
  ) -> GenerateContentRequest {
    GenerateContentRequest(
      model: model,
      contents: [Content(parts: [Part(data: .text(prompt))], role: "user")]
    )
  }

  // MARK: - Where the request goes

  @Test
  func inferenceGoesToTheInferenceOriginAndNeverToTheAuthOrigin() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .sse([#"{"choices":[{"delta":{"content":"hi"}}]}"#])
    )

    let client = try makeClient()
    let stream = try await client.generateContentStream(for: Self.textRequest())
    for try await _ in stream {}

    let requests = OrcaRouterRecordingURLProtocol.requests(
      toHost: OrcaRouterTestConstants.chatAPIHost
    )
    let request = try #require(requests.first)
    #expect(request.url.path == "/v1/chat/completions")
    #expect(request.method == "POST")
    #expect(request.headers["authorization"] == "Bearer \(OrcaRouterTestConstants.fakeAPIKey)")
    // The credential must never be placed in the URL.
    #expect(!request.url.absoluteString.contains(OrcaRouterTestConstants.fakeAPIKey))
    // Authentication lives on a different origin, so nothing may reach it from inference.
    #expect(
      OrcaRouterRecordingURLProtocol.requests(toHost: OrcaRouterTestConstants.authHost).isEmpty
    )
  }

  @Test
  func theModelIdentifierIsSentVerbatim() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .sse([#"{"choices":[{"delta":{"content":"hi"}}]}"#])
    )

    let client = try makeClient()
    let stream = try await client.generateContentStream(
      for: Self.textRequest(model: "openai/gpt-5.5")
    )
    for try await _ in stream {}

    let request = try #require(
      OrcaRouterRecordingURLProtocol.lastRequest(
        host: OrcaRouterTestConstants.chatAPIHost,
        pathSuffix: "/chat/completions"
      )
    )
    // The vendor/model namespace is preserved exactly; it is not split, lower-cased, or rewritten.
    #expect(request.json?["model"] as? String == "openai/gpt-5.5")
    #expect(request.json?["stream"] as? Bool == true)
    #expect(request.json?["messages"] != nil)
  }

  @Test
  func theRequestNeverLeaksTheKeyIntoHeadersOtherThanAuthorization() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .sse([#"{"choices":[{"delta":{"content":"hi"}}]}"#])
    )

    let client = try makeClient()
    let stream = try await client.generateContentStream(for: Self.textRequest())
    for try await _ in stream {}

    let request = try #require(
      OrcaRouterRecordingURLProtocol.lastRequest(
        host: OrcaRouterTestConstants.chatAPIHost,
        pathSuffix: "/chat/completions"
      )
    )
    for (name, value) in request.headers where name != "authorization" {
      #expect(!value.contains("sk-orca-"), "credential leaked into header \(name)")
    }
    let bodyText = String(decoding: request.body, as: UTF8.self)
    #expect(!bodyText.contains("sk-orca-"))
  }

  // MARK: - Streaming

  @Test
  func streamedChunksAreTranslatedIntoSDKResponses() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .sse([
        #"{"choices":[{"delta":{"role":"assistant","content":"Hel"}}]}"#,
        #"{"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}]}"#,
      ])
    )

    let client = try makeClient()
    let stream = try await client.generateContentStream(for: Self.textRequest())

    var texts: [String] = []
    for try await response in stream {
      for candidate in response.candidates ?? [] {
        for part in candidate.content?.parts ?? [] {
          if case .text(let value) = part.data { texts.append(value) }
        }
      }
    }
    #expect(texts.joined() == "Hello")
  }

  // MARK: - Errors

  @Test
  func aRejectedCredentialIsReportedAsUnauthenticated() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .raw(#"{"error":{"message":"invalid key","type":"auth_error"}}"#, status: 401)
    )

    let client = try makeClient()
    do {
      let stream = try await client.generateContentStream(for: Self.textRequest())
      for try await _ in stream {}
      Issue.record("A 401 must be surfaced, not streamed as an empty success.")
    } catch let error as GeminiAPIError {
      guard case .apiError(let apiError) = error else {
        Issue.record("Expected an apiError, got \(error)")
        return
      }
      #expect(apiError.status == .unauthenticated)
    }
  }

  @Test
  func aRateLimitedRequestKeepsTheOriginsMessage() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .raw(#"{"error":{"message":"slow down","type":"rate_limit"}}"#, status: 429)
    )

    let client = try makeClient()
    do {
      let stream = try await client.generateContentStream(for: Self.textRequest())
      for try await _ in stream {}
      Issue.record("A 429 must be surfaced.")
    } catch let error as GeminiAPIError {
      guard case .apiError(let apiError) = error else {
        Issue.record("Expected an apiError, got \(error)")
        return
      }
      #expect(apiError.status == .resourceExhausted)
      #expect(apiError.message == "slow down")
    }
  }

  @Test
  func aForbiddenModelIsReportedAsPermissionDenied() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .raw(#"{"error":{"message":"model_access_denied","type":"forbidden"}}"#, status: 403)
    )

    let client = try makeClient()
    do {
      let stream = try await client.generateContentStream(for: Self.textRequest())
      for try await _ in stream {}
      Issue.record("A 403 must be surfaced.")
    } catch let error as GeminiAPIError {
      guard case .apiError(let apiError) = error else {
        Issue.record("Expected an apiError, got \(error)")
        return
      }
      #expect(apiError.status == .permissionDenied)
      #expect(apiError.message == "model_access_denied")
    }
  }

  @Test
  func noErrorDescribesTheCredential() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .raw(#"{"error":{"message":"invalid key"}}"#, status: 401)
    )

    let client = try makeClient()
    do {
      let stream = try await client.generateContentStream(for: Self.textRequest())
      for try await _ in stream {}
    } catch {
      #expect(!String(describing: error).contains("sk-orca-"))
    }
  }

  // MARK: - The same client serves both authentication entries

  @Test
  func bothAuthenticationEntriesDriveTheSameInferencePath() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .sse([#"{"choices":[{"delta":{"content":"hi"}}]}"#])
    )

    // Whether the credential was pasted or authorized, the transport is identical.
    let credentials = [
      OrcaRouterCredential(apiKey: OrcaRouterTestConstants.fakeAPIKey, acquisition: .apiKey),
      OrcaRouterCredential(
        apiKey: OrcaRouterTestConstants.fakeAPIKey,
        acquisition: .account,
        scope: "api"
      ),
    ]
    for credential in credentials {
      let client = try makeClient(
        credentialSource: OrcaRouterStaticCredentialSource(credential: credential)
      )
      let stream = try await client.generateContentStream(for: Self.textRequest())
      for try await _ in stream {}
    }

    let requests = OrcaRouterRecordingURLProtocol.requests(
      toHost: OrcaRouterTestConstants.chatAPIHost
    )
    let mine = requests.suffix(credentials.count)
    #expect(mine.count == credentials.count)
    #expect(mine.allSatisfy { $0.headers["authorization"] == "Bearer \(OrcaRouterTestConstants.fakeAPIKey)" })
  }

  @Test
  func aRejectedCredentialIsNeverSilentlyRenewed() async throws {
    // A durable key has no refresh endpoint. Requesting one against a rejected credential must fail
    // loudly from the credential seam rather than quietly minting a replacement.
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

    let before = Self.recordedChatRequestCount()
    let client = try makeClient(
      credentialSource: OrcaRouterCredentialManagerSource(manager: manager)
    )
    await #expect(throws: OrcaRouterCredentialError.reauthenticationRequired) {
      _ = try await client.generateContentStream(for: Self.textRequest())
    }
    // Nothing new was sent: there is no refresh grant to call, so a rejected credential fails at the
    // seam instead of quietly producing another request.
    #expect(Self.recordedChatRequestCount() == before)
  }

  // MARK: - Token counting

  @Test
  func tokenCountingUsesARealCompletionAndReadsItsUsage() async throws {
    OrcaRouterRecordingURLProtocol.stub(
      matching: OrcaRouterTestConstants.chatAPIBaseURL,
      .json([
        "choices": [["message": ["role": "assistant", "content": "hi"], "finish_reason": "stop"]],
        "usage": ["prompt_tokens": 11, "completion_tokens": 7, "total_tokens": 18],
      ])
    )

    let client = try makeClient()
    let response = try await client.countTokens(
      for: CountTokensRequest(
        contents: [Content(parts: [Part(data: .text("Count me"))], role: "user")],
        model: "deepseek/deepseek-v4-pro"
      )
    )
    #expect(response.totalTokens == 18)

    let request = try #require(
      OrcaRouterRecordingURLProtocol.lastRequest(
        host: OrcaRouterTestConstants.chatAPIHost,
        pathSuffix: "/chat/completions"
      )
    )
    // OrcaRouter has no counting route, so this is a real, billed completion.
    #expect(request.json?["stream"] as? Bool == false)
  }
}

// MARK: - Manager-backed source

/// A credential source backed by a manager, so a test can observe the `needsReauthentication` path.
struct OrcaRouterCredentialManagerSource: OrcaRouterCredentialSource {
  let manager: OrcaRouterCredentialManager

  func acquire() async throws -> OrcaRouterCredential {
    try await manager.credential(
      sourcingFrom: OrcaRouterFailingCredentialSource(error: OrcaRouterCredentialError.codeRejected)
    )
  }
}
