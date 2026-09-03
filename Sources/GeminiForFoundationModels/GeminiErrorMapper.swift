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

  /// Maps Gemini API and network errors to `FoundationModels.LanguageModelError` or
  /// `GeminiLanguageModel.Error`.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiErrorMapper {
    /// Maps an underlying error to a corresponding `LanguageModelError` or `GeminiLanguageModel.Error`.
    ///
    /// - Parameter error: The error to map.
    /// - Returns: The mapped error, or `GeminiLanguageModel.Error.networkFailure` if no specific
    ///   mapping exists.
    static func map(_ error: any Error) -> any Error {
      if let error = error as? LanguageModelError {
        return error
      }
      if error is CancellationError {
        return error
      }
      if let error = error as? GeminiLanguageModel.Error {
        return error
      }

      if case GeminiAPIError.apiError(let apiError) = error {
        if apiError.code == 429 || apiError.status == .resourceExhausted {
          let resetDate = apiError.retryDelay.map {
            Date.now.addingTimeInterval(Double($0.components.seconds))
          }
          return LanguageModelError.rateLimited(
            .init(resetDate: resetDate, debugDescription: apiError.message)
          )
        }

        if apiError.code == 503 || apiError.status == .unavailable {
          return GeminiLanguageModel.Error.serviceUnavailable(
            .init(debugDescription: apiError.message)
          )
        }

        if apiError.code == 404 || apiError.status == .notFound {
          if apiError.message.localizedCaseInsensitiveContains("model") {
            return GeminiLanguageModel.Error.modelNotFound(
              .init(debugDescription: apiError.message)
            )
          }
        }

        var metadata: [String: any Sendable] = [:]
        if let status = apiError.status?.rawValue {
          metadata["status"] = status
        }

        let code = apiError.status?.rawValue ?? "\(apiError.code)"
        return GeminiLanguageModel.Error.apiError(
          .init(
            code: code,
            statusCode: apiError.code,
            message: apiError.message,
            metadata: metadata
          )
        )
      }

      if case GeminiAPIError.httpError(let statusCode, let body) = error {
        if statusCode == 503 {
          return GeminiLanguageModel.Error.serviceUnavailable(
            .init(debugDescription: "Gemini service is unavailable (HTTP 503): \(body)")
          )
        }
        return GeminiLanguageModel.Error.networkFailure(
          .init(debugDescription: "Gemini HTTP error (status \(statusCode)): \(body)")
        )
      }

      if let urlError = error as? URLError {
        if urlError.code == .timedOut {
          return LanguageModelError.timeout(.init(debugDescription: urlError.localizedDescription))
        }
        return GeminiLanguageModel.Error.networkFailure(
          .init(debugDescription: urlError.localizedDescription)
        )
      }

      return GeminiLanguageModel.Error.networkFailure(
        .init(debugDescription: error.localizedDescription)
      )
    }

    /// Checks the given response chunk for guardrail violations or model refusals.
    ///
    /// - Parameter chunk: The content response chunk to validate.
    /// - Throws: `LanguageModelError.guardrailViolation` if safety filters blocked generation,
    ///   `LanguageModelError.refusal` if the model declined for non-safety reasons, or
    ///   `LanguageModelError.unsupportedLanguageOrLocale` if the prompt language is unsupported.
    static func checkGuardrails(in chunk: GenerateContentResponse) throws {
      if let promptFeedback = chunk.promptFeedback,
        let blockReason = promptFeedback.blockReason
      {
        switch blockReason {
        case .safety, .blocklist, .prohibitedContent, .imageSafety:
          throw LanguageModelError.guardrailViolation(
            .init(debugDescription: "Gemini blocked the prompt: \(blockReason)")
          )
        case .other:
          throw LanguageModelError.refusal(
            .init(
              explanation: "The model declined to answer this request (\(blockReason)).",
              debugDescription: "Gemini prompt was blocked: \(blockReason)"
            )
          )
        case .unrecognized(let rawValue):
          throw LanguageModelError.guardrailViolation(
            .init(debugDescription: "Gemini blocked the prompt: \(rawValue)")
          )
        }
      }

      guard let candidate = chunk.candidates?.first else {
        return
      }

      if let finishReason = candidate.finishReason {
        let message = candidate.finishMessage

        switch finishReason {
        case .safety, .blocklist, .prohibitedContent, .spii, .imageSafety, .imageProhibitedContent,
          .imageOther:
          throw LanguageModelError.guardrailViolation(
            .init(debugDescription: message ?? "Content generation blocked by safety filters.")
          )
        case .recitation:
          throw LanguageModelError.refusal(
            .init(
              explanation: message ?? "Content generation blocked by recitation check.",
              debugDescription: message ?? "Recitation check failed."
            )
          )
        case .escalation, .other:
          if let message {
            throw LanguageModelError.refusal(
              .init(explanation: message, debugDescription: message)
            )
          }
        case .language:
          throw LanguageModelError.unsupportedLanguageOrLocale(
            .init(
              languageCode: Locale.LanguageCode("und"),
              debugDescription: message ?? "Unsupported language or locale."
            )
          )
        default:
          break
        }
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
