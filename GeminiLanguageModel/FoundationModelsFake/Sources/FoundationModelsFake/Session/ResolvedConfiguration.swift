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
  import Synchronization

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - SessionModelRegistry

  /// A per-session registry that caches instantiated language model executors across model switches.
  ///
  /// Each ``LanguageModelSession`` owns its own `SessionModelRegistry` instance so executors are
  /// never shared across sessions, while switching between models within the same session (`Model A`
  /// -> `Model B` -> `Model A`) reuses `Model A`'s cached executor when its executor type and
  /// configuration match.
  internal final class SessionModelRegistry: Sendable {
    /// Composite cache key identifying an executor type and its configuration value.
    internal struct ModelCacheKey: Hashable, Sendable {
      /// The metatype identifier of `M.Executor`.
      let executorType: ObjectIdentifier

      /// The type-erased `Sendable & Hashable` executor configuration.
      let configuration: LanguageModelSession.AnySendableHashable
    }

    /// Cached executor instances keyed by `(Executor.self, configuration)`.
    private let executors = Mutex<[ModelCacheKey: any Sendable]>([:])

    /// Creates an empty per-session model executor registry.
    internal init() {}

    /// Resolves a cached executor for `model`, or initializes and caches a new one.
    ///
    /// - Parameter model: The language model whose executor should be resolved.
    /// - Returns: The resolved executor instance for `model`.
    /// - Throws: Any error thrown by `M.Executor(configuration:)`.
    internal func resolveExecutor<M: LanguageModel>(for model: M) throws -> M.Executor {
      let configuration = model.executorConfiguration
      let key = ModelCacheKey(
        executorType: ObjectIdentifier(M.Executor.self),
        configuration: LanguageModelSession.AnySendableHashable(configuration)
      )
      if let cached = executors.withLock({ $0[key] }) as? M.Executor {
        return cached
      }
      let created = try M.Executor(configuration: configuration)
      return executors.withLock { cache in
        if let existing = cache[key] as? M.Executor {
          return existing
        }
        cache[key] = created
        return created
      }
    }

    /// Creates a type-erased model box backed by this session registry for `model`.
    ///
    /// - Parameter model: The language model to wrap.
    /// - Returns: A `ConcreteModelBox` sharing this registry's executor cache.
    internal func box<M: LanguageModel>(for model: M) -> LanguageModelSession.ConcreteModelBox<M> {
      LanguageModelSession.ConcreteModelBox(model, registry: self)
    }

    /// Creates a type-erased model box backed by this session registry for an existential `model`.
    ///
    /// - Parameter model: The language model to wrap.
    /// - Returns: An `AnyModelBox` sharing this registry's executor cache.
    internal func anyBox(for model: any LanguageModel) -> any LanguageModelSession.AnyModelBox {
      func makeBox<M: LanguageModel>(_ concrete: M) -> any LanguageModelSession.AnyModelBox {
        LanguageModelSession.ConcreteModelBox(concrete, registry: self)
      }
      return makeBox(model)
    }
  }

  // MARK: - ResolvedConfiguration

  /// The per-request resolved configuration for a ``LanguageModelSession`` turn.
  internal struct ResolvedConfiguration: Sendable {
    /// The active language model box for the turn.
    internal let modelBox: any LanguageModelSession.AnyModelBox

    /// The active tools deduplicated on a first-wins basis by `tool.name`.
    internal let tools: [any Tool]

    /// The evaluated instruction segments for dynamic sessions.
    internal let instructionsSegments: [Transcript.Segment]

    /// The definitions of `tools` whose `includesSchemaInInstructions` is `true`.
    internal let instructionsToolDefinitions: [Transcript.ToolDefinition]

    /// Whether this configuration originates from a static session initializer.
    ///
    /// When `true`, the session skips per-turn dynamic instruction re-evaluation and leading
    /// `.instructions` updates.
    internal let isStatic: Bool

    /// Optional profile-level generation options override.
    internal var generationOptionsOverride: GenerationOptions?

    /// Optional profile-level context options override.
    internal var contextOptionsOverride: ContextOptions?

    /// Optional profile-level transcript error handling policy override.
    internal var transcriptErrorHandlingPolicyOverride: TranscriptErrorHandlingPolicy?

    /// Chained history transforms registered on the active profile (outer-to-inner).
    internal var historyTransforms: [@Sendable ([Transcript.Entry]) -> [Transcript.Entry]]

    /// Lifecycle hooks invoked after appending the user prompt (inner-to-outer).
    internal var onPromptHooks: [@Sendable (Transcript.Prompt) async throws -> Void]

    /// Lifecycle hooks invoked when a reasoning entry is finalized (inner-to-outer).
    internal var onReasoningHooks: [@Sendable (Transcript.Reasoning) async throws -> Void]

    /// Lifecycle hooks invoked before each tool call executes (inner-to-outer).
    internal var onToolCallHooks: [@Sendable (Transcript.ToolCall) async throws -> Void]

    /// Lifecycle hooks invoked after each tool call produces an output (inner-to-outer).
    internal var onToolOutputHooks:
      [@Sendable (Transcript.ToolCall, Transcript.ToolOutput) async throws -> Void]

    /// Lifecycle hooks invoked when the final response entry is finalized (inner-to-outer).
    internal var onResponseHooks: [@Sendable (Transcript.Response) async throws -> Void]

    /// Structural path of the active profile leaf in the conditional profile tree.
    internal var activeProfilePath: [ProfilePathStep]

    /// Activation hooks along the active profile branch (outer-to-inner).
    internal var onActivateHooks: [ProfileLifecycleHook]

    /// Deactivation hooks along the active profile branch (inner-to-outer).
    internal var onDeactivateHooks: [ProfileLifecycleHook]

    /// Creates a resolved configuration.
    internal init(
      modelBox: any LanguageModelSession.AnyModelBox,
      tools: [any Tool],
      instructionsSegments: [Transcript.Segment] = [],
      instructionsToolDefinitions: [Transcript.ToolDefinition],
      isStatic: Bool,
      generationOptionsOverride: GenerationOptions? = nil,
      contextOptionsOverride: ContextOptions? = nil,
      transcriptErrorHandlingPolicyOverride: TranscriptErrorHandlingPolicy? = nil,
      historyTransforms: [@Sendable ([Transcript.Entry]) -> [Transcript.Entry]] = [],
      onPromptHooks: [@Sendable (Transcript.Prompt) async throws -> Void] = [],
      onReasoningHooks: [@Sendable (Transcript.Reasoning) async throws -> Void] = [],
      onToolCallHooks: [@Sendable (Transcript.ToolCall) async throws -> Void] = [],
      onToolOutputHooks:
        [@Sendable (Transcript.ToolCall, Transcript.ToolOutput) async throws -> Void] = [],
      onResponseHooks: [@Sendable (Transcript.Response) async throws -> Void] = [],
      activeProfilePath: [ProfilePathStep] = [],
      onActivateHooks: [ProfileLifecycleHook] = [],
      onDeactivateHooks: [ProfileLifecycleHook] = []
    ) {
      self.modelBox = modelBox
      self.tools = tools
      self.instructionsSegments = instructionsSegments
      self.instructionsToolDefinitions = instructionsToolDefinitions
      self.isStatic = isStatic
      self.generationOptionsOverride = generationOptionsOverride
      self.contextOptionsOverride = contextOptionsOverride
      self.transcriptErrorHandlingPolicyOverride = transcriptErrorHandlingPolicyOverride
      self.historyTransforms = historyTransforms
      self.onPromptHooks = onPromptHooks
      self.onReasoningHooks = onReasoningHooks
      self.onToolCallHooks = onToolCallHooks
      self.onToolOutputHooks = onToolOutputHooks
      self.onResponseHooks = onResponseHooks
      self.activeProfilePath = activeProfilePath
      self.onActivateHooks = onActivateHooks
      self.onDeactivateHooks = onDeactivateHooks
    }

    /// Whether the evaluated dynamic instructions contain neither text segments nor tools.
    internal var hasEmptyInstructions: Bool {
      instructionsSegments.isEmpty && tools.isEmpty
    }

    /// Merges profile-level generation option overrides with `perCall` options.
    ///
    /// Non-`nil` fields on `perCall` take precedence over profile modifier values.
    ///
    /// - Parameter perCall: The generation options passed to `respond` or `streamResponse`.
    /// - Returns: The effective generation options for the turn.
    internal func effectiveGenerationOptions(perCall: GenerationOptions) -> GenerationOptions {
      guard let override = generationOptionsOverride else { return perCall }
      return GenerationOptions(
        samplingMode: perCall.samplingMode ?? override.samplingMode,
        temperature: perCall.temperature ?? override.temperature,
        maximumResponseTokens: perCall.maximumResponseTokens ?? override.maximumResponseTokens,
        toolCallingMode: perCall.toolCallingMode ?? override.toolCallingMode
      )
    }

    /// Merges profile-level context option overrides with `perCall` context options.
    ///
    /// Non-`nil` fields on `perCall` take precedence over profile modifier values.
    ///
    /// - Parameter perCall: The context options passed to `respond` or `streamResponse`.
    /// - Returns: The effective context options for the turn.
    internal func effectiveContextOptions(perCall: ContextOptions) -> ContextOptions {
      guard let override = contextOptionsOverride else { return perCall }
      return ContextOptions(
        includeSchemaInPrompt: perCall.includeSchemaInPrompt ?? override.includeSchemaInPrompt,
        reasoningLevel: perCall.reasoningLevel ?? override.reasoningLevel
      )
    }
  }

  // MARK: - SessionConfigurationSource

  /// The backing configuration source for a ``LanguageModelSession``.
  internal enum SessionConfigurationSource: Sendable {
    /// Constant configuration for sessions created with static model, tools, and instructions.
    case staticConfig(ResolvedConfiguration)

    /// Dynamically evaluated instructions configuration for sessions created with
    /// `init(model:dynamicInstructions:history:)`.
    case dynamicInstructions(
      modelBox: any LanguageModelSession.AnyModelBox,
      evaluate: @Sendable (SessionPropertyValues) -> FlattenedDynamicInstructions
    )

    /// Dynamically evaluated profile configuration for sessions created with
    /// `init(profile:history:)`.
    case dynamicProfile(
      registry: SessionModelRegistry,
      evaluate: @Sendable (SessionModelRegistry, SessionPropertyValues) -> ResolvedConfiguration
    )

    /// Whether this configuration source is static and never re-evaluates between turns.
    internal var isStatic: Bool {
      switch self {
      case .staticConfig:
        return true
      case .dynamicInstructions, .dynamicProfile:
        return false
      }
    }

    /// Resolves the configuration for the current turn.
    ///
    /// Must be called outside `state.withLock` so dynamic instruction builders can read observable
    /// state and session properties without lock reentrancy.
    ///
    /// - Parameter properties: Autoclosure providing the session's `SessionPropertyValues` when
    ///   binding dynamic instructions and tools.
    /// - Returns: The resolved configuration for the turn.
    internal func resolve(
      using properties: @autoclosure () -> SessionPropertyValues
    ) -> ResolvedConfiguration {
      switch self {
      case .staticConfig(let config):
        return config
      case .dynamicInstructions(let modelBox, let evaluate):
        let flattened = evaluate(properties())
        return ResolvedConfiguration(
          modelBox: modelBox,
          tools: flattened.tools,
          instructionsSegments: flattened.segments,
          instructionsToolDefinitions: flattened.instructionToolDefinitions,
          isStatic: false
        )
      case .dynamicProfile(let registry, let evaluate):
        return evaluate(registry, properties())
      }
    }
  }
#endif  // compiler(>=6.4)
