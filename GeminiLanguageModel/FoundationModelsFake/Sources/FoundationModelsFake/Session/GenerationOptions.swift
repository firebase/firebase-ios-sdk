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
  /// Configuration options that control response generation and sampling behavior.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`GenerationOptions`](https://developer.apple.com/documentation/foundationmodels/generationoptions).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GenerationOptions: Sendable, Equatable {
    /// The sampling mode used to select tokens during generation.
    public var samplingMode: GenerationOptions.SamplingMode?

    /// The sampling temperature used to control randomness during generation.
    public var temperature: Double?

    /// The maximum number of tokens to generate for a response.
    public var maximumResponseTokens: Int?

    /// The policy controlling how the model may invoke tools during generation.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public var toolCallingMode: GenerationOptions.ToolCallingMode?

    /// Creates generation options with the specified sampling mode, temperature, and token limit.
    ///
    /// - Parameters:
    ///   - samplingMode: The strategy for sampling candidate tokens, or `nil` for model default.
    ///   - temperature: The randomness parameter, or `nil` for model default.
    ///   - maximumResponseTokens: The maximum tokens to produce, or `nil` for model default.
    public init(
      samplingMode: GenerationOptions.SamplingMode? = nil,
      temperature: Double? = nil,
      maximumResponseTokens: Int? = nil
    ) {
      self.samplingMode = samplingMode
      self.temperature = temperature
      self.maximumResponseTokens = maximumResponseTokens
      self.toolCallingMode = nil
    }
  }

  extension GenerationOptions {
    /// Creates generation options including tool calling configuration.
    ///
    /// - Parameters:
    ///   - samplingMode: The strategy for sampling candidate tokens, or `nil` for model default.
    ///   - temperature: The randomness parameter, or `nil` for model default.
    ///   - maximumResponseTokens: The maximum tokens to produce, or `nil` for model default.
    ///   - toolCallingMode: The tool calling mode, or `nil` for model default.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(
      samplingMode: GenerationOptions.SamplingMode? = nil,
      temperature: Double? = nil,
      maximumResponseTokens: Int? = nil,
      toolCallingMode: GenerationOptions.ToolCallingMode?
    ) {
      self.samplingMode = samplingMode
      self.temperature = temperature
      self.maximumResponseTokens = maximumResponseTokens
      self.toolCallingMode = toolCallingMode
    }
  }

  extension GenerationOptions {
    /// The strategy used to sample candidate tokens during generation.
    ///
    /// - SeeAlso: [`GenerationOptions.SamplingMode`](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode)
    public struct SamplingMode: Sendable, Equatable {
      /// The underlying sampling algorithm and parameters.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public let kind: GenerationOptions.SamplingMode.Kind
    }
  }

  extension GenerationOptions.SamplingMode {
    /// A sampling mode that selects the highest-probability token at each step.
    public static var greedy: GenerationOptions.SamplingMode {
      GenerationOptions.SamplingMode(kind: .greedy)
    }

    /// Creates a sampling mode that selects randomly from the top-k highest probability tokens.
    ///
    /// - Parameters:
    ///   - k: The number of highest probability candidate tokens to consider.
    ///   - seed: An optional random seed for reproducible sampling.
    /// - Returns: A sampling mode configured for top-k random sampling.
    public static func random(top k: Int, seed: UInt64? = nil) -> GenerationOptions.SamplingMode {
      GenerationOptions.SamplingMode(kind: .randomTopK(k, seed: seed))
    }

    /// Creates a sampling mode that selects randomly from tokens within a cumulative probability.
    ///
    /// - Parameters:
    ///   - probabilityThreshold: The cumulative probability threshold for candidate tokens.
    ///   - seed: An optional random seed for reproducible sampling.
    /// - Returns: A sampling mode configured for nucleus sampling.
    public static func random(
      probabilityThreshold: Double,
      seed: UInt64? = nil
    ) -> GenerationOptions.SamplingMode {
      GenerationOptions.SamplingMode(
        kind: .randomProbabilityThreshold(probabilityThreshold, seed: seed))
    }
  }

  extension GenerationOptions.SamplingMode {
    /// The kind of sampling algorithm applied during generation.
    ///
    /// - SeeAlso: [`GenerationOptions.SamplingMode.Kind`](https://developer.apple.com/documentation/foundationmodels/generationoptions/samplingmode/kind)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public enum Kind: Sendable, Equatable {
      /// Greedy token selection choosing the highest-probability token.
      case greedy

      /// Random token selection restricted to the top-k candidate tokens with an optional seed.
      case randomTopK(_: Int, seed: UInt64?)

      /// Random token selection restricted to tokens within a cumulative probability threshold.
      case randomProbabilityThreshold(_: Double, seed: UInt64?)
    }
  }

  extension GenerationOptions {
    /// The mode determining whether and how tools may be invoked during generation.
    ///
    /// - SeeAlso: [`GenerationOptions.ToolCallingMode`](https://developer.apple.com/documentation/foundationmodels/generationoptions/toolcallingmode)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct ToolCallingMode: Sendable, Equatable {
      /// The underlying tool calling behavior.
      public var kind: GenerationOptions.ToolCallingMode.Kind

      /// A mode where the model may choose whether to invoke tools.
      public static let allowed = GenerationOptions.ToolCallingMode(kind: .allowed)

      /// A mode where the model is required to invoke a tool.
      public static let required = GenerationOptions.ToolCallingMode(kind: .required)

      /// A mode where tool invocation is disabled.
      public static let disallowed = GenerationOptions.ToolCallingMode(kind: .disallowed)
    }
  }

  extension GenerationOptions.ToolCallingMode {
    /// The kind of tool calling behavior allowed during generation.
    ///
    /// - SeeAlso: [`GenerationOptions.ToolCallingMode.Kind`](https://developer.apple.com/documentation/foundationmodels/generationoptions/toolcallingmode/kind)
    public enum Kind: Sendable, Equatable {
      /// The model may choose whether to invoke tools.
      case allowed

      /// The model must invoke at least one tool.
      case required

      /// The model cannot invoke tools.
      case disallowed
    }
  }

  extension GenerationOptions.ToolCallingMode.Kind: Hashable {}
#endif  // compiler(>=6.4)
