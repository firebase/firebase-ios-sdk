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

#if compiler(>=6.4)
  /// Options for configuring context behavior during model generation.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`ContextOptions`](https://developer.apple.com/documentation/foundationmodels/contextoptions).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct ContextOptions: Sendable, Equatable {
    /// Whether to include the response schema in the prompt text.
    public var includeSchemaInPrompt: Bool?

    /// The requested reasoning level for model generation.
    public var reasoningLevel: ContextOptions.ReasoningLevel?

    /// Creates context options with the specified configuration.
    ///
    /// - Parameters:
    ///   - includeSchemaInPrompt: Whether to include the response schema in the prompt.
    ///   - reasoningLevel: The desired reasoning level for model generation.
    public init(
      includeSchemaInPrompt: Bool? = nil,
      reasoningLevel: ContextOptions.ReasoningLevel? = nil
    ) {
      self.includeSchemaInPrompt = includeSchemaInPrompt
      self.reasoningLevel = reasoningLevel
    }
  }

  extension ContextOptions {
    /// The level of reasoning effort requested from a model.
    ///
    /// - SeeAlso: [`ContextOptions.ReasoningLevel`](https://developer.apple.com/documentation/foundationmodels/contextoptions/reasoninglevel)
    public enum ReasoningLevel: Sendable, Equatable {
      /// A light reasoning effort level.
      case light

      /// A moderate reasoning effort level.
      case moderate

      /// A deep reasoning effort level.
      case deep

      /// A custom reasoning level specified by name.
      case custom(String)
    }
  }
#endif  // compiler(>=6.4)
