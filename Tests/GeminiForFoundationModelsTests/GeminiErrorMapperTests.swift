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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiAPIDataModels
  import Testing

  @testable import GeminiForFoundationModels

  @Suite("GeminiErrorMapper Tests")
  struct GeminiErrorMapperTests {
    @Test
    func mapPassesThroughLanguageModelError() throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let originalError = LanguageModelError.timeout(
        .init(debugDescription: "Operation timed out")
      )

      let mappedError = GeminiErrorMapper.map(originalError)

      #expect(mappedError is LanguageModelError)
      if case LanguageModelError.timeout(let timeout) = mappedError {
        #expect(timeout.debugDescription == "Operation timed out")
      } else {
        Issue.record("Expected LanguageModelError.timeout")
      }
    }

    @Test
    func mapPassesThroughCancellationError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let originalError = CancellationError()

      let mappedError = GeminiErrorMapper.map(originalError)

      #expect(mappedError is CancellationError)
    }

    @Test
    func mapPassesThroughGeminiLanguageModelError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let originalError = GeminiLanguageModel.Error.serviceUnavailable(
        .init(debugDescription: "Service down")
      )

      let mappedError = GeminiErrorMapper.map(originalError)

      #expect(mappedError as? GeminiLanguageModel.Error == originalError)
    }

    @Test
    func mapRateLimit429WithRetryDelay() throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let apiError = GoogleCloudAPIError(
        code: 429,
        message: "Resource exhausted",
        status: .resourceExhausted,
        retryDelay: .seconds(60)
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      if case LanguageModelError.rateLimited(let rateLimited) = mappedError {
        #expect(rateLimited.debugDescription == "Resource exhausted")
        let resetDate = try #require(rateLimited.resetDate)
        #expect(resetDate > Date.now)
      } else {
        Issue.record("Expected LanguageModelError.rateLimited")
      }
    }

    @Test
    func mapRateLimitResourceExhaustedWithoutRetryDelay() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let apiError = GoogleCloudAPIError(
        code: 429,
        message: "Quota exceeded",
        status: .resourceExhausted
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      if case LanguageModelError.rateLimited(let rateLimited) = mappedError {
        #expect(rateLimited.debugDescription == "Quota exceeded")
        #expect(rateLimited.resetDate == nil)
      } else {
        Issue.record("Expected LanguageModelError.rateLimited")
      }
    }

    @Test
    func mapServiceUnavailableFromAPIError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let apiError = GoogleCloudAPIError(
        code: 503,
        message: "Backend service unavailable",
        status: .unavailable
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      let expected = GeminiLanguageModel.Error.serviceUnavailable(
        .init(debugDescription: "Backend service unavailable")
      )
      #expect(mappedError as? GeminiLanguageModel.Error == expected)
    }

    @Test
    func mapServiceUnavailableFromHTTPError503() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let httpError = GeminiAPIError.httpError(statusCode: 503, body: "Overloaded")

      let mappedError = GeminiErrorMapper.map(httpError)

      let expected = GeminiLanguageModel.Error.serviceUnavailable(
        .init(debugDescription: "Gemini service is unavailable (HTTP 503): Overloaded")
      )
      #expect(mappedError as? GeminiLanguageModel.Error == expected)
    }

    @Test
    func mapModelNotFoundFrom404Message() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let apiError = GoogleCloudAPIError(
        code: 404,
        message: "models/gemini-invalid is not found",
        status: .notFound
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      let expected = GeminiLanguageModel.Error.modelNotFound(
        .init(debugDescription: "models/gemini-invalid is not found")
      )
      #expect(mappedError as? GeminiLanguageModel.Error == expected)
    }

    @Test
    func mapGeneralAPIError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let apiError = GoogleCloudAPIError(
        code: 400,
        message: "Invalid field value",
        status: .invalidArgument
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      let expected = GeminiLanguageModel.Error.apiError(
        .init(
          code: "INVALID_ARGUMENT",
          statusCode: 400,
          message: "Invalid field value",
          metadata: ["status": "INVALID_ARGUMENT"]
        )
      )
      #expect(mappedError as? GeminiLanguageModel.Error == expected)
    }

    @Test
    func mapNetworkFailureFromHTTPError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let httpError = GeminiAPIError.httpError(statusCode: 502, body: "Bad Gateway")

      let mappedError = GeminiErrorMapper.map(httpError)

      let expected = GeminiLanguageModel.Error.networkFailure(
        .init(debugDescription: "Gemini HTTP error (status 502): Bad Gateway")
      )
      #expect(mappedError as? GeminiLanguageModel.Error == expected)
    }

    @Test
    func mapTimeoutFromURLError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let urlError = URLError(.timedOut)

      let mappedError = GeminiErrorMapper.map(urlError)

      #expect(mappedError is LanguageModelError)
      if case LanguageModelError.timeout = mappedError {
        // Success
      } else {
        Issue.record("Expected LanguageModelError.timeout")
      }
    }

    @Test
    func mapNetworkFailureFromGenericURLError() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let urlError = URLError(.cannotConnectToHost)

      let mappedError = GeminiErrorMapper.map(urlError)

      let expected = GeminiLanguageModel.Error.networkFailure(
        .init(debugDescription: urlError.localizedDescription)
      )
      #expect(mappedError as? GeminiLanguageModel.Error == expected)
    }

    @Test
    func checkGuardrailsThrowsForPromptSafety() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let promptFeedback = PromptFeedback(blockReason: .safety)
      let chunk = GenerateContentResponse(promptFeedback: promptFeedback)

      #expect(throws: LanguageModelError.self) {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
      }
    }

    @Test
    func checkGuardrailsThrowsRefusalForPromptOther() async throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let promptFeedback = PromptFeedback(blockReason: .other)
      let chunk = GenerateContentResponse(promptFeedback: promptFeedback)

      do {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
        Issue.record("Expected refusal error to be thrown")
      } catch let LanguageModelError.refusal(refusal) {
        let content = try await refusal.explanation.content
        #expect(content.contains("other"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    func checkGuardrailsThrowsForCandidateSafety() throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let candidate = Candidate(
        finishReason: .safety,
        finishMessage: "Safety policy triggered"
      )
      let chunk = GenerateContentResponse(candidates: [candidate])

      do {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
        Issue.record("Expected guardrailViolation error to be thrown")
      } catch let LanguageModelError.guardrailViolation(violation) {
        #expect(violation.debugDescription.contains("Safety policy triggered"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    func checkGuardrailsThrowsRefusalForCandidateRecitation() async throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let candidate = Candidate(
        finishReason: .recitation,
        finishMessage: "Recitation check failed"
      )
      let chunk = GenerateContentResponse(candidates: [candidate])

      do {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
        Issue.record("Expected refusal error to be thrown")
      } catch let LanguageModelError.refusal(refusal) {
        let content = try await refusal.explanation.content
        #expect(content.contains("Recitation check failed"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    func checkGuardrailsThrowsUnsupportedLanguageForCandidateLanguage() throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let candidate = Candidate(
        finishReason: .language,
        finishMessage: "Language not supported"
      )
      let chunk = GenerateContentResponse(candidates: [candidate])

      do {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
        Issue.record("Expected unsupportedLanguageOrLocale error to be thrown")
      } catch let LanguageModelError.unsupportedLanguageOrLocale(unsupported) {
        #expect(unsupported.languageCode == Locale.LanguageCode("und"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    func checkGuardrailsPassesForSafeContent() throws {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let candidate = Candidate(finishReason: .stop)
      let chunk = GenerateContentResponse(candidates: [candidate])

      try GeminiErrorMapper.checkGuardrails(in: chunk)
    }

    @Test
    func apiErrorDebugDescriptionAndEquality() {
      guard #available(macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *) else {
        return
      }
      let errorWithCode = GeminiLanguageModel.Error.APIError(
        code: "invalid_request",
        statusCode: 400,
        message: "Invalid parameter"
      )
      let errorWithoutCode = GeminiLanguageModel.Error.APIError(
        code: "invalid_request",
        message: "Invalid parameter"
      )

      #expect(errorWithCode.debugDescription.contains("HTTP 400"))
      #expect(!errorWithoutCode.debugDescription.contains("HTTP"))
      #expect(errorWithCode == errorWithCode)
      #expect(errorWithCode != errorWithoutCode)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
