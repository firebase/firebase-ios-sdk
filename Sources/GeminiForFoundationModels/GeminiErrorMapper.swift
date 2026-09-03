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
    /// Maps an underlying error to a corresponding `LanguageModelError` or
    /// `GeminiLanguageModel.Error`.
    ///
    /// - Parameter error: The error to map.
    /// - Returns: The mapped error, or `GeminiLanguageModel.Error.networkFailure` if no specific
    ///   mapping exists.
    static func map(_ error: any Error) -> any Error {
      switch error {
      case let error as LanguageModelError:
        return error

      case is CancellationError:
        return error

      case let error as GeminiLanguageModel.Error:
        return error

      case GeminiAPIError.apiError(let apiError):
        if apiError.code == 429 || apiError.status == .resourceExhausted {
          let resetDate = apiError.retryDelay.map {
            Date.now.addingTimeInterval(Double($0.components.seconds))
          }
          return LanguageModelError.rateLimited(
            LanguageModelError.RateLimited(
              resetDate: resetDate,
              debugDescription: apiError.message
            )
          )
        } else if apiError.code == 503 || apiError.status == .unavailable {
          return GeminiLanguageModel.Error.serviceUnavailable(
            GeminiLanguageModel.Error.ServiceUnavailable(
              debugDescription: apiError.message
            )
          )
        } else if apiError.code == 404 || apiError.status == .notFound,
          apiError.message.localizedCaseInsensitiveContains("model")
        {
          return GeminiLanguageModel.Error.modelNotFound(
            GeminiLanguageModel.Error.ModelNotFound(
              debugDescription: apiError.message
            )
          )
        }

        var metadata: [String: any Sendable] = [:]
        if let status = apiError.status?.rawValue {
          metadata["status"] = status
        }

        let code = apiError.status?.rawValue ?? "\(apiError.code)"
        return GeminiLanguageModel.Error.apiError(
          GeminiLanguageModel.Error.APIError(
            code: code,
            statusCode: apiError.code,
            message: apiError.message,
            metadata: metadata
          )
        )

      case GeminiAPIError.httpError(let statusCode, let body):
        switch statusCode {
        case 429:
          return LanguageModelError.rateLimited(
            LanguageModelError.RateLimited(
              resetDate: nil,
              debugDescription: "HTTP 429: \(body)"
            )
          )
        case 404:
          return GeminiLanguageModel.Error.modelNotFound(
            GeminiLanguageModel.Error.ModelNotFound(
              debugDescription: "HTTP 404: \(body)"
            )
          )
        case 503:
          return GeminiLanguageModel.Error.serviceUnavailable(
            GeminiLanguageModel.Error.ServiceUnavailable(
              debugDescription: "Gemini service is unavailable (HTTP 503): \(body)"
            )
          )
        default:
          return GeminiLanguageModel.Error.networkFailure(
            GeminiLanguageModel.Error.NetworkFailure(
              debugDescription: "Gemini HTTP error (status \(statusCode)): \(body)"
            )
          )
        }

      case let urlError as URLError:
        switch urlError.code {
        case .timedOut:
          return LanguageModelError.timeout(
            LanguageModelError.Timeout(debugDescription: urlError.localizedDescription)
          )
        default:
          return GeminiLanguageModel.Error.networkFailure(
            GeminiLanguageModel.Error.NetworkFailure(
              debugDescription: urlError.localizedDescription
            )
          )
        }

      default:
        return GeminiLanguageModel.Error.networkFailure(
          GeminiLanguageModel.Error.NetworkFailure(
            debugDescription: error.localizedDescription
          )
        )
      }
    }

    /// Checks the given response chunk for guardrail violations or model refusals.
    ///
    /// - Parameter chunk: The response chunk from the Gemini API.
    /// - Throws: `LanguageModelError.guardrailViolation` or `LanguageModelError.refusal` if a
    ///   block reason or refusal finish reason is present.
    static func checkGuardrails(in chunk: GenerateContentResponse) throws {
      if let promptFeedback = chunk.promptFeedback,
        let blockReason = promptFeedback.blockReason
      {
        switch blockReason {
        case .safety, .blocklist, .prohibitedContent, .imageSafety:
          throw LanguageModelError.guardrailViolation(
            LanguageModelError.GuardrailViolation(
              debugDescription: "Gemini blocked the prompt: \(blockReason)"
            )
          )
        case .other:
          throw LanguageModelError.refusal(
            LanguageModelError.Refusal(
              explanation: "The model declined to answer this request (\(blockReason)).",
              debugDescription: "Gemini prompt was blocked: \(blockReason)"
            )
          )
        case .unrecognized(let rawValue):
          throw LanguageModelError.guardrailViolation(
            LanguageModelError.GuardrailViolation(
              debugDescription: "Gemini blocked the prompt: \(rawValue)"
            )
          )
        }
      }

      guard let candidate = chunk.candidates?.first,
        let finishReason = candidate.finishReason
      else {
        return
      }

      let message = candidate.finishMessage

      switch finishReason {
      case .safety, .blocklist, .prohibitedContent, .spii, .imageSafety, .imageProhibitedContent,
        .imageOther:
        throw LanguageModelError.guardrailViolation(
          LanguageModelError.GuardrailViolation(
            debugDescription: message ?? "Content generation blocked by safety filters."
          )
        )
      case .recitation, .imageRecitation:
        throw LanguageModelError.refusal(
          LanguageModelError.Refusal(
            explanation: message ?? "Content generation blocked by recitation check.",
            debugDescription: message ?? "Recitation check failed."
          )
        )
      case .escalation, .other:
        throw LanguageModelError.refusal(
          LanguageModelError.Refusal(
            explanation: message ?? "The model declined to generate a response.",
            debugDescription: message ?? "Content generation declined by the model."
          )
        )
      case .language:
        throw LanguageModelError.unsupportedLanguageOrLocale(
          LanguageModelError.UnsupportedLanguageOrLocale(
            languageCode: Locale.LanguageCode("und"),
            debugDescription: message ?? "Unsupported language or locale."
          )
        )
      default:
        break
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
