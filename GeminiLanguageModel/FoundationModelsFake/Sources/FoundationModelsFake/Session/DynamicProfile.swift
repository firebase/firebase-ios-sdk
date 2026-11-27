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

  // MARK: - DynamicProfile

  extension LanguageModelSession {
    /// A type that defines dynamic configuration, instructions, and lifecycle hooks for a session.
    ///
    /// - SeeAlso: [`LanguageModelSession.DynamicProfile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile)
    @_typeEraser(AnyDynamicProfile)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public protocol DynamicProfile {
      /// The type of dynamic profile representing the body of this profile.
      associatedtype Body: LanguageModelSession.DynamicProfile

      /// The content and behavior of the dynamic profile.
      @LanguageModelSession.DynamicProfileBuilder
      var body: Self.Body { get }
    }
  }

  extension LanguageModelSession.DynamicProfile {
    /// An alias for the concrete profile leaf type within a session.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias Profile = LanguageModelSession.Profile

    /// An alias for the dynamic profile protocol within a session.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias DynamicProfile = LanguageModelSession.DynamicProfile

    /// An alias for the session property wrapper within a dynamic profile.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias SessionProperty = LanguageModelSession.SessionProperty
  }

  // MARK: - Standard Conformances

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Never: LanguageModelSession.DynamicProfile {}

  // MARK: - AnyDynamicProfile

  extension LanguageModelSession {
    /// A type-erased dynamic profile container.
    ///
    /// - SeeAlso: [`LanguageModelSession.AnyDynamicProfile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/anydynamicprofile)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct AnyDynamicProfile: LanguageModelSession.DynamicProfile {
      /// The type of dynamic profile representing the body of this profile.
      public typealias Body = Never

      /// The underlying dynamic profile value wrapped by this instance.
      internal let storage: any LanguageModelSession.DynamicProfile

      /// Creates a type-erased dynamic profile wrapping the given dynamic profile.
      ///
      /// - Parameter dynamicProfile: The dynamic profile to type-erase.
      public init(_ dynamicProfile: any LanguageModelSession.DynamicProfile) {
        if let existing = dynamicProfile as? AnyDynamicProfile {
          self.storage = existing.storage
        } else {
          self.storage = dynamicProfile
        }
      }

      /// Creates a type-erased dynamic profile wrapping the given dynamic profile.
      ///
      /// - Parameter dynamicProfile: The dynamic profile to type-erase.
      public init(erasing dynamicProfile: some DynamicProfile) {
        self.init(dynamicProfile)
      }

      /// The content and behavior of the dynamic profile.
      public var body: Never {
        fatalError("AnyDynamicProfile.body should not be called.")
      }
    }
  }

  // MARK: - Profile

  extension LanguageModelSession {
    /// A leaf dynamic profile configured with dynamic instructions and tools.
    ///
    /// - SeeAlso: [`LanguageModelSession.Profile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/profile)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct Profile: LanguageModelSession.DynamicProfile {
      /// The type of dynamic profile representing the body of this profile.
      public typealias Body = Never

      /// The dynamic instructions component produced by this profile's builder closure.
      internal let instructions: AnyDynamicInstructions

      /// Creates a profile with dynamic instructions and tools constructed by a builder closure.
      ///
      /// - Parameter dynamicInstructions: A builder closure that produces dynamic instructions.
      public init(
        @DynamicInstructionsBuilder _ dynamicInstructions: () -> some DynamicInstructions
      ) {
        self.instructions = AnyDynamicInstructions(dynamicInstructions())
      }

      /// The content and behavior of the dynamic profile.
      public var body: Never {
        fatalError("Profile.body should not be called.")
      }
    }
  }

  // MARK: - ConditionalDynamicProfile

  extension LanguageModelSession {
    /// A dynamic profile that represents an alternative between two profile branches.
    ///
    /// - SeeAlso: [`LanguageModelSession.ConditionalDynamicProfile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/conditionaldynamicprofile)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct ConditionalDynamicProfile<
      TrueContent: LanguageModelSession.DynamicProfile,
      FalseContent: LanguageModelSession.DynamicProfile
    >: LanguageModelSession.DynamicProfile {
      /// The type of dynamic profile representing the body of this profile.
      public typealias Body = Never

      /// A branch of a conditional dynamic profile.
      internal enum Branch {
        /// The first (`true`) branch of a conditional statement.
        case trueContent(TrueContent)

        /// The second (`false`) branch of a conditional statement.
        case falseContent(FalseContent)
      }

      /// The active conditional branch stored by this instance.
      internal let branch: Branch

      /// Creates a conditional dynamic profile for the specified branch.
      ///
      /// - Parameter branch: The selected branch of the conditional.
      internal init(_ branch: Branch) {
        self.branch = branch
      }

      /// The content and behavior of the dynamic profile.
      public var body: Never {
        fatalError("ConditionalDynamicProfile.body should not be called.")
      }
    }
  }

  // MARK: - DynamicProfileBuilder

  extension LanguageModelSession {
    /// A result builder used to construct dynamic profiles.
    ///
    /// - SeeAlso: [`LanguageModelSession.DynamicProfileBuilder`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofilebuilder)
    @resultBuilder
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct DynamicProfileBuilder {
      /// Passes through a single dynamic profile component.
      ///
      /// - Parameter content: The dynamic profile component.
      /// - Returns: The given dynamic profile.
      public static func buildBlock<T: LanguageModelSession.DynamicProfile>(_ content: T) -> T {
        content
      }

      /// Builds a conditional dynamic profile from the first branch of a conditional statement.
      ///
      /// - Parameter content: The dynamic profile from the first branch.
      /// - Returns: A conditional dynamic profile selecting the first branch.
      public static func buildEither<
        TrueContent: LanguageModelSession.DynamicProfile,
        FalseContent: LanguageModelSession.DynamicProfile
      >(
        first content: TrueContent
      ) -> LanguageModelSession.ConditionalDynamicProfile<TrueContent, FalseContent> {
        ConditionalDynamicProfile(.trueContent(content))
      }

      /// Builds a conditional dynamic profile from the second branch of a conditional statement.
      ///
      /// - Parameter content: The dynamic profile from the second branch.
      /// - Returns: A conditional dynamic profile selecting the second branch.
      public static func buildEither<
        TrueContent: LanguageModelSession.DynamicProfile,
        FalseContent: LanguageModelSession.DynamicProfile
      >(
        second content: FalseContent
      ) -> LanguageModelSession.ConditionalDynamicProfile<TrueContent, FalseContent> {
        ConditionalDynamicProfile(.falseContent(content))
      }

      // Disfavored so that, with availability checking disabled inside the fake, the compiler never
      // prefers this overload.
      /// Diagnoses an error when multiple profile expressions appear in a single block.
      ///
      /// - Parameter contents: The dynamic profile components.
      /// - Returns: Never returns.
      @_disfavoredOverload
      @available(
        *, unavailable,
        message: "A 'DynamicProfile' body must produce exactly one active profile"
      )
      public static func buildBlock<each Content: LanguageModelSession.DynamicProfile>(
        _ contents: repeat each Content
      ) -> Never {
        fatalError("A 'DynamicProfile' body must produce exactly one active profile.")
      }

      /// Erases a dynamic profile constructed under conditional API availability.
      ///
      /// - Parameter component: The dynamic profile component.
      /// - Returns: A type-erased dynamic profile wrapping `component`.
      public static func buildLimitedAvailability(
        _ component: some LanguageModelSession.DynamicProfile
      ) -> LanguageModelSession.AnyDynamicProfile {
        AnyDynamicProfile(component)
      }
    }
  }

  // MARK: - Internal Profile Evaluation & Flattening

  /// Represents a structural step along the active path of a `DynamicProfile` hierarchy.
  internal enum ProfilePathStep: Hashable, Sendable {
    /// Entered the `body` of a composite `DynamicProfile` type.
    case profileType(ObjectIdentifier)

    /// Entered the `body(content:)` of a `DynamicProfileModifier` type.
    case modifierType(ObjectIdentifier)

    /// Selected the first (`true`) branch of a `ConditionalDynamicProfile`.
    case conditionalFirst

    /// Selected the second (`false`) branch of a `ConditionalDynamicProfile`.
    case conditionalSecond

    /// Opened an `AnyDynamicProfile` wrapping a concrete profile of the given type.
    case typeErased(ObjectIdentifier)
  }

  /// A lifecycle hook (`onActivate` or `onDeactivate`) paired with its structural path in the
  /// profile hierarchy.
  internal struct ProfileLifecycleHook: Sendable {
    /// The structural path from the root profile to the branch where this hook was registered.
    internal let path: [ProfilePathStep]

    /// The asynchronous callback to execute.
    internal let action: @Sendable () async -> Void
  }

  /// Tracks whether a scalar profile modifier has already been set by an inner profile node.
  internal enum ProfileOptionOverride<Value: Sendable>: Sendable {
    /// No modifier for this option has been encountered yet.
    case unset

    /// An inner modifier explicitly set this option to the given value (which may be `nil`).
    case set(Value?)

    /// Records `newValue` only if no inner modifier has set this option yet (innermost wins).
    ///
    /// Because `_ScalarOptionDynamicProfile` evaluates its inner `base` profile first, any inner
    /// modifier transitions this override to `.set(...)`, preventing outer modifiers from
    /// overwriting it.
    ///
    /// - Parameter newValue: The outer modifier's value.
    internal mutating func applyOuter(_ newValue: Value?) {
      if case .unset = self {
        self = .set(newValue)
      }
    }

    /// The resolved optional value if set, or `nil` if unset.
    internal var resolvedValue: Value? {
      switch self {
      case .unset:
        return nil
      case .set(let value):
        return value
      }
    }
  }

  /// Mutable state accumulated while evaluating a `DynamicProfile` tree from root to leaf.
  internal struct ProfileEvaluationContext {
    /// The owning session's model executor registry.
    internal let registry: SessionModelRegistry

    /// The owning session's property values storage used to bind `@SessionProperty` wrappers.
    internal let properties: SessionPropertyValues

    /// The current traversal path from the root profile node.
    internal var currentPath: [ProfilePathStep] = []

    /// The structural path recorded when reaching the active leaf `Profile`.
    internal var activeLeafPath: [ProfilePathStep] = []

    /// The flattened instructions and tools produced by the active leaf `Profile`.
    internal var flattenedInstructions = FlattenedDynamicInstructions()

    /// The resolved model box from the innermost `.model(...)` modifier.
    internal var modelBox: (any LanguageModelSession.AnyModelBox)? = nil

    /// Scalar option overrides where the innermost modifier takes precedence.
    internal var temperature: ProfileOptionOverride<Double> = .unset
    internal var samplingMode: ProfileOptionOverride<GenerationOptions.SamplingMode> = .unset
    internal var maximumResponseTokens: ProfileOptionOverride<Int> = .unset
    internal var toolCallingMode: ProfileOptionOverride<GenerationOptions.ToolCallingMode> = .unset
    internal var reasoningLevel: ProfileOptionOverride<ContextOptions.ReasoningLevel> = .unset
    internal var transcriptErrorHandlingPolicy:
      ProfileOptionOverride<TranscriptErrorHandlingPolicy> =
        .unset

    /// History transforms collected in outer-to-inner execution order.
    internal var historyTransforms: [@Sendable ([Transcript.Entry]) -> [Transcript.Entry]] = []

    /// Turn hooks collected in inner-to-outer execution order.
    internal var onPromptHooks: [@Sendable (Transcript.Prompt) async throws -> Void] = []
    internal var onReasoningHooks: [@Sendable (Transcript.Reasoning) async throws -> Void] = []
    internal var onToolCallHooks: [@Sendable (Transcript.ToolCall) async throws -> Void] = []
    internal var onToolOutputHooks:
      [@Sendable (Transcript.ToolCall, Transcript.ToolOutput) async throws -> Void] = []
    internal var onResponseHooks: [@Sendable (Transcript.Response) async throws -> Void] = []

    /// Activation hooks collected in outer-to-inner execution order.
    internal var onActivateHooks: [ProfileLifecycleHook] = []

    /// Deactivation hooks collected in inner-to-outer execution order.
    internal var onDeactivateHooks: [ProfileLifecycleHook] = []
  }

  /// An internal protocol implemented by primitive `DynamicProfile` nodes whose `Body` is `Never`.
  internal protocol _DynamicProfilePrimitive {
    /// Evaluates this primitive profile node into `context`.
    ///
    /// - Parameter context: The mutable profile evaluation context.
    func _evaluate(into context: inout ProfileEvaluationContext)
  }

  /// Evaluates a `DynamicProfile` hierarchy into a per-turn `ResolvedConfiguration`.
  internal enum DynamicProfileEvaluator {
    /// Evaluates `root` outside `state.withLock`, binding all encountered `@SessionProperty`
    /// wrappers to `properties` and resolving model executors via `registry`.
    ///
    /// - Parameters:
    ///   - root: The root dynamic profile to evaluate.
    ///   - registry: The session's model executor registry.
    ///   - properties: The session's property values storage.
    /// - Returns: The resolved configuration for the active profile branch.
    internal static func evaluate<P: LanguageModelSession.DynamicProfile>(
      _ root: P,
      registry: SessionModelRegistry,
      properties: SessionPropertyValues
    ) -> ResolvedConfiguration {
      var context = ProfileEvaluationContext(registry: registry, properties: properties)
      evaluateNode(root, into: &context)

      let resolvedTemperature = context.temperature.resolvedValue
      let resolvedSamplingMode = context.samplingMode.resolvedValue
      let resolvedMaxTokens = context.maximumResponseTokens.resolvedValue
      let resolvedToolMode = context.toolCallingMode.resolvedValue

      let generationOptionsOverride: GenerationOptions? =
        if resolvedTemperature != nil || resolvedSamplingMode != nil || resolvedMaxTokens != nil
          || resolvedToolMode != nil
        {
          GenerationOptions(
            samplingMode: resolvedSamplingMode,
            temperature: resolvedTemperature,
            maximumResponseTokens: resolvedMaxTokens,
            toolCallingMode: resolvedToolMode
          )
        } else {
          nil
        }

      let resolvedReasoningLevel = context.reasoningLevel.resolvedValue
      let contextOptionsOverride: ContextOptions? =
        if let resolvedReasoningLevel {
          ContextOptions(reasoningLevel: resolvedReasoningLevel)
        } else {
          nil
        }

      return ResolvedConfiguration(
        modelBox: context.modelBox ?? context.registry.box(for: SystemLanguageModel.default),
        tools: context.flattenedInstructions.tools,
        instructionsSegments: context.flattenedInstructions.segments,
        instructionsToolDefinitions: context.flattenedInstructions.instructionToolDefinitions,
        isStatic: false,
        generationOptionsOverride: generationOptionsOverride,
        contextOptionsOverride: contextOptionsOverride,
        transcriptErrorHandlingPolicyOverride: context.transcriptErrorHandlingPolicy.resolvedValue,
        historyTransforms: context.historyTransforms,
        onPromptHooks: context.onPromptHooks,
        onReasoningHooks: context.onReasoningHooks,
        onToolCallHooks: context.onToolCallHooks,
        onToolOutputHooks: context.onToolOutputHooks,
        onResponseHooks: context.onResponseHooks,
        activeProfilePath: context.activeLeafPath,
        onActivateHooks: context.onActivateHooks,
        onDeactivateHooks: context.onDeactivateHooks
      )
    }

    /// Recursively evaluates a single `DynamicProfile` node into `context`.
    ///
    /// - Parameters:
    ///   - node: The profile node to evaluate.
    ///   - context: The mutable profile evaluation context.
    internal static func evaluateNode<P: LanguageModelSession.DynamicProfile>(
      _ node: P,
      into context: inout ProfileEvaluationContext
    ) {
      if let primitive = node as? any _DynamicProfilePrimitive {
        primitive._evaluate(into: &context)
        return
      }

      SessionPropertyBinder.bind(node, to: context.properties)
      guard P.Body.self != Never.self else { return }
      context.currentPath.append(.profileType(ObjectIdentifier(P.self)))
      let body = node.body
      evaluateNode(body, into: &context)
      context.currentPath.removeLast()
    }
  }

  // MARK: - Core Primitive Conformances

  extension Never: _DynamicProfilePrimitive {
    /// No-op evaluation for `Never`.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {}
  }

  extension LanguageModelSession.Profile: _DynamicProfilePrimitive {
    /// Flattens the leaf profile's dynamic instructions and binds any nested `@SessionProperty`
    /// wrappers.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      context.activeLeafPath = context.currentPath
      let properties = context.properties
      context.flattenedInstructions = DynamicInstructionsFlattener.flatten(instructions) { target in
        SessionPropertyBinder.bind(target, to: properties)
      }
    }
  }

  extension LanguageModelSession.AnyDynamicProfile: _DynamicProfilePrimitive {
    /// Opens and evaluates the underlying type-erased dynamic profile.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      func openAndEvaluate<T: LanguageModelSession.DynamicProfile>(_ wrapped: T) {
        context.currentPath.append(.typeErased(ObjectIdentifier(T.self)))
        DynamicProfileEvaluator.evaluateNode(wrapped, into: &context)
        context.currentPath.removeLast()
      }
      openAndEvaluate(storage)
    }
  }

  extension LanguageModelSession.ConditionalDynamicProfile: _DynamicProfilePrimitive {
    /// Evaluates the active branch of the conditional dynamic profile.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      switch branch {
      case .trueContent(let content):
        context.currentPath.append(.conditionalFirst)
        DynamicProfileEvaluator.evaluateNode(content, into: &context)
        context.currentPath.removeLast()
      case .falseContent(let content):
        context.currentPath.append(.conditionalSecond)
        DynamicProfileEvaluator.evaluateNode(content, into: &context)
        context.currentPath.removeLast()
      }
    }
  }
#endif  // compiler(>=6.4)
