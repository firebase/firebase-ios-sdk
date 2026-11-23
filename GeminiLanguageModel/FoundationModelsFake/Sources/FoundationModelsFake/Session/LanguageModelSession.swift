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
  import Foundation
  public import Observation
  import Synchronization

  #if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
  #endif

  /// A session managing a multi-turn conversation with a language model.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModelSession`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public final class LanguageModelSession {
    // MARK: - Type-Erased Model Box

    /// A type-erased wrapper around a `Hashable & Sendable` value that preserves `Sendable`
    /// conformance without `@unchecked`.
    internal struct AnySendableHashable: Hashable, Sendable {
      /// The wrapped hashable and sendable value.
      private let base: any Hashable & Sendable

      /// Creates a type-erased wrapper around `base`.
      internal init(_ base: some Hashable & Sendable) {
        self.base = base
      }

      /// Returns whether two type-erased wrappers wrap equal values of the exact same dynamic type.
      internal static func == (lhs: AnySendableHashable, rhs: AnySendableHashable) -> Bool {
        guard type(of: lhs.base) == type(of: rhs.base) else { return false }
        return Self.areEqual(lhs.base, rhs.base)
      }

      /// Hashes the dynamic type identifier and wrapped value into `hasher`.
      internal func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: base)))
        base.hash(into: &hasher)
      }

      /// Opens the existential `lhs` to compare it against `rhs` of the same dynamic type.
      private static func areEqual<T: Hashable>(_ lhs: T, _ rhs: any Hashable) -> Bool {
        guard type(of: lhs as Any) == type(of: rhs), let rhs = rhs as? T else { return false }
        return lhs == rhs
      }
    }

    /// Type-erased box wrapping a concrete `LanguageModel` instance.
    internal protocol AnyModelBox: Sendable {
      /// The capabilities supported by the underlying language model.
      var capabilities: LanguageModelCapabilities { get }

      /// Prewarms the underlying model executor with `transcript`.
      func prewarm(transcript: Transcript)

      /// Executes a single generation turn streaming events into `channel`.
      nonisolated(nonsending) func respond(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws

      #if compiler(>=6.4.2)
        /// Returns whether the underlying model supports data attachments of `type`.
        nonisolated(nonsending) func supportsDataAttachmentType(_ type: UTType) async throws -> Bool

        /// Returns whether the underlying model supports data entries of `type`.
        nonisolated(nonsending) func supportsDataEntryType(_ type: UTType) async throws -> Bool
      #endif  // compiler(>=6.4.2)
    }

    /// Concrete box storing a `LanguageModel` and resolving its cached `Executor`.
    ///
    /// Each session creates its own box, so executors are cached **per session**, as in Apple's
    /// session: two sessions never share an executor, even with equal configurations. Within the
    /// box, executors are keyed by `Configuration` equality. An executor is created lazily, on the
    /// first `prewarm` or request, and a failed initialization isn't cached, so the next call tries
    /// again.
    internal final class ConcreteModelBox<M: LanguageModel>: AnyModelBox, Sendable {
      /// The wrapped language model.
      let model: M

      /// This session's executor registry.
      let registry: SessionModelRegistry

      /// Creates a box wrapping `model` and using `registry` to cache executors.
      init(_ model: M, registry: SessionModelRegistry = SessionModelRegistry()) {
        self.model = model
        self.registry = registry
      }

      /// The capabilities declared by `model`.
      var capabilities: LanguageModelCapabilities {
        model.capabilities
      }

      /// Resolves or creates this session's executor for `model`'s configuration.
      func resolveExecutor() throws -> M.Executor {
        try registry.resolveExecutor(for: model)
      }

      /// Prewarms the resolved executor with `transcript`, ignoring initialization errors.
      func prewarm(transcript: Transcript) {
        guard let executor = try? resolveExecutor() else { return }
        executor.prewarm(model: model, transcript: transcript)
      }

      /// Runs a single turn on the resolved executor streaming events into `channel`.
      nonisolated(nonsending) func respond(
        to request: LanguageModelExecutorGenerationRequest,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        let executor = try resolveExecutor()
        try await executor.respond(to: request, model: model, streamingInto: channel)
      }

      #if compiler(>=6.4.2)
        /// Returns whether `model` supports data attachments of `type`.
        nonisolated(nonsending) func supportsDataAttachmentType(_ type: UTType) async throws -> Bool
        {
          try await model.supportsDataAttachmentType(type)
        }

        /// Returns whether `model` supports data entries of `type`.
        nonisolated(nonsending) func supportsDataEntryType(_ type: UTType) async throws -> Bool {
          try await model.supportsDataEntryType(type)
        }
      #endif  // compiler(>=6.4.2)
    }

    // MARK: - Internal State

    /// Mutable session state synchronized by `state`.
    internal struct State: Sendable {
      /// The current session transcript.
      var transcript: Transcript

      /// The policy governing transcript restoration after an error.
      var transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy? = nil

      /// Whether a `respond` or `streamResponse` call is currently active.
      var isResponding: Bool = false

      /// Cumulative token usage across completed turns in this session.
      var usage: LanguageModelSession.Usage = .zero

      /// Counter incremented whenever `session.transcript` is assigned externally.
      var externalMutationCount: UInt64 = 0

      /// Counter incremented when an observer assigns `session.transcript` from inside one of this
      /// session's own notifications (a subset of `externalMutationCount`).
      ///
      /// Such writes fail the call and always revert. Other external writes follow the
      /// error-handling policy, as in Apple's session.
      var reentrantMutationCount: UInt64 = 0

      /// The IDs of this session's observer notifications in progress.
      var activeNotificationScopes: Set<UInt64> = []

      /// Type-erased `SessionPropertyValues` box associated with this session.
      var _propertyValuesBox: (any Sendable)? = nil

      /// The structural path of the currently active profile leaf, if any.
      var activeProfilePath: [ProfilePathStep]? = nil

      /// The deactivation hooks along the currently active profile branch (inner-to-outer).
      var activeDeactivateHooks: [ProfileLifecycleHook] = []

      /// Detached task running initial `onActivate` hooks spawned during `init(profile:history:)`.
      var pendingInitialActivationTask: Task<Void, Never>? = nil
    }

    /// Per-session registry caching language model executors across model switches.
    internal let modelRegistry: SessionModelRegistry

    /// The configuration source resolving the active model, tools, and instructions for each turn.
    internal let configurationSource: SessionConfigurationSource

    /// Type-erased language model box for this session.
    internal let modelBox: any AnyModelBox

    /// Tools registered with this session.
    internal let tools: [any Tool]

    /// The definitions of the tools whose `includesSchemaInInstructions` is `true`, which every
    /// transcript the session stores carries in its leading instructions entry.
    internal let instructionsToolDefinitions: [Transcript.ToolDefinition]

    /// The ID of the instructions entry the `transcript` setter inserts for the session's tools.
    ///
    /// Apple's setter reuses one ID per session, distinct from the ID of the entry created at init.
    internal let insertedInstructionsID: String

    /// Mutex guarding the session's mutable state.
    internal let state: Mutex<State>

    /// The registrar that notifies observers of `transcript`, `isResponding`, and `usage`.
    ///
    /// Observer callbacks run synchronously and may read the session, so the session calls the
    /// registrar only while it doesn't hold `state`'s lock (see `mutateState(notifying:_:)`).
    internal let observationRegistrar = ObservationRegistrar()

    // MARK: - Public Properties

    /// The transcript of entries recorded during this session.
    public final var transcript: Transcript {
      get {
        observationRegistrar.access(self, keyPath: \.transcript)
        return state.withLock { $0.transcript }
      }
      set {
        let isReentrant = isNotifyingObservers
        let toolDefs =
          configurationSource.isStatic
          ? instructionsToolDefinitions
          : resolveConfiguration().instructionsToolDefinitions
        let stored = Self.transcript(
          newValue,
          carryingToolDefinitions: toolDefs,
          insertedInstructionsID: insertedInstructionsID
        )
        mutateState(notifying: \.transcript) {
          $0.transcript = stored
          $0.externalMutationCount &+= 1
          if isReentrant {
            $0.reentrantMutationCount &+= 1
          }
        }
      }
    }

    // MARK: - Internal Designated Initializers

    /// Creates a session with a type-erased model box, tools, and initial transcript.
    ///
    /// Like Apple's session, the stored transcript carries the definitions of the tools whose
    /// `includesSchemaInInstructions` is `true` in its leading instructions entry (see
    /// `transcript(_:carryingToolDefinitions:insertedInstructionsID:)`); an entry inserted here gets
    /// a fresh ID.
    internal init(
      modelBox: any AnyModelBox,
      tools: [any Tool],
      transcript: Transcript,
      modelRegistry: SessionModelRegistry = SessionModelRegistry()
    ) {
      let uniqueTools = Self.deduplicateTools(tools)
      let toolDefinitions =
        uniqueTools
        .filter { $0.includesSchemaInInstructions }
        .map { Transcript.ToolDefinition(tool: $0) }
      let staticConfig = ResolvedConfiguration(
        modelBox: modelBox,
        tools: uniqueTools,
        instructionsToolDefinitions: toolDefinitions,
        isStatic: true
      )
      self.modelRegistry = modelRegistry
      self.configurationSource = .staticConfig(staticConfig)
      self.modelBox = modelBox
      self.tools = uniqueTools
      self.instructionsToolDefinitions = toolDefinitions
      self.insertedInstructionsID = UUID().uuidString
      let initialTranscript = Self.transcript(
        transcript,
        carryingToolDefinitions: toolDefinitions,
        insertedInstructionsID: UUID().uuidString
      )
      self.state = Mutex(State(transcript: initialTranscript))
      if !uniqueTools.isEmpty {
        let props = self.properties
        for tool in uniqueTools {
          SessionPropertyBinder.bind(tool, to: props)
        }
      }
    }

    /// Creates a session backed by a dynamic configuration source and an optional seed history.
    internal init(
      configurationSource: SessionConfigurationSource,
      modelRegistry: SessionModelRegistry,
      modelBox: any AnyModelBox,
      seedHistory: [Transcript.Entry]
    ) {
      self.modelRegistry = modelRegistry
      self.configurationSource = configurationSource
      self.modelBox = modelBox
      self.tools = []
      self.instructionsToolDefinitions = []
      self.insertedInstructionsID = UUID().uuidString
      self.state = Mutex(State(transcript: Transcript(entries: seedHistory)))

      let initialConfig = configurationSource.resolve(using: self.properties)
      self.state.withLock { state in
        _ = Self.applyDynamicInstructions(from: initialConfig, to: &state.transcript)
        if let policyOverride = initialConfig.transcriptErrorHandlingPolicyOverride {
          state.transcriptErrorHandlingPolicy = policyOverride
        }
        state.activeProfilePath = initialConfig.activeProfilePath
        state.activeDeactivateHooks = initialConfig.onDeactivateHooks
      }
      if !initialConfig.onActivateHooks.isEmpty {
        let hooks = initialConfig.onActivateHooks
        // The hooks run asynchronously, after the initializer returns. Turns wait for them with
        // `awaitPendingInitialActivation()`.
        let task = Task.detached {
          for hook in hooks {
            await hook.action()
          }
        }
        self.state.withLock { state in
          state.pendingInitialActivationTask = task
        }
      }
    }

    /// Deduplicates `tools` on a first-wins basis by `tool.name`.
    internal static func deduplicateTools(_ tools: [any Tool]) -> [any Tool] {
      var seen: Set<String> = []
      var result: [any Tool] = []
      result.reserveCapacity(tools.count)
      for tool in tools {
        if seen.insert(tool.name).inserted {
          result.append(tool)
        }
      }
      return result
    }

    /// Resolves the active configuration for the current turn outside `state.withLock`.
    internal func resolveConfiguration() -> ResolvedConfiguration {
      configurationSource.resolve(using: self.properties)
    }

    /// Awaits the completion of any initial `onActivate` hooks spawned at `init(profile:history:)`.
    internal func awaitPendingInitialActivation() async {
      let task = state.withLock { state -> Task<Void, Never>? in
        let pending = state.pendingInitialActivationTask
        state.pendingInitialActivationTask = nil
        return pending
      }
      if let task {
        await task.value
      }
    }

    /// Runs `onDeactivate` and `onActivate` hooks if the resolved `config`'s active profile path
    /// differs from the previously active path.
    internal func runProfileTransitionIfNeeded(for config: ResolvedConfiguration) async {
      let transition = state.withLock {
        state -> (
          oldPath: [ProfilePathStep],
          oldDeactivateHooks: [ProfileLifecycleHook],
          newPath: [ProfilePathStep],
          newActivateHooks: [ProfileLifecycleHook]
        )? in
        guard let oldPath = state.activeProfilePath else {
          state.activeProfilePath = config.activeProfilePath
          state.activeDeactivateHooks = config.onDeactivateHooks
          return nil
        }
        let newPath = config.activeProfilePath
        guard oldPath != newPath else {
          state.activeDeactivateHooks = config.onDeactivateHooks
          return nil
        }
        let oldDeactivateHooks = state.activeDeactivateHooks
        state.activeProfilePath = newPath
        state.activeDeactivateHooks = config.onDeactivateHooks
        return (oldPath, oldDeactivateHooks, newPath, config.onActivateHooks)
      }
      guard let transition else { return }

      await awaitPendingInitialActivation()

      var commonPrefixLen = 0
      let minLen = min(transition.oldPath.count, transition.newPath.count)
      while commonPrefixLen < minLen
        && transition.oldPath[commonPrefixLen] == transition.newPath[commonPrefixLen]
      {
        commonPrefixLen += 1
      }

      // A profile switch happens while a call starts, so the hooks' `history` writes are part of
      // the call, like the other profile hooks'.
      await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
        for hook in transition.oldDeactivateHooks where hook.path.count > commonPrefixLen {
          await hook.action()
        }
        for hook in transition.newActivateHooks where hook.path.count > commonPrefixLen {
          await hook.action()
        }
      }
    }

    /// Resolves the active configuration for the current turn and executes any profile branch
    /// transition hooks (`onDeactivate` followed by `onActivate`).
    internal func resolveConfigurationAndHandleSwitch() async -> ResolvedConfiguration {
      let config = resolveConfiguration()
      await runProfileTransitionIfNeeded(for: config)
      return config
    }

    /// Applies the dynamic instructions from `config` in-place to `transcript`.
    ///
    /// If `transcript` already starts with `.instructions(var existing)`, its `segments` and
    /// `toolDefinitions` are updated in-place while preserving `existing.id`. Otherwise, if `config`
    /// has non-empty instructions or tools, a new `.instructions` entry is inserted at index 0.
    ///
    /// - Parameters:
    ///   - config: The resolved dynamic configuration.
    ///   - transcript: The transcript to update in-place.
    /// - Returns: `true` if a new leading `.instructions` entry was inserted at index 0; `false`
    ///   otherwise.
    @discardableResult
    internal static func applyDynamicInstructions(
      from config: ResolvedConfiguration,
      to transcript: inout Transcript
    ) -> Bool {
      guard !config.isStatic else { return false }
      if case .instructions(var existing) = transcript.entries.first {
        existing.segments = config.instructionsSegments
        existing.toolDefinitions = config.instructionsToolDefinitions
        transcript.entries[0] = .instructions(existing)
        return false
      }
      guard !config.hasEmptyInstructions else { return false }
      let inserted = Transcript.Instructions(
        id: UUID().uuidString,
        segments: config.instructionsSegments,
        toolDefinitions: config.instructionsToolDefinitions
      )
      transcript.entries.insert(.instructions(inserted), at: 0)
      return true
    }

    /// Copies the leading `.instructions` entry from `source` into `target`, preserving or inserting
    /// it at index 0.
    internal static func syncLeadingInstructions(
      from source: Transcript,
      to target: inout Transcript
    ) {
      guard case .instructions(let updated) = source.entries.first else { return }
      if case .instructions = target.entries.first {
        target.entries[0] = .instructions(updated)
      } else {
        target.entries.insert(.instructions(updated), at: 0)
      }
    }

    /// Returns `transcript` with `toolDefinitions` in its leading instructions entry, as Apple's
    /// session stores transcripts given to `init(model:tools:transcript:)` and the `transcript`
    /// setter.
    ///
    /// If `toolDefinitions` is empty, `transcript` is returned unchanged. Otherwise, a leading
    /// instructions entry keeps its ID and segments and gets `toolDefinitions` in place of its own,
    /// and a transcript without one gets a new leading entry with no segments.
    ///
    /// - Parameters:
    ///   - transcript: The transcript to store.
    ///   - toolDefinitions: The definitions of the session's tools that are included in instructions.
    ///   - insertedInstructionsID: The ID for an inserted instructions entry.
    /// - Returns: The transcript to store.
    internal static func transcript(
      _ transcript: Transcript,
      carryingToolDefinitions toolDefinitions: [Transcript.ToolDefinition],
      insertedInstructionsID: String
    ) -> Transcript {
      guard !toolDefinitions.isEmpty else { return transcript }
      var result = transcript
      if case .instructions(var instructions) = result.entries.first {
        instructions.toolDefinitions = toolDefinitions
        result.entries[0] = .instructions(instructions)
      } else {
        let inserted = Transcript.Instructions(
          id: insertedInstructionsID,
          segments: [],
          toolDefinitions: toolDefinitions
        )
        result.entries.insert(.instructions(inserted), at: 0)
      }
      return result
    }
  }

  extension LanguageModelSession {
    /// The policy governing how the transcript is handled when an error occurs.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final var transcriptErrorHandlingPolicy: TranscriptErrorHandlingPolicy? {
      get {
        state.withLock { $0.transcriptErrorHandlingPolicy }
      }
      set {
        state.withLock { $0.transcriptErrorHandlingPolicy = newValue }
      }
    }

    /// A Boolean value indicating whether the session is currently generating a response.
    public final var isResponding: Bool {
      observationRegistrar.access(self, keyPath: \.isResponding)
      return state.withLock { $0.isResponding }
    }

    /// The cumulative token usage across completed turns in this session.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final var usage: LanguageModelSession.Usage {
      observationRegistrar.access(self, keyPath: \.usage)
      return state.withLock { $0.usage }
    }
  }

  // MARK: - Observation

  /// Observation tracks `transcript`, `isResponding`, and `usage`, like Apple's session.
  ///
  /// `transcriptErrorHandlingPolicy` doesn't notify observers, matching Apple. The conformance is
  /// spelled `nonisolated Observable`, as in Apple's interface; the session isn't actor-isolated, so
  /// the modifier only documents that the conformance is usable from any isolation domain.
  extension LanguageModelSession: nonisolated Observable {}

  extension LanguageModelSession {
    /// Mutates the session state under its lock and notifies observers of `keyPath`.
    ///
    /// Observers' `willSet` callbacks run before the lock is taken and `didSet` callbacks after it
    /// is released, so an observer can read the session (for example `session.transcript`) without
    /// deadlocking on the non-reentrant state lock. The registrar notifies even if `body` leaves
    /// the value unchanged or throws, as Apple's session does.
    ///
    /// - Parameters:
    ///   - keyPath: The observable property that `body` mutates.
    ///   - body: The mutation to perform while holding the state lock.
    /// - Returns: The value `body` returns.
    internal func mutateState<Member, Result>(
      notifying keyPath: KeyPath<LanguageModelSession, Member>,
      _ body: (inout State) throws -> Result
    ) rethrows -> Result {
      try withNotificationScope {
        try observationRegistrar.withMutation(of: self, keyPath: keyPath) {
          try state.withLock { state in
            try body(&state)
          }
        }
      }
    }

    /// One in-progress observer notification of one session.
    internal struct NotificationScope: Hashable, Sendable {
      /// The notifying session.
      let session: ObjectIdentifier

      /// The notification's process-unique ID.
      let id: UInt64
    }

    /// The source of process-unique notification IDs, so a stale ID never matches a later
    /// notification, even of a new session at the same address.
    private static let notificationScopeCounter = Atomic<UInt64>(0)

    /// The notifications the current code runs inside, outermost first.
    ///
    /// Observers run synchronously inside a notification, so they see its scope. A `Task` that an
    /// observer starts inherits the value but outlives the notification; its scopes are then no
    /// longer active (see `isNotifyingObservers`).
    @TaskLocal internal static var notificationScopes: [NotificationScope] = []

    /// Whether the current code runs synchronously inside one of this session's observer
    /// notifications that is still in progress, which is where an observer's `onChange` runs.
    internal var isNotifyingObservers: Bool {
      let identifier = ObjectIdentifier(self)
      let candidates = Self.notificationScopes.filter { $0.session == identifier }.map(\.id)
      guard !candidates.isEmpty else { return false }
      return state.withLock { state in
        candidates.contains { state.activeNotificationScopes.contains($0) }
      }
    }

    /// Runs `body`, which notifies observers, inside a new notification scope of this session.
    ///
    /// The scope's ID is active in the session state only while `body` runs, and the task-local
    /// stack keeps the scopes of outer notifications (of this or other sessions), so a write from
    /// an observer of another session that this session's observer triggered still counts.
    private func withNotificationScope<Result>(_ body: () throws -> Result) rethrows -> Result {
      let id = Self.notificationScopeCounter.wrappingAdd(1, ordering: .relaxed).newValue
      state.withLock { _ = $0.activeNotificationScopes.insert(id) }
      defer { state.withLock { _ = $0.activeNotificationScopes.remove(id) } }
      let scope = NotificationScope(session: ObjectIdentifier(self), id: id)
      return try Self.$notificationScopes.withValue(Self.notificationScopes + [scope]) {
        try body()
      }
    }

    /// Notifies observers of `keyPath` without changing it.
    ///
    /// Used where Apple's session reports a change at a point where the fake has nothing left to
    /// write, such as the end of a streamed turn whose events were already applied live.
    ///
    /// - Parameter keyPath: The observable property to report as changed.
    internal func notifyObservers<Member>(of keyPath: KeyPath<LanguageModelSession, Member>) {
      withNotificationScope {
        observationRegistrar.withMutation(of: self, keyPath: keyPath) {}
      }
    }
  }

  extension LanguageModelSession {
    /// Creates a session with a system language model and optional string instructions.
    ///
    /// - Parameters:
    ///   - model: The ``SystemLanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - instructions: The optional instructions guiding model responses.
    @_disfavoredOverload
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public convenience init(
      model: SystemLanguageModel = .default,
      tools: [any Tool] = [],
      instructions: String? = nil
    ) {
      let parsedInstructions = instructions.map { Instructions($0) }
      self.init(model: model, tools: tools, instructions: parsedInstructions)
    }

    /// Creates a session with a system language model and instructions created by a closure.
    ///
    /// - Parameters:
    ///   - model: The ``SystemLanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - instructions: A closure building the session instructions.
    /// - Throws: An error thrown while building instructions.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public convenience init(
      model: SystemLanguageModel = .default,
      tools: [any Tool] = [],
      @InstructionsBuilder instructions: () throws -> Instructions
    ) rethrows {
      let builtInstructions = try instructions()
      self.init(model: model, tools: tools, instructions: builtInstructions)
    }

    /// Creates a session with a system language model and optional structured instructions.
    ///
    /// - Parameters:
    ///   - model: The ``SystemLanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - instructions: The optional ``Instructions`` guiding model responses.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public convenience init(
      model: SystemLanguageModel = .default,
      tools: [any Tool] = [],
      instructions: Instructions? = nil
    ) {
      self.init(_genericModel: model, tools: tools, instructions: instructions)
    }

    /// Creates a session with a system language model and an existing transcript.
    ///
    /// - Parameters:
    ///   - model: The ``SystemLanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - transcript: The existing ``Transcript`` to populate the session with.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public convenience init(
      model: SystemLanguageModel = .default,
      tools: [any Tool] = [],
      transcript: Transcript
    ) {
      let registry = SessionModelRegistry()
      self.init(
        modelBox: registry.box(for: model),
        tools: tools,
        transcript: transcript,
        modelRegistry: registry
      )
    }

    /// Creates a session with a language model and instructions created by a closure.
    ///
    /// - Parameters:
    ///   - model: The ``LanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - instructions: A closure building the session instructions.
    /// - Throws: An error thrown while building instructions.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public convenience init<Failure>(
      model: some LanguageModel,
      tools: [any Tool] = [],
      @InstructionsBuilder instructions: () throws(Failure) -> Instructions
    ) throws(Failure) where Failure: Swift.Error {
      let builtInstructions = try instructions()
      self.init(_genericModel: model, tools: tools, instructions: builtInstructions)
    }

    /// Creates a session with a language model and an existing transcript.
    ///
    /// - Parameters:
    ///   - model: The ``LanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - transcript: The existing ``Transcript`` to populate the session with.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public convenience init(
      model: some LanguageModel,
      tools: [any Tool] = [],
      transcript: Transcript
    ) {
      let registry = SessionModelRegistry()
      self.init(
        modelBox: registry.box(for: model),
        tools: tools,
        transcript: transcript,
        modelRegistry: registry
      )
    }

    /// Creates a session with a language model and optional structured instructions.
    ///
    /// - Parameters:
    ///   - model: The ``LanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - instructions: The optional ``Instructions`` guiding model responses.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public convenience init(
      model: some LanguageModel,
      tools: [any Tool] = [],
      instructions: Instructions? = nil
    ) {
      self.init(_genericModel: model, tools: tools, instructions: instructions)
    }

    /// Shared implementation for `init(model:tools:instructions:)`.
    internal convenience init(
      _genericModel model: some LanguageModel,
      tools: [any Tool],
      instructions: Instructions?
    ) {
      let uniqueTools = Self.deduplicateTools(tools)
      var entries: [Transcript.Entry] = []
      if instructions != nil || !uniqueTools.isEmpty {
        let segments = instructions?.segments ?? []
        let toolDefinitions =
          uniqueTools
          .filter { $0.includesSchemaInInstructions }
          .map { Transcript.ToolDefinition(tool: $0) }
        let instructionsEntry = Transcript.Instructions(
          id: UUID().uuidString,
          segments: segments,
          toolDefinitions: toolDefinitions
        )
        entries.append(.instructions(instructionsEntry))
      }
      let registry = SessionModelRegistry()
      self.init(
        modelBox: registry.box(for: model),
        tools: uniqueTools,
        transcript: Transcript(entries: entries),
        modelRegistry: registry
      )
    }

    /// Creates a session with a language model and optional string instructions.
    ///
    /// - Parameters:
    ///   - model: The ``LanguageModel`` to use for the session.
    ///   - tools: The tools available to the model during the session.
    ///   - instructions: The optional instructions guiding model responses.
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public convenience init(
      model: some LanguageModel,
      tools: [any Tool] = [],
      instructions: String? = nil
    ) {
      let parsedInstructions = instructions.map { Instructions($0) }
      self.init(_genericModel: model, tools: tools, instructions: parsedInstructions)
    }

    /// Creates a session with dynamic instructions and initial conversation history.
    ///
    /// - Parameters:
    ///   - model: The ``LanguageModel`` to use for the session.
    ///   - dynamicInstructions: The dynamic instructions to evaluate during the session.
    ///   - history: The initial transcript entries to populate the session with.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public convenience init(
      model: some LanguageModel = SystemLanguageModel.default,
      dynamicInstructions: sending some DynamicInstructions,
      history: some Collection<Transcript.Entry> = []
    ) {
      let registry = SessionModelRegistry()
      let box = registry.box(for: model)
      let erasedInstructions = AnyDynamicInstructions(dynamicInstructions)
      nonisolated(unsafe) let transferredInstructions = erasedInstructions
      let source = SessionConfigurationSource.dynamicInstructions(
        modelBox: box,
        evaluate: { properties in
          unsafe DynamicInstructionsFlattener.flatten(transferredInstructions) { target in
            SessionPropertyBinder.bind(target, to: properties)
          }
        }
      )
      self.init(
        configurationSource: source,
        modelRegistry: registry,
        modelBox: box,
        seedHistory: Array(history)
      )
    }

    /// Creates a session configured by a dynamic profile and initial conversation history.
    ///
    /// - Parameters:
    ///   - profile: The dynamic profile defining the session configuration.
    ///   - history: The initial transcript entries to populate the session with.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public convenience init(
      profile: sending some DynamicProfile,
      history: some Collection<Transcript.Entry> = []
    ) {
      let registry = SessionModelRegistry()
      let fallbackBox: any AnyModelBox = registry.box(for: SystemLanguageModel.default)
      let erasedProfile = AnyDynamicProfile(erasing: profile)
      nonisolated(unsafe) let transferredProfile = erasedProfile
      let source = SessionConfigurationSource.dynamicProfile(
        registry: registry,
        evaluate: { reg, properties in
          unsafe DynamicProfileEvaluator.evaluate(
            transferredProfile,
            registry: reg,
            properties: properties
          )
        }
      )
      self.init(
        configurationSource: source,
        modelRegistry: registry,
        modelBox: fallbackBox,
        seedHistory: Array(history)
      )
    }
  }

  extension LanguageModelSession {
    /// Prewarms the underlying model using the current transcript and an optional prompt.
    ///
    /// - Parameter promptPrefix: An optional prompt prefix to include in prewarming.
    public final func prewarm(promptPrefix: Prompt? = nil) {
      let activeModelBox =
        configurationSource.isStatic ? modelBox : resolveConfiguration().modelBox
      var prewarmTranscript = state.withLock { $0.transcript }
      if let promptPrefix {
        let promptEntry = Transcript.Prompt(
          id: UUID().uuidString,
          metadata: [:],
          segments: promptPrefix.segments,
          options: GenerationOptions(),
          responseFormat: nil
        )
        prewarmTranscript.append(.prompt(promptEntry))
      }
      activeModelBox.prewarm(transcript: prewarmTranscript)
    }
  }

  extension LanguageModelSession: Sendable {}

  // MARK: - Internal Turn & Event Processing Engine

  extension LanguageModelSession {
    /// Reverts the session transcript to `preCallTranscript` without incrementing
    /// `externalMutationCount`, and notifies `transcript` observers.
    internal func revertTranscript(to preCallTranscript: Transcript) {
      mutateState(notifying: \.transcript) { state in
        state.transcript = preCallTranscript
      }
    }

    /// Mutates the transcript internally, and notifies `transcript` observers, after checking under
    /// the same lock that it wasn't written externally since `mutationCount`.
    ///
    /// Observers run in `willSet`, before `body` takes the lock, so an observer that writes
    /// `session.transcript` from `onChange` is detected here instead of being overwritten by `body`.
    ///
    /// - Parameters:
    ///   - mutationCount: The `externalMutationCount` captured when the call started.
    ///   - body: The mutation to perform if the transcript is unchanged.
    /// - Returns: The value `body` returns.
    /// - Throws: `LanguageModelSession.Error.transcriptMutationWhileResponding` if the transcript
    ///   was written externally, or any error `body` throws.
    internal func withCheckedTranscript<R>(
      since mutationCount: UInt64,
      _ body: (inout Transcript) throws -> R
    ) throws -> R {
      try mutateState(notifying: \.transcript) { state in
        guard state.externalMutationCount == mutationCount else {
          throw LanguageModelSession.Error.transcriptMutationWhileResponding
        }
        return try body(&state.transcript)
      }
    }

    /// Replaces the transcript internally, and notifies `transcript` observers, after checking under
    /// the same lock that it wasn't written externally since `mutationCount`.
    ///
    /// - Parameters:
    ///   - transcript: The new transcript.
    ///   - mutationCount: The `externalMutationCount` captured when the call started.
    /// - Throws: `LanguageModelSession.Error.transcriptMutationWhileResponding` if the transcript
    ///   was written externally.
    internal func setCheckedTranscript(_ transcript: Transcript, since mutationCount: UInt64) throws
    {
      try withCheckedTranscript(since: mutationCount) { $0 = transcript }
    }

    /// Reads the transcript after checking under the same lock that it wasn't written externally
    /// since `mutationCount`. Doesn't notify observers.
    ///
    /// - Parameter mutationCount: The `externalMutationCount` captured when the call started.
    /// - Returns: The current transcript.
    /// - Throws: `LanguageModelSession.Error.transcriptMutationWhileResponding` if the transcript
    ///   was written externally.
    internal func checkedTranscript(since mutationCount: UInt64) throws -> Transcript {
      try state.withLock { state in
        guard state.externalMutationCount == mutationCount else {
          throw LanguageModelSession.Error.transcriptMutationWhileResponding
        }
        return state.transcript
      }
    }

    /// Applies `events` with a fresh reducer to the current transcript after an external write,
    /// and notifies `transcript` observers.
    ///
    /// This matches Apple's session after an external write: it keeps the written
    /// transcript and appends the call's events to it (`respond`: the whole turn; streams: the
    /// event being applied), then throws `transcriptMutationWhileResponding`. Under
    /// `.revertTranscript` the caller reverts afterwards. Nothing is applied if an observer wrote
    /// from inside one of this session's notifications, because those calls always revert.
    ///
    /// - Parameters:
    ///   - events: The events to apply, in order.
    ///   - schema: The call's generation schema, if any.
    ///   - generationID: The call's generation identifier.
    ///   - reentrantMutationCount: The `reentrantMutationCount` captured when the call started.
    ///   - propagatingErrors: Whether an event that fails to apply throws its error (streams) or
    ///     stops the merge, keeping the events applied so far (`respond`).
    /// - Throws: The error from the first event that fails to apply, if `propagatingErrors`; the
    ///   transcript is then unchanged.
    internal func mergeEventsAfterExternalWrite(
      _ events: [LanguageModelExecutorGenerationChannel.Event],
      schema: GenerationSchema?,
      generationID: GenerationID,
      reentrantMutationCount: UInt64,
      propagatingErrors: Bool
    ) throws {
      // Skip the notification too when an observer wrote; those calls revert instead.
      let observerWrote = state.withLock { $0.reentrantMutationCount != reentrantMutationCount }
      guard !observerWrote else { return }
      try mutateState(notifying: \.transcript) { state in
        guard state.reentrantMutationCount == reentrantMutationCount else { return }
        var reducer = TurnReducer(schema: schema, generationID: generationID)
        var merged = state.transcript
        for event in events {
          do {
            _ = try reducer.apply(event, to: &merged)
          } catch {
            if propagatingErrors {
              throw error
            }
            break
          }
        }
        state.transcript = merged
      }
    }

    /// Returns whether to restore the pre-call transcript after `error`.
    ///
    /// `.revertTranscript` (the default) always reverts. `.preserveTranscript` keeps the transcript,
    /// including an external write and the events merged onto it, except when an observer wrote
    /// from inside one of this session's notifications: those mutation errors always revert.
    ///
    /// - Parameters:
    ///   - error: The error the call is about to throw.
    ///   - reentrantMutationCount: The `reentrantMutationCount` captured when the call started.
    /// - Returns: Whether to revert.
    internal func shouldRevert(after error: any Swift.Error, reentrantMutationCount: UInt64) -> Bool
    {
      let (policy, observerWrote) = state.withLock {
        (
          $0.transcriptErrorHandlingPolicy ?? .revertTranscript,
          $0.reentrantMutationCount != reentrantMutationCount
        )
      }
      guard policy.behavior != .revert else { return true }
      if case LanguageModelSession.Error.transcriptMutationWhileResponding = error {
        return observerWrote
      }
      return false
    }

    /// Sets whether a request is active, and notifies `isResponding` observers.
    internal func setResponding(_ isResponding: Bool) {
      mutateState(notifying: \.isResponding) { state in
        state.isResponding = isResponding
      }
    }

    /// Adds token usage from a completed turn to the session's cumulative usage, and notifies
    /// `usage` observers.
    internal func addSessionUsage(_ turnUsage: LanguageModelSession.Usage) {
      mutateState(notifying: \.usage) { state in
        let current = state.usage
        state.usage = LanguageModelSession.Usage(
          input: .init(
            totalTokenCount: current.input.totalTokenCount + turnUsage.input.totalTokenCount,
            cachedTokenCount: current.input.cachedTokenCount + turnUsage.input.cachedTokenCount
          ),
          output: .init(
            totalTokenCount: current.output.totalTokenCount + turnUsage.output.totalTokenCount,
            reasoningTokenCount: current.output.reasoningTokenCount
              + turnUsage.output.reasoningTokenCount
          ),
          metadata: [:]
        )
      }
    }

    /// Builds an executor generation request for the current turn.
    internal func buildGenerationRequest(
      id: UUID,
      transcript: Transcript,
      tools: [any Tool],
      options: GenerationOptions,
      contextOptions: ContextOptions,
      schema: GenerationSchema?,
      metadata: [String: any ConvertibleToGeneratedContent]
    ) -> LanguageModelExecutorGenerationRequest {
      let enabledTools: [Transcript.ToolDefinition] =
        if options.toolCallingMode == .disallowed {
          []
        } else {
          tools.map { Transcript.ToolDefinition(tool: $0) }
        }
      return LanguageModelExecutorGenerationRequest(
        id: id,
        transcript: transcript,
        enabledTools: enabledTools,
        schema: schema,
        generationOptions: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Validates model capabilities in Apple's exact precedence order:
    /// `guidedGeneration` -> `vision` -> `toolCalling` -> `reasoning`.
    internal func validateCapabilities(
      modelBox: any AnyModelBox,
      tools: [any Tool],
      prompt: Prompt,
      transcript: Transcript,
      options: GenerationOptions,
      contextOptions: ContextOptions,
      schema: GenerationSchema?
    ) throws {
      let capabilities = modelBox.capabilities

      if schema != nil && !capabilities.contains(.guidedGeneration) {
        throw LanguageModelError.unsupportedCapability(
          .init(
            capability: .guidedGeneration,
            debugDescription:
              "This model can't generate guided output. "
              + "Use a model with this capability."
          )
        )
      }

      if !capabilities.contains(.vision) {
        let hasImageInTranscript = transcript.contains { entry in
          guard case .prompt(let promptEntry) = entry else { return false }
          return Self.segmentsContainImage(promptEntry.segments)
        }
        let hasImageInPrompt = Self.segmentsContainImage(prompt.segments)
        if hasImageInTranscript || hasImageInPrompt {
          throw LanguageModelError.unsupportedCapability(
            .init(
              capability: .vision,
              debugDescription:
                "This model can't accept images. "
                + "Use a model with this capability."
            )
          )
        }
      }

      if !tools.isEmpty && options.toolCallingMode != .disallowed
        && !capabilities.contains(.toolCalling)
      {
        throw LanguageModelError.unsupportedCapability(
          .init(
            capability: .toolCalling,
            debugDescription:
              "This model can't call tools. "
              + "Use a model with this capability."
          )
        )
      }

      if contextOptions.reasoningLevel != nil && !capabilities.contains(.reasoning) {
        throw LanguageModelError.unsupportedCapability(
          .init(
            capability: .reasoning,
            debugDescription:
              "This model can't reason. "
              + "Use a model with this capability."
          )
        )
      }
    }

    /// Returns `true` if `segments` contains at least one image attachment segment.
    private static func segmentsContainImage(_ segments: [Transcript.Segment]) -> Bool {
      for segment in segments {
        if case .attachment(let attachment) = segment,
          case .image = attachment.content
        {
          return true
        }
      }
      return false
    }

    /// Validates that the model supports every `DataAttachment` and `DataEntry` content type in
    /// `transcript` and `prompt`.
    nonisolated(nonsending) internal func validateDataCapabilities(
      modelBox: any AnyModelBox,
      prompt: Transcript.Prompt? = nil,
      transcript: Transcript
    ) async throws {
      for entry in transcript {
        switch entry {
        #if compiler(>=6.4.2)
          case .data(let dataEntry):
            let supported = try await modelBox.supportsDataEntryType(dataEntry.contentType)
            if !supported {
              throw LanguageModelError.unsupportedTranscriptContent(
                .init(
                  unsupportedContent: [entry],
                  debugDescription:
                    "This model can't accept data entries of type "
                    + "\(dataEntry.contentType.identifier)."
                )
              )
            }
        #endif  // compiler(>=6.4.2)
        case .instructions(let instructions):
          if let type = try await Self.firstUnsupportedDataAttachmentType(
            in: instructions.segments,
            modelBox: modelBox
          ) {
            throw LanguageModelError.unsupportedTranscriptContent(
              .init(
                unsupportedContent: [entry],
                debugDescription:
                  "This model can't accept data attachments of type "
                  + "\(type.identifier)."
              )
            )
          }
        case .prompt(let promptEntry):
          if let type = try await Self.firstUnsupportedDataAttachmentType(
            in: promptEntry.segments,
            modelBox: modelBox
          ) {
            throw LanguageModelError.unsupportedTranscriptContent(
              .init(
                unsupportedContent: [entry],
                debugDescription:
                  "This model can't accept data attachments of type "
                  + "\(type.identifier)."
              )
            )
          }
        case .toolOutput(let toolOutput):
          if let type = try await Self.firstUnsupportedDataAttachmentType(
            in: toolOutput.segments,
            modelBox: modelBox
          ) {
            throw LanguageModelError.unsupportedTranscriptContent(
              .init(
                unsupportedContent: [entry],
                debugDescription:
                  "This model can't accept data attachments of type "
                  + "\(type.identifier)."
              )
            )
          }
        case .response(let response):
          if let type = try await Self.firstUnsupportedDataAttachmentType(
            in: response.segments,
            modelBox: modelBox
          ) {
            throw LanguageModelError.unsupportedTranscriptContent(
              .init(
                unsupportedContent: [entry],
                debugDescription:
                  "This model can't accept data attachments of type "
                  + "\(type.identifier)."
              )
            )
          }
        case .reasoning, .toolCalls:
          break
        }
      }

      if let prompt,
        let type = try await Self.firstUnsupportedDataAttachmentType(
          in: prompt.segments,
          modelBox: modelBox
        )
      {
        throw LanguageModelError.unsupportedTranscriptContent(
          .init(
            unsupportedContent: [.prompt(prompt)],
            debugDescription:
              "This model can't accept data attachments of type "
              + "\(type.identifier)."
          )
        )
      }
    }

    /// Returns the first `UTType` in `segments` that `modelBox` does not support as a data
    /// attachment, or `nil` if all data attachments in `segments` are supported.
    nonisolated(nonsending) private static func firstUnsupportedDataAttachmentType(
      in segments: [Transcript.Segment],
      modelBox: any AnyModelBox
    ) async throws -> UTType? {
      #if compiler(>=6.4.2)
        for segment in segments {
          if case .attachment(let attachment) = segment,
            case .data(let dataAttachment) = attachment.content
          {
            let supported = try await modelBox.supportsDataAttachmentType(
              dataAttachment.contentType)
            if !supported {
              return dataAttachment.contentType
            }
          }
        }
      #endif  // compiler(>=6.4.2)
      return nil
    }

    /// State tracked for a single executor turn when reducing channel events into a transcript.
    internal struct TurnReducer {
      /// Discriminator for transcript entry kinds produced by channel events.
      enum EntryKind: Equatable {
        /// A response entry.
        case response
        /// A reasoning entry.
        case reasoning
        /// A tool-calls entry.
        case toolCalls
        #if compiler(>=6.4.2)
          /// A data entry.
          case data
        #endif  // compiler(>=6.4.2)
      }

      /// Key identifying a tool call within a specific transcript entry.
      struct CallKey: Hashable {
        /// Index of the `.toolCalls` entry in the transcript.
        let entryIndex: Int

        /// Identifier of the tool call.
        let callID: String
      }

      /// Key identifying a text or structured segment within a specific response entry.
      struct SegmentKey: Hashable {
        /// Index of the `.response` entry in the transcript.
        let entryIndex: Int

        /// Identifier of the segment.
        let segmentID: String
      }

      /// Optional generation schema when guided generation is active.
      let schema: GenerationSchema?

      /// Stable generation identifier assigned to structured content in this call.
      let generationID: GenerationID

      /// Entry kind of the most recently resolved non-usage event in this turn.
      var lastEventKind: EntryKind? = nil

      /// Transcript index of the most recently resolved entry in this turn.
      var lastEntryIndex: Int? = nil

      /// Indices of `.toolCalls` entries newly created during this turn.
      var createdToolCallsEntryIndices: [Int] = []

      /// Indices of `.reasoning` entries newly created during this turn.
      var createdReasoningEntryIndices: [Int] = []

      /// Indices of `.response` entries newly created during this turn.
      var createdResponseEntryIndices: [Int] = []

      /// Raw text buffer for each response segment (used when `schema != nil`).
      var responseSegmentTextBuffers: [SegmentKey: String] = [:]

      /// Raw JSON argument buffer for each tool call modified during this turn.
      var toolCallArgBuffers: [CallKey: String] = [:]

      /// Pending metadata for tool calls that received `updateMetadata` before `appendArguments`.
      var pendingToolCallMetadata: [CallKey: [String: GeneratedContent]] = [:]

      /// Cumulative usage for this turn.
      var usage: LanguageModelSession.Usage = .zero

      /// Creates a turn reducer for the given optional schema and generation identifier.
      init(schema: GenerationSchema?, generationID: GenerationID = GenerationID()) {
        self.schema = schema
        self.generationID = generationID
      }

      /// Applies a single channel event to `transcript`.
      ///
      /// - Returns: `true` if this event mutated a `.response` entry's segments.
      mutating func apply(
        _ event: LanguageModelExecutorGenerationChannel.Event,
        to transcript: inout Transcript
      ) throws -> Bool {
        switch event.kind {
        case .response(let responseEvent):
          if case .updateUsage(let usageEvent) = responseEvent.action.kind {
            applyUsageUpdate(usageEvent)
            return false
          }

          let entryIndex = resolveEntryIndex(
            kind: .response,
            explicitID: responseEvent.entryID,
            in: &transcript
          )
          guard case .response(var responseEntry) = transcript[entryIndex] else {
            return false
          }

          var shouldYieldSnapshot = false
          switch responseEvent.action.kind {
          case .appendText(let fragment):
            addOutputTokens(fragment.tokenCount)
            try appendResponseText(
              fragment.content,
              segmentID: fragment.segmentID,
              entryIndex: entryIndex,
              responseEntry: &responseEntry
            )
            shouldYieldSnapshot = true

          case .replaceTextSegment(let replacement):
            addOutputTokens(replacement.tokenCount)
            try replaceResponseText(
              replacement.content,
              segmentID: replacement.segmentID,
              entryIndex: entryIndex,
              responseEntry: &responseEntry
            )
            shouldYieldSnapshot = true

          case .addAttachmentSegment(let segment):
            responseEntry.segments.append(.attachment(segment))
            shouldYieldSnapshot = true

          case .removeAttachmentSegment(let id):
            responseEntry.segments.removeAll { seg in
              if case .attachment(let att) = seg {
                return att.id == id
              }
              return false
            }
            shouldYieldSnapshot = true

          case .updateMetadata(let metadata):
            responseEntry.storedMetadata = metadata.values
            shouldYieldSnapshot = false

          case .updateUsage:
            break
          }

          transcript[entryIndex] = .response(responseEntry)
          return shouldYieldSnapshot

        case .reasoning(let reasoningEvent):
          if case .updateUsage(let usageEvent) = reasoningEvent.action.kind {
            applyUsageUpdate(usageEvent)
            return false
          }

          let entryIndex = resolveEntryIndex(
            kind: .reasoning,
            explicitID: reasoningEvent.entryID,
            in: &transcript
          )
          guard case .reasoning(var reasoningEntry) = transcript[entryIndex] else {
            return false
          }

          switch reasoningEvent.action.kind {
          case .appendText(let fragment):
            addReasoningTokens(fragment.tokenCount)
            if let firstSeg = reasoningEntry.segments.first,
              case .text(let existing) = firstSeg
            {
              reasoningEntry.segments = [
                .text(
                  Transcript.TextSegment(
                    id: existing.id,
                    content: existing.content + fragment.content
                  )
                )
              ]
            } else {
              let newID = fragment.segmentID ?? UUID().uuidString
              reasoningEntry.segments = [
                .text(Transcript.TextSegment(id: newID, content: fragment.content))
              ]
            }

          case .replaceTextSegment(let replacement):
            addReasoningTokens(replacement.tokenCount)
            let newID = replacement.segmentID ?? UUID().uuidString
            reasoningEntry.segments = [
              .text(Transcript.TextSegment(id: newID, content: replacement.content))
            ]

          case .updateSignature(let sig):
            addReasoningTokens(sig.tokenCount)
            reasoningEntry.signature = sig.signature

          case .updateMetadata(let metadata):
            reasoningEntry.metadata = metadata.values

          case .updateUsage:
            break
          }

          transcript[entryIndex] = .reasoning(reasoningEntry)
          return false

        case .toolCalls(let toolCallsEvent):
          if case .updateUsage(let usageEvent) = toolCallsEvent.action.kind {
            applyUsageUpdate(usageEvent)
            return false
          }

          let targetCallID: String? =
            switch toolCallsEvent.action.kind {
            case .toolCall(let perCall): perCall.id
            case .removeToolCall(let callID): callID
            case .updateMetadata, .updateUsage: nil
            }

          let entryIndex: Int
          if toolCallsEvent.entryID == nil,
            let targetCallID,
            let existingIdx = transcript.indices.first(where: { idx in
              guard case .toolCalls(let existing) = transcript[idx] else { return false }
              return existing.calls.contains { $0.id == targetCallID }
            })
          {
            lastEventKind = .toolCalls
            lastEntryIndex = existingIdx
            entryIndex = existingIdx
          } else {
            entryIndex = resolveEntryIndex(
              kind: .toolCalls,
              explicitID: toolCallsEvent.entryID,
              in: &transcript
            )
          }
          guard case .toolCalls(var toolCallsEntry) = transcript[entryIndex] else {
            return false
          }

          switch toolCallsEvent.action.kind {
          case .toolCall(let perCall):
            let callID = perCall.id
            let callName = perCall.name
            let key = CallKey(entryIndex: entryIndex, callID: callID)

            switch perCall.action.kind {
            case .appendArguments(let fragment):
              addOutputTokens(fragment.tokenCount)
              let newBuffer = (toolCallArgBuffers[key] ?? "") + fragment.content
              toolCallArgBuffers[key] = newBuffer
              let jsonToParse = newBuffer.isEmpty ? "{}" : newBuffer
              let parsedArgs = try GeneratedContent(json: jsonToParse)

              if let existingCallIdx = toolCallsEntry.calls.firstIndex(where: { $0.id == callID }) {
                var existingCall = toolCallsEntry.calls[existingCallIdx]
                existingCall.toolName = callName
                existingCall.arguments = parsedArgs
                toolCallsEntry.calls[existingCallIdx] = existingCall
              } else {
                let initialMetadata = pendingToolCallMetadata.removeValue(forKey: key) ?? [:]
                let newCall = Transcript.ToolCall(
                  id: callID,
                  metadata: initialMetadata,
                  toolName: callName,
                  arguments: parsedArgs
                )
                toolCallsEntry.calls.append(newCall)
              }

            case .updateMetadata(let metadata):
              if let existingCallIdx = toolCallsEntry.calls.firstIndex(where: { $0.id == callID }) {
                toolCallsEntry.calls[existingCallIdx].metadata = metadata.values
              } else {
                pendingToolCallMetadata[key] = metadata.values
              }
            }

          case .removeToolCall(let callID):
            let key = CallKey(entryIndex: entryIndex, callID: callID)
            toolCallArgBuffers.removeValue(forKey: key)
            pendingToolCallMetadata.removeValue(forKey: key)
            toolCallsEntry.calls.removeAll { $0.id == callID }

          case .updateMetadata:
            // Entry-level toolCalls metadata has no backing field on Transcript.ToolCalls.
            break

          case .updateUsage:
            break
          }

          transcript[entryIndex] = .toolCalls(toolCallsEntry)
          return false

        #if compiler(>=6.4.2)
          case .data(let dataEvent):
            switch dataEvent.action.kind {
            case .update(let update):
              if let explicitID = dataEvent.entryID,
                let foundIndex = transcript.indices.first(where: { idx in
                  Self.entryMatches(transcript[idx], kind: .data, id: explicitID)
                })
              {
                lastEventKind = .data
                lastEntryIndex = foundIndex
                transcript[foundIndex] = .data(
                  Transcript.DataEntry(
                    id: explicitID,
                    contentType: update.contentType,
                    content: update.content,
                    metadata: update.metadata
                  )
                )
              } else {
                let newID = dataEvent.entryID ?? UUID().uuidString
                transcript.append(
                  .data(
                    Transcript.DataEntry(
                      id: newID,
                      contentType: update.contentType,
                      content: update.content,
                      metadata: update.metadata
                    )
                  )
                )
                lastEventKind = .data
                lastEntryIndex = transcript.count - 1
              }
            }
            return false
        #endif  // compiler(>=6.4.2)
        }
      }

      /// Replaces the turn usage accumulator wholesale from an `updateUsage` event.
      private mutating func applyUsageUpdate(
        _ usageEvent: LanguageModelExecutorGenerationChannel.Usage
      ) {
        // updateUsage replaces the turn accumulator wholesale and does NOT affect entry coalescing.
        self.usage = LanguageModelSession.Usage(
          input: .init(
            totalTokenCount: usageEvent.input.totalTokenCount,
            cachedTokenCount: usageEvent.input.cachedTokenCount
          ),
          output: .init(
            totalTokenCount: usageEvent.output.totalTokenCount,
            reasoningTokenCount: usageEvent.output.reasoningTokenCount
          ),
          metadata: usageEvent.metadata
        )
      }

      /// Increments output token count on the turn usage accumulator.
      private mutating func addOutputTokens(_ count: Int) {
        guard count != 0 else { return }
        usage = LanguageModelSession.Usage(
          input: usage.input,
          output: .init(
            totalTokenCount: usage.output.totalTokenCount + count,
            reasoningTokenCount: usage.output.reasoningTokenCount
          ),
          metadata: usage.metadata
        )
      }

      /// Increments both total output and reasoning token counts on the turn usage accumulator.
      private mutating func addReasoningTokens(_ count: Int) {
        guard count != 0 else { return }
        usage = LanguageModelSession.Usage(
          input: usage.input,
          output: .init(
            totalTokenCount: usage.output.totalTokenCount + count,
            reasoningTokenCount: usage.output.reasoningTokenCount + count
          ),
          metadata: usage.metadata
        )
      }

      /// Resolves an existing or newly appended transcript entry index for `kind` and `explicitID`.
      private mutating func resolveEntryIndex(
        kind: EntryKind,
        explicitID: String?,
        in transcript: inout Transcript
      ) -> Int {
        if let explicitID {
          if let foundIndex = transcript.indices.first(where: { idx in
            Self.entryMatches(transcript[idx], kind: kind, id: explicitID)
          }) {
            lastEventKind = kind
            lastEntryIndex = foundIndex
            return foundIndex
          }
          let createdIndex = appendNewEntry(kind: kind, id: explicitID, to: &transcript)
          lastEventKind = kind
          lastEntryIndex = createdIndex
          return createdIndex
        } else {
          if lastEventKind == kind,
            let existingIndex = lastEntryIndex,
            existingIndex < transcript.count,
            Self.entryHasKind(transcript[existingIndex], kind: kind)
          {
            return existingIndex
          }
          let newID = UUID().uuidString
          let createdIndex = appendNewEntry(kind: kind, id: newID, to: &transcript)
          lastEventKind = kind
          lastEntryIndex = createdIndex
          return createdIndex
        }
      }

      /// Appends a new empty entry of `kind` with `id` to `transcript` and returns its index.
      private mutating func appendNewEntry(
        kind: EntryKind,
        id: String,
        to transcript: inout Transcript
      ) -> Int {
        let entry: Transcript.Entry
        switch kind {
        case .response:
          entry = .response(Transcript.Response(id: id, metadata: [:], segments: []))
        case .reasoning:
          entry = .reasoning(
            Transcript.Reasoning(id: id, metadata: [:], segments: [], signature: nil)
          )
        case .toolCalls:
          entry = .toolCalls(Transcript.ToolCalls(id: id, []))
        #if compiler(>=6.4.2)
          case .data:
            entry = .data(
              Transcript.DataEntry(
                id: id,
                contentType: .data,
                content: Data(),
                metadata: GeneratedContent(properties: [:])
              )
            )
        #endif  // compiler(>=6.4.2)
        }
        transcript.append(entry)
        let index = transcript.count - 1
        if kind == .toolCalls {
          createdToolCallsEntryIndices.append(index)
        } else if kind == .reasoning {
          createdReasoningEntryIndices.append(index)
        } else if kind == .response {
          createdResponseEntryIndices.append(index)
        }
        return index
      }

      /// Returns `true` if `entry` has the given `EntryKind`.
      private static func entryHasKind(_ entry: Transcript.Entry, kind: EntryKind) -> Bool {
        switch (entry, kind) {
        case (.response, .response), (.reasoning, .reasoning), (.toolCalls, .toolCalls):
          return true
        #if compiler(>=6.4.2)
          case (.data, .data):
            return true
        #endif  // compiler(>=6.4.2)
        default:
          return false
        }
      }

      /// Returns `true` if `entry` matches both `kind` and `id`.
      private static func entryMatches(
        _ entry: Transcript.Entry,
        kind: EntryKind,
        id: String
      ) -> Bool {
        Self.entryHasKind(entry, kind: kind) && entry.id == id
      }

      /// Appends a text fragment to a `.response` entry, parsing structured content if `schema` is
      /// set.
      private mutating func appendResponseText(
        _ text: String,
        segmentID: String?,
        entryIndex: Int,
        responseEntry: inout Transcript.Response
      ) throws {
        let targetIndex: Int
        let targetSegID: String

        if let segmentID {
          if let foundIdx = responseEntry.segments.firstIndex(where: { seg in
            switch seg {
            case .text(let ts): return ts.id == segmentID
            case .structure(let ss): return ss.id == segmentID
            case .attachment: return false
            }
          }) {
            targetIndex = foundIdx
            targetSegID = segmentID
          } else {
            targetIndex = responseEntry.segments.count
            targetSegID = segmentID
            responseEntry.segments.append(.text(Transcript.TextSegment(id: segmentID, content: "")))
          }
        } else {
          if let lastSeg = responseEntry.segments.last,
            case .text(let ts) = lastSeg
          {
            targetIndex = responseEntry.segments.count - 1
            targetSegID = ts.id
          } else if schema != nil,
            let lastSeg = responseEntry.segments.last,
            case .structure(let ss) = lastSeg
          {
            targetIndex = responseEntry.segments.count - 1
            targetSegID = ss.id
          } else {
            let freshID = UUID().uuidString
            targetIndex = responseEntry.segments.count
            targetSegID = freshID
            responseEntry.segments.append(.text(Transcript.TextSegment(id: freshID, content: "")))
          }
        }

        let segKey = SegmentKey(entryIndex: entryIndex, segmentID: targetSegID)
        let existingText: String
        if let buffered = responseSegmentTextBuffers[segKey] {
          existingText = buffered
        } else if case .text(let ts) = responseEntry.segments[targetIndex] {
          existingText = ts.content
        } else {
          existingText = ""
        }

        let combined = existingText + text
        responseSegmentTextBuffers[segKey] = combined

        if let schema {
          var parsed = try GeneratedContent(json: combined)
          parsed.id = generationID
          responseEntry.segments[targetIndex] = .structure(
            Transcript.StructuredSegment(
              id: targetSegID,
              schemaName: schema.transcriptTypeName,
              content: parsed
            )
          )
        } else {
          responseEntry.segments[targetIndex] = .text(
            Transcript.TextSegment(id: targetSegID, content: combined)
          )
        }
      }

      /// Replaces a text segment in a `.response` entry, parsing structured content if `schema` is
      /// set.
      private mutating func replaceResponseText(
        _ text: String,
        segmentID: String?,
        entryIndex: Int,
        responseEntry: inout Transcript.Response
      ) throws {
        let targetIndex: Int
        let targetSegID: String

        if let segmentID {
          if let foundIdx = responseEntry.segments.firstIndex(where: { seg in
            switch seg {
            case .text(let ts): return ts.id == segmentID
            case .structure(let ss): return ss.id == segmentID
            case .attachment: return false
            }
          }) {
            targetIndex = foundIdx
            targetSegID = segmentID
          } else {
            targetIndex = responseEntry.segments.count
            targetSegID = segmentID
            responseEntry.segments.append(.text(Transcript.TextSegment(id: segmentID, content: "")))
          }
        } else {
          if let lastIdx = responseEntry.segments.indices.last(where: { idx in
            switch responseEntry.segments[idx] {
            case .text, .structure: return true
            case .attachment: return false
            }
          }) {
            targetIndex = lastIdx
            targetSegID = responseEntry.segments[lastIdx].id
          } else {
            let freshID = UUID().uuidString
            targetIndex = responseEntry.segments.count
            targetSegID = freshID
            responseEntry.segments.append(.text(Transcript.TextSegment(id: freshID, content: "")))
          }
        }

        let segKey = SegmentKey(entryIndex: entryIndex, segmentID: targetSegID)
        responseSegmentTextBuffers[segKey] = text

        if let schema {
          var parsed = try GeneratedContent(json: text)
          parsed.id = generationID
          responseEntry.segments[targetIndex] = .structure(
            Transcript.StructuredSegment(
              id: targetSegID,
              schemaName: schema.transcriptTypeName,
              content: parsed
            )
          )
        } else {
          responseEntry.segments[targetIndex] = .text(
            Transcript.TextSegment(id: targetSegID, content: text)
          )
        }
      }
    }

    /// Executes all tool calls from `.toolCalls` entries created in the just-completed turn.
    ///
    /// - Returns: `.some(toolCallOutputs)` if there were tool calls to execute, or `nil` if the turn
    ///   produced no tool calls.
    internal func executeTurnToolCalls(
      createdIndices: [Int],
      in transcript: Transcript,
      tools: [any Tool],
      onToolCallHooks: [@Sendable (Transcript.ToolCall) async throws -> Void] = []
    ) async throws -> [(Transcript.ToolCall, Transcript.ToolOutput)]? {
      var callsToRun: [Transcript.ToolCall] = []
      for index in createdIndices where index < transcript.count {
        if case .toolCalls(let toolCallsEntry) = transcript[index] {
          callsToRun.append(contentsOf: toolCallsEntry.calls)
        }
      }

      guard !callsToRun.isEmpty else {
        return nil
      }

      // Validate all tool names up-front before running any tool.
      var resolvedTools: [(Transcript.ToolCall, any Tool)] = []
      resolvedTools.reserveCapacity(callsToRun.count)
      for call in callsToRun {
        guard let tool = tools.first(where: { $0.name == call.toolName }) else {
          let available = tools.map { "\"\($0.name)\"" }.joined(separator: ", ")
          throw GeneratedContent.ParsingError(
            rawContent: "",
            debugDescription:
              "The model called a tool that isn't available.\n"
              + "Tool name: \(call.toolName)\n"
              + "Available tools: [\(available)]"
          )
        }
        resolvedTools.append((call, tool))
      }

      // Run the `onToolCall` hooks one call at a time, in call order, before any tool starts, so a
      // hook closure is never called concurrently with itself.
      if !onToolCallHooks.isEmpty {
        for (call, tool) in resolvedTools {
          try await Self.runToolCallHooks(onToolCallHooks, for: call, tool: tool)
        }
      }

      // Execute all tool calls concurrently and collect outputs in call order.
      let indexedOutputs = try await withThrowingTaskGroup(
        of: (Int, (Transcript.ToolCall, Transcript.ToolOutput)).self
      ) { group in
        for (idx, pair) in resolvedTools.enumerated() {
          let (call, tool) = pair
          group.addTask {
            let output = try await Self.invokeTool(tool, call: call)
            return (idx, (call, output))
          }
        }

        var results: [(Int, (Transcript.ToolCall, Transcript.ToolOutput))] = []
        results.reserveCapacity(resolvedTools.count)
        do {
          for try await item in group {
            results.append(item)
          }
        } catch {
          group.cancelAll()
          throw error
        }
        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
      }

      return indexedOutputs
    }

    /// Runs the `onToolCall` hooks for `call`, wrapping any thrown error in `ToolCallError`.
    ///
    /// - Parameters:
    ///   - hooks: The hooks to run, in order.
    ///   - call: The tool call the hooks observe.
    ///   - tool: The tool that `call` invokes.
    /// - Throws: A `ToolCallError` wrapping the first error a hook throws.
    private static func runToolCallHooks(
      _ hooks: [@Sendable (Transcript.ToolCall) async throws -> Void],
      for call: Transcript.ToolCall,
      tool: any Tool
    ) async throws {
      do {
        try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
          for hook in hooks {
            try await hook(call)
          }
        }
      } catch {
        throw LanguageModelSession.ToolCallError(tool: tool, underlyingError: error)
      }
    }

    /// Decodes tool arguments, invokes `tool`, and wraps any thrown error in `ToolCallError`.
    private static func invokeTool<T: Tool>(
      _ tool: T,
      call: Transcript.ToolCall
    ) async throws -> Transcript.ToolOutput {
      do {
        return try await SessionPropertyValues.$isExecutingToolCall.withValue(true) {
          let arguments = try T.Arguments(call.arguments)
          let output = try await tool.call(arguments: arguments)
          return Transcript.ToolOutput(
            id: call.id,
            toolName: call.toolName,
            segments: output.promptRepresentation.segments
          )
        }
      } catch {
        throw LanguageModelSession.ToolCallError(tool: tool, underlyingError: error)
      }
    }

    /// Extracts the last `.response` entry created during the current call after `promptIndex`.
    internal static func extractFinalResponseEntry(
      from transcript: Transcript,
      afterPromptIndex promptIndex: Int
    ) -> Transcript.Response? {
      let postPromptStart = min(max(0, promptIndex + 1), transcript.count)
      let responseEntry = transcript[postPromptStart...].reversed().first { entry in
        if case .response = entry { return true }
        return false
      }
      if case .response(let response) = responseEntry {
        return response
      }
      return nil
    }

    /// Extracts the raw `GeneratedContent` from the last `.response` entry created during the
    /// current call.
    internal static func extractRawResponseContent(
      from transcript: Transcript,
      afterPromptIndex promptIndex: Int,
      schema: GenerationSchema?,
      generationID: GenerationID
    ) throws -> GeneratedContent {
      let postPromptStart = promptIndex + 1
      guard postPromptStart <= transcript.count else {
        throw GeneratedContent.ParsingError(
          rawContent: "",
          debugDescription: "The call finished without a response."
        )
      }

      let responseEntry = transcript[postPromptStart...].reversed().first { entry in
        if case .response = entry { return true }
        return false
      }

      guard case .response(let response) = responseEntry else {
        throw GeneratedContent.ParsingError(
          rawContent: "",
          debugDescription: "The call finished without a response."
        )
      }

      if schema != nil {
        for segment in response.segments.reversed() {
          if case .structure(let structured) = segment {
            var content = structured.content
            if content.id == nil {
              content.id = generationID
            }
            return content
          }
        }
        var empty = GeneratedContent(
          kind: .structure(properties: [:], orderedKeys: []),
          id: generationID
        )
        empty.id = generationID
        return empty
      } else {
        let text = response.segments.compactMap { segment -> String? in
          if case .text(let ts) = segment {
            return ts.content
          }
          return nil
        }.joined()
        return GeneratedContent(kind: .string(text), id: generationID)
      }
    }
  }
#endif  // compiler(>=6.4)
