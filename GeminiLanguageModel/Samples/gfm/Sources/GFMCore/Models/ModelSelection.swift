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

public import ArgumentParser
import Foundation

#if canImport(FoundationModels) && compiler(>=6.4)
  public import FoundationModels
  public import GeminiLanguageModel

  /// Supported model families for the `gfm` command-line utility.
  public enum ModelChoice: String, ExpressibleByArgument, CaseIterable, Sendable {
    case gemini
    case system

    /// Short human-readable display name for this model choice.
    public var displayName: String {
      switch self {
      case .gemini:
        return "Gemini model"
      case .system:
        return "System model"
      }
    }
  }

  /// Availability status for a model evaluated by `gfm`.
  public enum ModelAvailabilityStatus: Sendable, Equatable {
    case available
    case unavailable(reason: String)

    public var isAvailable: Bool {
      if case .available = self {
        return true
      }
      return false
    }
  }

  /// Helper for configuring and resolving language models from CLI options and environment.
  public struct ModelResolver: Sendable {
    /// Default Gemini model ID.
    public static let defaultGeminiModelID = "gemini-3.5-flash-lite"

    /// The selected model family. Defaults to `.gemini`.
    public var choice: ModelChoice

    /// Custom Gemini model ID override.
    public var geminiModelID: String

    /// Optional explicit API key passed via `--api-key`.
    public var explicitAPIKey: String?

    /// Initializes a new model resolver with the given options.
    ///
    /// - Parameters:
    ///   - choice: The model family to use. Defaults to `.gemini`.
    ///   - geminiModelID: The model identifier to use when targetting Gemini. Defaults to
    ///     `"gemini-3.5-flash-lite"`.
    ///   - explicitAPIKey: An optional explicit API key.
    public init(
      choice: ModelChoice = .gemini,
      geminiModelID: String = defaultGeminiModelID,
      explicitAPIKey: String? = nil
    ) {
      self.choice = choice
      self.geminiModelID = geminiModelID
      self.explicitAPIKey = explicitAPIKey
    }

    /// Resolves the effective Gemini API key from explicit options or environment variables.
    ///
    /// - Returns: The resolved API key, or `nil` if not configured.
    public func resolveAPIKey() -> String? {
      if let explicitAPIKey, !explicitAPIKey.isEmpty {
        return explicitAPIKey
      }
      let env = ProcessInfo.processInfo.environment
      if let envKey = env["GEMINI_API_KEY"], !envKey.isEmpty {
        return envKey
      }
      if let googleKey = env["GOOGLE_API_KEY"], !googleKey.isEmpty {
        return googleKey
      }
      return nil
    }

    /// Checks the availability of the specified model choice.
    ///
    /// - Parameter targetChoice: The model choice to check.
    /// - Returns: The availability status.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    public func checkAvailability(for targetChoice: ModelChoice) -> ModelAvailabilityStatus {
      switch targetChoice {
      case .gemini:
        if resolveAPIKey() != nil {
          return .available
        } else {
          return .unavailable(reason: "missingAPIKey")
        }

      case .system:
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
          return .available
        case .unavailable(let reason):
          switch reason {
          case .deviceNotEligible:
            return .unavailable(reason: "deviceNotEligible")
          case .appleIntelligenceNotEnabled:
            return .unavailable(reason: "appleIntelligenceNotEnabled")
          case .modelNotReady:
            return .unavailable(reason: "modelNotReady")
          @unknown default:
            return .unavailable(reason: "unknownReason")
          }
        }
      }
    }

    /// Instantiates the configured `LanguageModel` instance.
    ///
    /// - Returns: An instance conforming to `LanguageModel`.
    /// - Throws: `ValidationError` if the model cannot be initialized (e.g. missing API key).
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    public func makeModel() throws -> any LanguageModel {
      switch choice {
      case .gemini:
        guard let apiKey = resolveAPIKey() else {
          throw ValidationError(
            "Gemini API key is required. Provide --api-key or set GEMINI_API_KEY (or GOOGLE_API_KEY)."
          )
        }
        if let explicitAPIKey, !explicitAPIKey.isEmpty {
          setenv("GEMINI_API_KEY", explicitAPIKey, 1)
        }
        return GeminiLanguageModel(modelID: geminiModelID)

      case .system:
        return SystemLanguageModel.default
      }
    }
  }
#endif
