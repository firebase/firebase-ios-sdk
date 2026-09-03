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
  import SharedTestUtilities
  import Testing

  @testable import GeminiForFoundationModels

  @Suite("GeminiErrorMapper Tests", .requireFoundationModels)
  struct GeminiErrorMapperTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapPassesThroughLanguageModelError() throws {
      let originalError = LanguageModelError.timeout(
        LanguageModelError.Timeout(debugDescription: "Operation timed out")
      )

      let mappedError = GeminiErrorMapper.map(originalError)

      #expect(mappedError is LanguageModelError)
      if case LanguageModelError.timeout(let timeout) = mappedError {
        #expect(timeout.debugDescription == originalError.debugDescription)
      } else {
        Issue.record("Expected LanguageModelError.timeout")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapPassesThroughCancellationError() {
      let originalError = CancellationError()

      let mappedError = GeminiErrorMapper.map(originalError)

      #expect(mappedError is CancellationError)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapPassesThroughGeminiLanguageModelError() throws {
      let originalError = GeminiLanguageModel.Error.serviceUnavailable(
        GeminiLanguageModel.Error.ServiceUnavailable(debugDescription: "Service down")
      )

      let mappedError = GeminiErrorMapper.map(originalError)

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .serviceUnavailable(let serviceUnavailable) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.serviceUnavailable, got: \(mappedError)")
        return
      }
      #expect(serviceUnavailable.debugDescription == originalError.debugDescription)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapRateLimit429WithRetryDelay() throws {
      let apiError = GoogleCloudAPIError(
        code: 429,
        message: "Resource exhausted",
        status: .resourceExhausted,
        retryDelay: .seconds(60)
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      if case LanguageModelError.rateLimited(let rateLimited) = mappedError {
        #expect(rateLimited.debugDescription == apiError.message)
        let resetDate = try #require(rateLimited.resetDate)
        #expect(resetDate > Date.now)
      } else {
        Issue.record("Expected LanguageModelError.rateLimited")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapRateLimitResourceExhaustedWithoutRetryDelay() {
      let apiError = GoogleCloudAPIError(
        code: 429,
        message: "Quota exceeded",
        status: .resourceExhausted
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      if case LanguageModelError.rateLimited(let rateLimited) = mappedError {
        #expect(rateLimited.debugDescription == apiError.message)
        #expect(rateLimited.resetDate == nil)
      } else {
        Issue.record("Expected LanguageModelError.rateLimited")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapServiceUnavailableFromAPIError() throws {
      let apiError = GoogleCloudAPIError(
        code: 503,
        message: "Backend service unavailable",
        status: .unavailable
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .serviceUnavailable(let serviceUnavailable) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.serviceUnavailable, got: \(mappedError)")
        return
      }
      #expect(serviceUnavailable.debugDescription == apiError.message)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapServiceUnavailableFromHTTPError503() throws {
      let httpError = GeminiAPIError.httpError(statusCode: 503, body: "Overloaded")

      let mappedError = GeminiErrorMapper.map(httpError)

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .serviceUnavailable(let serviceUnavailable) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.serviceUnavailable, got: \(mappedError)")
        return
      }
      if case GeminiAPIError.httpError(_, let body) = httpError {
        #expect(serviceUnavailable.debugDescription.contains(body))
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapModelNotFoundFrom404Message() throws {
      let apiError = GoogleCloudAPIError(
        code: 404,
        message: "models/gemini-invalid is not found",
        status: .notFound
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .modelNotFound(let modelNotFound) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.modelNotFound, got: \(mappedError)")
        return
      }
      #expect(modelNotFound.debugDescription == apiError.message)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapGeneralAPIError() throws {
      let apiError = GoogleCloudAPIError(
        code: 400,
        message: "Invalid field value",
        status: .invalidArgument
      )

      let mappedError = GeminiErrorMapper.map(GeminiAPIError.apiError(apiError))

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .apiError(let geminiAPIError) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.apiError, got: \(mappedError)")
        return
      }
      #expect(geminiAPIError.code == apiError.status?.rawValue)
      #expect(geminiAPIError.statusCode == apiError.code)
      #expect(geminiAPIError.message == apiError.message)
      #expect(geminiAPIError.metadata["status"] as? String == apiError.status?.rawValue)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapNetworkFailureFromHTTPError() throws {
      let httpError = GeminiAPIError.httpError(statusCode: 502, body: "Bad Gateway")

      let mappedError = GeminiErrorMapper.map(httpError)

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .networkFailure(let networkFailure) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.networkFailure, got: \(mappedError)")
        return
      }
      if case GeminiAPIError.httpError(_, let body) = httpError {
        #expect(networkFailure.debugDescription.contains(body))
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapTimeoutFromURLError() {
      let urlError = URLError(.timedOut)

      let mappedError = GeminiErrorMapper.map(urlError)

      #expect(mappedError is LanguageModelError)
      if case LanguageModelError.timeout(let timeout) = mappedError {
        #expect(timeout.debugDescription == urlError.localizedDescription)
      } else {
        Issue.record("Expected LanguageModelError.timeout")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapNetworkFailureFromGenericURLError() throws {
      let urlError = URLError(.cannotConnectToHost)

      let mappedError = GeminiErrorMapper.map(urlError)

      let geminiError = try #require(
        mappedError as? GeminiLanguageModel.Error,
        "Expected GeminiLanguageModel.Error, got: \(type(of: mappedError))"
      )
      guard case .networkFailure(let networkFailure) = geminiError else {
        Issue.record("Expected GeminiLanguageModel.Error.networkFailure, got: \(mappedError)")
        return
      }
      #expect(networkFailure.debugDescription == urlError.localizedDescription)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsThrowsForPromptSafety() {
      let promptFeedback = PromptFeedback(blockReason: .safety)
      let chunk = GenerateContentResponse(promptFeedback: promptFeedback)

      #expect(throws: LanguageModelError.self) {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsThrowsRefusalForPromptOther() async throws {
      let promptFeedback = PromptFeedback(blockReason: .other)
      let chunk = GenerateContentResponse(promptFeedback: promptFeedback)

      do {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
        Issue.record("Expected refusal error to be thrown")
      } catch let LanguageModelError.refusal(refusal) {
        let content = try await refusal.explanation.content
        let blockReason = try #require(promptFeedback.blockReason)
        #expect(content.contains("\(blockReason)"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsThrowsForCandidateSafety() throws {
      let candidate = Candidate(
        finishReason: .safety,
        finishMessage: "Safety policy triggered"
      )
      let chunk = GenerateContentResponse(candidates: [candidate])

      do {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
        Issue.record("Expected guardrailViolation error to be thrown")
      } catch let LanguageModelError.guardrailViolation(violation) {
        let finishMessage = try #require(candidate.finishMessage)
        #expect(violation.debugDescription.contains(finishMessage))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsThrowsRefusalForCandidateRecitation() async throws {
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
        let finishMessage = try #require(candidate.finishMessage)
        #expect(content.contains(finishMessage))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsThrowsUnsupportedLanguageForCandidateLanguage() throws {
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
        let finishMessage = try #require(candidate.finishMessage)
        #expect(unsupported.debugDescription == finishMessage)
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsPassesForSafeContent() throws {
      let candidate = Candidate(finishReason: .stop)
      let chunk = GenerateContentResponse(candidates: [candidate])

      try GeminiErrorMapper.checkGuardrails(in: chunk)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func apiErrorDebugDescription() {
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
      #expect(errorWithCode.code == "invalid_request")
      #expect(errorWithCode.statusCode == 400)
      #expect(errorWithCode.message == "Invalid parameter")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapRateLimitFromHTTP429() {
      let mappedError = GeminiErrorMapper.map(
        GeminiAPIError.httpError(statusCode: 429, body: "Too many requests")
      )

      if case LanguageModelError.rateLimited(let rateLimited) = mappedError {
        #expect(rateLimited.debugDescription.contains("429"))
      } else {
        Issue.record("Expected LanguageModelError.rateLimited")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mapModelNotFoundFromHTTP404() {
      let mappedError = GeminiErrorMapper.map(
        GeminiAPIError.httpError(statusCode: 404, body: "Not found")
      )

      if case GeminiLanguageModel.Error.modelNotFound(let modelNotFound) = mappedError {
        #expect(modelNotFound.debugDescription.contains("404"))
      } else {
        Issue.record("Expected GeminiLanguageModel.Error.modelNotFound")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func checkGuardrailsThrowsRefusalForCandidateOtherWithoutMessage() {
      let candidate = Candidate(finishReason: .other)
      let chunk = GenerateContentResponse(candidates: [candidate])

      #expect(throws: LanguageModelError.self) {
        try GeminiErrorMapper.checkGuardrails(in: chunk)
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
