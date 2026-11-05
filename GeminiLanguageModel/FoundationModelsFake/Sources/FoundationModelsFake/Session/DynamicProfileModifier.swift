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
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - DynamicProfileModifier

  extension LanguageModelSession {
    /// A modifier that transforms a dynamic profile.
    ///
    /// - SeeAlso: [`LanguageModelSession.DynamicProfileModifier`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofilemodifier)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public protocol DynamicProfileModifier {
      /// The type of dynamic profile produced by modifying content.
      associatedtype Body: LanguageModelSession.DynamicProfile

      /// Transforms the given profile content into a modified dynamic profile.
      ///
      /// - Parameter content: The dynamic profile content to modify.
      /// - Returns: The modified dynamic profile.
      @LanguageModelSession.DynamicProfileBuilder
      func body(content: Self.Content) -> Self.Body
    }
  }

  extension LanguageModelSession.DynamicProfileModifier {
    /// An alias for the content proxy passed to a profile modifier.
    public typealias Content = LanguageModelSession.DynamicProfileModifierContent<Self>

    /// An alias for the dynamic profile protocol within a profile modifier.
    public typealias DynamicProfile = LanguageModelSession.DynamicProfile

    /// An alias for the session property wrapper within a profile modifier.
    public typealias SessionProperty = LanguageModelSession.SessionProperty
  }

  // MARK: - DynamicProfileModifierContent & ModifiedDynamicProfile

  extension LanguageModelSession {
    /// A proxy representing dynamic profile content supplied to a profile modifier.
    ///
    /// - SeeAlso: [`LanguageModelSession.DynamicProfileModifierContent`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofilemodifiercontent)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct DynamicProfileModifierContent<
      Modifier: LanguageModelSession.DynamicProfileModifier
    >: LanguageModelSession.DynamicProfile {
      /// The type of dynamic profile representing the body of this modifier content.
      public typealias Body = Never

      /// The underlying type-erased profile node wrapped by this content proxy.
      internal let base: any LanguageModelSession.DynamicProfile

      /// Creates a modifier content proxy wrapping `base`.
      ///
      /// - Parameter base: The underlying dynamic profile content.
      internal init(base: any LanguageModelSession.DynamicProfile) {
        self.base = base
      }

      /// The content and behavior of the dynamic profile.
      public var body: Never {
        fatalError("DynamicProfileModifierContent.body should not be called.")
      }
    }

    /// A dynamic profile that applies a modifier to an underlying profile.
    ///
    /// - SeeAlso: [`LanguageModelSession.ModifiedDynamicProfile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/modifieddynamicprofile)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct ModifiedDynamicProfile<
      Content: LanguageModelSession.DynamicProfile,
      Modifier: LanguageModelSession.DynamicProfileModifier
    >: LanguageModelSession.DynamicProfile {
      /// The type of dynamic profile representing the body of this modified profile.
      public typealias Body = Never

      /// The underlying dynamic profile content.
      internal let content: Content

      /// The modifier applied to `content`.
      internal let modifier: Modifier

      /// Creates a modified dynamic profile from `content` and `modifier`.
      ///
      /// - Parameters:
      ///   - content: The underlying dynamic profile content.
      ///   - modifier: The modifier to apply to `content`.
      internal init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
      }

      /// The content and behavior of the dynamic profile.
      public var body: Never {
        fatalError("ModifiedDynamicProfile.body should not be called.")
      }
    }
  }

  extension LanguageModelSession.DynamicProfileModifierContent: _DynamicProfilePrimitive {
    /// Evaluates the underlying dynamic profile wrapped by this modifier content proxy.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      func openAndEvaluate<T: LanguageModelSession.DynamicProfile>(_ wrapped: T) {
        DynamicProfileEvaluator.evaluateNode(wrapped, into: &context)
      }
      openAndEvaluate(base)
    }
  }

  extension LanguageModelSession.ModifiedDynamicProfile: _DynamicProfilePrimitive {
    /// Binds `@SessionProperty` wrappers on `modifier` and evaluates `modifier.body(content:)`.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      SessionPropertyBinder.bind(modifier, to: context.properties)
      let proxy = LanguageModelSession.DynamicProfileModifierContent<Modifier>(base: content)
      context.currentPath.append(.modifierType(ObjectIdentifier(Modifier.self)))
      let modifiedBody = modifier.body(content: proxy)
      DynamicProfileEvaluator.evaluateNode(modifiedBody, into: &context)
      context.currentPath.removeLast()
    }
  }

  // MARK: - Internal Configuration Modifier Primitives

  /// Internal profile wrapper that sets a language model on the underlying profile.
  internal struct _ModelDynamicProfile<Base: LanguageModelSession.DynamicProfile>:
    LanguageModelSession.DynamicProfile, _DynamicProfilePrimitive
  {
    /// The type of dynamic profile representing the body of this profile.
    internal typealias Body = Never

    /// The underlying profile node.
    internal let base: Base

    /// Closure that resolves the model box from a `SessionModelRegistry`.
    internal let makeBox: @Sendable (SessionModelRegistry) -> any LanguageModelSession.AnyModelBox

    /// The content and behavior of the dynamic profile.
    internal var body: Never {
      fatalError("_ModelDynamicProfile.body should not be called.")
    }

    /// Evaluates `base` first so inner model modifiers take precedence over outer ones.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      DynamicProfileEvaluator.evaluateNode(base, into: &context)
      if context.modelBox == nil {
        context.modelBox = makeBox(context.registry)
      }
    }
  }

  /// Internal profile wrapper that applies a scalar configuration option override.
  internal struct _ScalarOptionDynamicProfile<Base: LanguageModelSession.DynamicProfile>:
    LanguageModelSession.DynamicProfile, _DynamicProfilePrimitive
  {
    /// The kind of scalar option override carried by this wrapper.
    internal enum OptionKind: Sendable {
      /// Sets the sampling temperature.
      case temperature(Double?)
      /// Sets the sampling mode.
      case samplingMode(GenerationOptions.SamplingMode?)
      /// Sets the maximum number of response tokens.
      case maximumResponseTokens(Int?)
      /// Sets the reasoning level.
      case reasoningLevel(ContextOptions.ReasoningLevel?)
      /// Sets the tool-calling mode.
      case toolCallingMode(GenerationOptions.ToolCallingMode?)
      /// Sets the transcript error-handling policy.
      case transcriptErrorHandlingPolicy(TranscriptErrorHandlingPolicy?)
    }

    /// The type of dynamic profile representing the body of this profile.
    internal typealias Body = Never

    /// The underlying profile node.
    internal let base: Base

    /// The scalar option override to apply.
    internal let kind: OptionKind

    /// The content and behavior of the dynamic profile.
    internal var body: Never {
      fatalError("_ScalarOptionDynamicProfile.body should not be called.")
    }

    /// Evaluates `base` first so inner scalar modifiers take precedence over outer ones.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      DynamicProfileEvaluator.evaluateNode(base, into: &context)
      switch kind {
      case .temperature(let value):
        context.temperature.applyOuter(value)
      case .samplingMode(let value):
        context.samplingMode.applyOuter(value)
      case .maximumResponseTokens(let value):
        context.maximumResponseTokens.applyOuter(value)
      case .reasoningLevel(let value):
        context.reasoningLevel.applyOuter(value)
      case .toolCallingMode(let value):
        context.toolCallingMode.applyOuter(value)
      case .transcriptErrorHandlingPolicy(let value):
        context.transcriptErrorHandlingPolicy.applyOuter(value)
      }
    }
  }

  /// Internal profile wrapper that registers a `historyTransform` closure.
  internal struct _HistoryTransformDynamicProfile<Base: LanguageModelSession.DynamicProfile>:
    LanguageModelSession.DynamicProfile, _DynamicProfilePrimitive
  {
    /// The type of dynamic profile representing the body of this profile.
    internal typealias Body = Never

    /// The underlying profile node.
    internal let base: Base

    /// The history transform closure.
    internal let transform: @Sendable ([Transcript.Entry]) -> [Transcript.Entry]

    /// The content and behavior of the dynamic profile.
    internal var body: Never {
      fatalError("_HistoryTransformDynamicProfile.body should not be called.")
    }

    /// Appends `transform` before evaluating `base` so chained transforms execute outer-to-inner.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      context.historyTransforms.append(transform)
      DynamicProfileEvaluator.evaluateNode(base, into: &context)
    }
  }

  // MARK: - Public Configuration Modifiers

  extension LanguageModelSession.DynamicProfile {
    /// Applies a custom profile modifier to this dynamic profile.
    ///
    /// - Parameter modifier: The modifier to apply.
    /// - Returns: A modified dynamic profile wrapping this profile and `modifier`.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func modifier<Modifier: LanguageModelSession.DynamicProfileModifier>(
      _ modifier: Modifier
    ) -> some LanguageModelSession.DynamicProfile {
      LanguageModelSession.ModifiedDynamicProfile(content: self, modifier: modifier)
    }

    /// Overrides the language model used by this dynamic profile branch.
    ///
    /// - Parameter model: The language model to use.
    /// - Returns: A dynamic profile configured with `model`.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func model(_ model: any LanguageModel) -> some LanguageModelSession.DynamicProfile {
      _ModelDynamicProfile(base: self) { registry in
        registry.anyBox(for: model)
      }
    }

    /// Overrides the language model used by this dynamic profile branch.
    ///
    /// - Parameter model: The language model to use.
    /// - Returns: A dynamic profile configured with `model`.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func model(_ model: some LanguageModel) -> some LanguageModelSession.DynamicProfile {
      _ModelDynamicProfile(base: self) { registry in
        registry.box(for: model)
      }
    }

    /// Sets the sampling temperature for generation on this profile branch.
    ///
    /// - Parameter temperature: The temperature value, or `nil` to clear any profile override.
    /// - Returns: A dynamic profile configured with the temperature override.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func temperature(_ temperature: Double?) -> some LanguageModelSession.DynamicProfile {
      _ScalarOptionDynamicProfile(base: self, kind: .temperature(temperature))
    }

    /// Sets the sampling mode for generation on this profile branch.
    ///
    /// - Parameter samplingMode: The sampling mode, or `nil` to clear any profile override.
    /// - Returns: A dynamic profile configured with the sampling mode override.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func samplingMode(
      _ samplingMode: GenerationOptions.SamplingMode?
    ) -> some LanguageModelSession.DynamicProfile {
      _ScalarOptionDynamicProfile(base: self, kind: .samplingMode(samplingMode))
    }

    /// Sets the maximum number of response tokens to generate on this profile branch.
    ///
    /// - Parameter maximumResponseTokens: The token limit, or `nil` to clear any profile override.
    /// - Returns: A dynamic profile configured with the token limit override.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func maximumResponseTokens(
      _ maximumResponseTokens: Int?
    ) -> some LanguageModelSession.DynamicProfile {
      _ScalarOptionDynamicProfile(base: self, kind: .maximumResponseTokens(maximumResponseTokens))
    }

    /// Sets the reasoning level for generation on this profile branch.
    ///
    /// - Parameter reasoningLevel: The reasoning level, or `nil` to clear any profile override.
    /// - Returns: A dynamic profile configured with the reasoning level override.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func reasoningLevel(
      _ reasoningLevel: ContextOptions.ReasoningLevel?
    ) -> some LanguageModelSession.DynamicProfile {
      _ScalarOptionDynamicProfile(base: self, kind: .reasoningLevel(reasoningLevel))
    }

    /// Sets the tool calling mode for generation on this profile branch.
    ///
    /// - Parameter toolCallingMode: The tool calling mode, or `nil` to clear any profile override.
    /// - Returns: A dynamic profile configured with the tool calling mode override.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func toolCallingMode(
      _ toolCallingMode: GenerationOptions.ToolCallingMode?
    ) -> some LanguageModelSession.DynamicProfile {
      _ScalarOptionDynamicProfile(base: self, kind: .toolCallingMode(toolCallingMode))
    }

    /// Registers a transform closure to filter or modify transcript history on this profile branch.
    ///
    /// - Parameter transform: A closure that transforms transcript entries.
    /// - Returns: A dynamic profile configured with the history transform.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func historyTransform(
      _ transform: @escaping ([Transcript.Entry]) -> [Transcript.Entry]
    ) -> some LanguageModelSession.DynamicProfile {
      // The closure is only called serially by one session, so transferring it is race-free as
      // long as callers follow the documented purity requirement.
      nonisolated(unsafe) let transferredTransform = transform
      return _HistoryTransformDynamicProfile(base: self) { entries in
        unsafe transferredTransform(entries)
      }
    }

    /// Sets the transcript error-handling policy for turns on this profile branch.
    ///
    /// - Parameter transcriptErrorHandlingPolicy: The error policy, or `nil` to clear any override.
    /// - Returns: A dynamic profile configured with the error-handling policy override.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func transcriptErrorHandlingPolicy(
      _ transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy?
    ) -> some LanguageModelSession.DynamicProfile {
      _ScalarOptionDynamicProfile(
        base: self,
        kind: .transcriptErrorHandlingPolicy(transcriptErrorHandlingPolicy)
      )
    }
  }
#endif  // compiler(>=6.4)
