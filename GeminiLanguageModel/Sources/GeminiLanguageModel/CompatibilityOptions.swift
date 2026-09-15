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
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel {
    /// Options for configuring compatibility with the Gemini API.
    ///
    /// Allows an app to adapt to backend behavioral changes without waiting for an SDK release.
    /// Generation parameters are configured in `GenerationOptions`, while per-tool settings are
    /// configured on the tool itself.
    public struct CompatibilityOptions: Hashable, Sendable {
      /// Overrides for how tool calling is expressed to the Gemini API.
      public var toolCalling = ToolCalling()

      /// Overrides for how guided generation is expressed to the Gemini API.
      public var guidedGeneration = GuidedGeneration()

      /// Creates options with the recommended defaults.
      public init() {}
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel.CompatibilityOptions {
    /// Overrides for how tool calling is expressed to the Gemini API.
    public struct ToolCalling: Hashable, Sendable {
      /// The Gemini function calling mode used when tool calling is allowed or unspecified.
      ///
      /// Defaults to ``AllowedMode/validated``.
      public var allowedMode: AllowedMode = .validated

      /// Creates tool calling overrides with the recommended defaults.
      public init() {}
    }

    /// The Gemini function calling mode used when tool calling is allowed or unspecified.
    @nonexhaustive
    public enum AllowedMode: Hashable, Sendable {
      /// Constrains decoding so tool calls conform to their schema.
      ///
      /// This is the default and reduces malformed tool calls.
      case validated

      /// Leaves tool call decoding unconstrained.
      ///
      /// Use this only if ``validated`` causes the backend to reject a large or deeply nested
      /// tool schema. If you encounter schema rejection, please file an issue on GitHub.
      case auto
    }

    /// Overrides for how guided generation is expressed to the Gemini API.
    public struct GuidedGeneration: Hashable, Sendable {
      /// The Gemini API payload format used to transmit schemas for guided generation.
      ///
      /// Defaults to ``SchemaFormat/responseJsonSchema``.
      public var schemaFormat: SchemaFormat = .responseJsonSchema

      /// Creates guided generation overrides with the recommended defaults.
      public init() {}
    }

    /// The Gemini API payload format used to transmit schemas for guided generation.
    @nonexhaustive
    public enum SchemaFormat: Hashable, Sendable {
      /// Transmits the schema using `responseJsonSchema` and `responseMimeType: "application/json"`.
      ///
      /// This is the default. It ensures full compatibility when tool calling is enabled
      /// in ``ToolCalling/allowedMode`` ``AllowedMode/validated``.
      case responseJsonSchema

      /// Transmits the schema using `responseFormat`.
      ///
      /// Note: The Gemini API currently ignores `responseFormat` when function calling is
      /// configured in ``AllowedMode/validated`` mode, causing the model to emit unconstrained
      /// text instead of valid JSON.
      case responseFormat
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
