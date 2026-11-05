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
  /// A set of capabilities supported by a language model.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModelCapabilities`](https://developer.apple.com/documentation/foundationmodels/languagemodelcapabilities).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct LanguageModelCapabilities: Sendable {
    /// The set of supported capabilities.
    let capabilities: Set<Capability>

    /// Creates a capabilities set with the specified array of capabilities.
    ///
    /// - Parameter capabilities: The capabilities supported by the model.
    public init(_ capabilities: [LanguageModelCapabilities.Capability]) {
      self.capabilities = Set(capabilities)
    }
  }

  extension LanguageModelCapabilities {
    /// Returns whether the capabilities set contains the specified capability.
    ///
    /// - Parameter capability: The capability to test for membership.
    /// - Returns: `true` if `capability` is supported; otherwise, `false`.
    public func contains(_ capability: LanguageModelCapabilities.Capability) -> Bool {
      capabilities.contains(capability)
    }
  }

  extension LanguageModelCapabilities {
    /// A capability that a language model can support.
    ///
    /// - SeeAlso: [`LanguageModelCapabilities.Capability`](https://developer.apple.com/documentation/foundationmodels/languagemodelcapabilities/capability)
    public struct Capability: Sendable, Hashable {
      /// The kinds of capability a language model can declare.
      enum Kind: Sendable, Hashable {
        /// Accepts image inputs in prompts.
        case vision
        /// Conforms output to a generation schema.
        case guidedGeneration
        /// Reasons separately from producing a response.
        case reasoning
        /// Calls tools.
        case toolCalling
      }

      /// The kind of this capability.
      let kind: Kind
    }
  }

  extension LanguageModelCapabilities.Capability {
    /// The capability to process image inputs in prompts.
    public static var vision: LanguageModelCapabilities.Capability {
      LanguageModelCapabilities.Capability(kind: .vision)
    }

    /// The capability to constrain output to a generation schema.
    public static var guidedGeneration: LanguageModelCapabilities.Capability {
      LanguageModelCapabilities.Capability(kind: .guidedGeneration)
    }

    /// The capability to produce reasoning traces separately from response text.
    public static var reasoning: LanguageModelCapabilities.Capability {
      LanguageModelCapabilities.Capability(kind: .reasoning)
    }

    /// The capability to invoke tools during generation.
    public static var toolCalling: LanguageModelCapabilities.Capability {
      LanguageModelCapabilities.Capability(kind: .toolCalling)
    }
  }
#endif  // compiler(>=6.4)
