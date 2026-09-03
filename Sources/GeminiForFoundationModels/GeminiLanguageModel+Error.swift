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
  public import Foundation

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel {
    /// Errors specific to the Gemini language model.
    @nonexhaustive
    public enum Error: Sendable, LocalizedError, CustomDebugStringConvertible, Equatable {
      /// An error that occurs when the Gemini service is temporarily unavailable.
      case serviceUnavailable(ServiceUnavailable)

      /// An error that occurs when network communication with the Gemini service fails.
      case networkFailure(NetworkFailure)

      /// An error that occurs when the specified model resource could not be found.
      case modelNotFound(ModelNotFound)

      /// An error returned by the Gemini API indicating a client or request failure.
      case apiError(APIError)

      // MARK: - Payload Structures

      /// Information about the Gemini service being temporarily unavailable.
      public struct ServiceUnavailable: Sendable, Equatable, CustomDebugStringConvertible {
        /// A debug description of the service unavailability.
        public let debugDescription: String

        /// Creates a service unavailable error instance.
        ///
        /// - Parameter debugDescription: A debug description of the failure.
        public init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      /// Information about a network failure when communicating with the Gemini service.
      public struct NetworkFailure: Sendable, Equatable, CustomDebugStringConvertible {
        /// A debug description of the network failure.
        public let debugDescription: String

        /// Creates a network failure error instance.
        ///
        /// - Parameter debugDescription: A debug description of the failure.
        public init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      /// Information about a requested model resource that could not be found.
      public struct ModelNotFound: Sendable, Equatable, CustomDebugStringConvertible {
        /// The name or identifier of the model that was not found, if known.
        public let modelName: String?

        /// A debug description of the model not found error.
        public let debugDescription: String

        /// Creates a model not found error instance.
        ///
        /// - Parameters:
        ///   - modelName: The name or identifier of the model, if known.
        ///   - debugDescription: A debug description of the failure.
        public init(modelName: String? = nil, debugDescription: String) {
          self.modelName = modelName
          self.debugDescription = debugDescription
        }
      }

      /// Information about an error returned by the Gemini API.
      public struct APIError: Sendable, Equatable, CustomDebugStringConvertible {
        /// The machine-readable error code (e.g. "invalid_request", "PERMISSION_DENIED").
        public let code: String

        /// The HTTP status code value, if available.
        public let statusCode: Int?

        /// A human-readable description of what went wrong.
        public let message: String

        /// Additional metadata and context about the error.
        public let metadata: [String: any Sendable]

        public var debugDescription: String {
          if let statusCode {
            return "Gemini API error (\(code), HTTP \(statusCode)): \(message)"
          }
          return "Gemini API error (\(code)): \(message)"
        }

        /// Creates an API error instance.
        ///
        /// - Parameters:
        ///   - code: The machine-readable error code.
        ///   - statusCode: The HTTP status code value, if available.
        ///   - message: A human-readable description of what went wrong.
        ///   - metadata: Additional metadata and context about the error.
        public init(
          code: String,
          statusCode: Int? = nil,
          message: String,
          metadata: [String: any Sendable] = [:]
        ) {
          self.code = code
          self.statusCode = statusCode
          self.message = message
          self.metadata = metadata
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
          lhs.code == rhs.code && lhs.statusCode == rhs.statusCode && lhs.message == rhs.message
            && NSDictionary(dictionary: lhs.metadata).isEqual(to: rhs.metadata)
        }
      }

      // MARK: - LocalizedError & CustomDebugStringConvertible

      public var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let serviceUnavailable):
          serviceUnavailable.debugDescription
        case .networkFailure(let networkFailure):
          networkFailure.debugDescription
        case .modelNotFound(let modelNotFound):
          modelNotFound.debugDescription
        case .apiError(let apiError):
          apiError.debugDescription
        }
      }

      public var debugDescription: String {
        errorDescription ?? "GeminiLanguageModel.Error"
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
