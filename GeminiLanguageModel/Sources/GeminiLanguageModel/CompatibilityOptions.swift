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
    /// Overrides for behavior that depends on current Gemini backend semantics.
    ///
    /// These exist so an app can respond to a change in backend behavior without
    /// waiting for an SDK release. Generation parameters belong in
    /// `GenerationOptions`; per-tool settings belong on the tool itself.
    public struct CompatibilityOptions: Hashable, Sendable {
      /// Overrides for how tool calling is expressed to the Gemini API.
      public var toolCalling = ToolCalling()

      /// Creates options with the recommended defaults.
      public init() {}
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel.CompatibilityOptions {
    /// Overrides for how tool calling is expressed to the Gemini API.
    public struct ToolCalling: Hashable, Sendable {
      /// The Gemini function calling mode used when tool calling is allowed.
      ///
      /// Defaults to ``AllowedMode/validated``.
      public var allowedMode: AllowedMode = .validated

      /// Creates tool calling overrides with the recommended defaults.
      public init() {}
    }

    /// The Gemini function calling mode used when tool calling is allowed.
    @nonexhaustive
    public enum AllowedMode: Hashable, Sendable {
      /// Constrains decoding so tool calls conform to their schema.
      ///
      /// This is the default and reduces malformed tool calls.
      case validated

      /// Leaves tool call decoding unconstrained.
      ///
      /// Use this only if ``validated`` causes the backend to reject a large or
      /// deeply nested tool schema. If you need this, please file an issue —
      /// we would like to reproduce the rejection and cover it with a test.
      case auto
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
