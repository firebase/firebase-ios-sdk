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
  import Observation
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  // MARK: - Test SessionProperty Entries

  extension SessionPropertyValues {
    /// A boolean flag used to switch conditional profiles in `DynamicProfileTests`.
    @SessionPropertyEntry
    var profileSwitchFlag: Bool = true

    /// A counter used to track hook and profile state in `DynamicProfileTests`.
    @SessionPropertyEntry
    var profileTurnCount: Int = 0
  }

  // MARK: - Test Support Types

  /// Thread-safe event log used by `DynamicProfileTests` to verify ordering of hooks and transforms.
  final class ProfileEventLog: Sendable {
    /// Mutex guarding the recorded events.
    private let entries = Mutex<[String]>([])

    /// Appends an event description to the log.
    ///
    /// - Parameter event: The event string to record.
    func record(_ event: String) {
      entries.withLock { $0.append(event) }
    }

    /// Returns a snapshot of all recorded events.
    var all: [String] {
      entries.withLock { $0 }
    }
  }

  /// A configurable mock language model that records received generation requests.
  struct RecordingProfileModel: LanguageModel {
    /// Recorded details of a single generation request.
    struct RecordedRequest: Sendable {
      /// The model identifier that handled the request.
      let modelID: String

      /// The transcript entries received by the executor.
      let transcriptEntries: [Transcript.Entry]

      /// The generation options received by the executor.
      let generationOptions: GenerationOptions

      /// The context options received by the executor.
      let contextOptions: ContextOptions

      /// The enabled tool names received by the executor.
      let enabledToolNames: [String]
    }

    /// Shared recorder box storing requests and scripted turn actions.
    final class Recorder: Sendable {
      /// Scripted action for a single executor turn.
      enum TurnAction: Sendable {
        /// Emits a text response with optional reasoning text.
        case text(String, reasoning: String? = nil)

        /// Emits tool calls with `(callID, toolName, argumentsJSON)`.
        case toolCalls([(String, String, String)], reasoning: String? = nil)
      }

      /// Mutex guarding requests, scripted turns, and executor init count.
      private let state = Mutex<
        (
          requests: [RecordedRequest],
          turns: [TurnAction],
          executorInitCount: Int
        )
      >(([], [], 0))

      /// Creates a recorder with scripted turn actions.
      ///
      /// - Parameter turns: The scripted turn actions to consume in order.
      init(turns: [TurnAction] = []) {
        state.withLock { $0.turns = turns }
      }

      /// Increments the executor initialization count.
      func recordExecutorInit() {
        state.withLock { $0.executorInitCount += 1 }
      }

      /// Returns the number of times an executor was initialized.
      var executorInitCount: Int {
        state.withLock { $0.executorInitCount }
      }

      /// Records a request and pops the next scripted turn action.
      ///
      /// - Parameter request: The recorded request metadata.
      /// - Returns: The next scripted turn action.
      func nextTurn(for request: RecordedRequest) -> TurnAction {
        state.withLock { state in
          state.requests.append(request)
          if state.turns.isEmpty {
            return .text("ok-\(request.modelID)")
          }
          return state.turns.removeFirst()
        }
      }

      /// Returns all recorded requests.
      var requests: [RecordedRequest] {
        state.withLock { $0.requests }
      }
    }

    /// Executor for `RecordingProfileModel`.
    struct Executor: LanguageModelExecutor {
      /// The associated language model type.
      typealias Model = RecordingProfileModel

      /// Configuration key for executor caching.
      struct Configuration: Hashable, Sendable {
        /// The configuration key string.
        let key: String
      }

      /// Creates a new executor instance.
      ///
      /// - Parameter configuration: The executor configuration.
      init(configuration: Configuration) throws {}

      /// Prewarms the executor.
      ///
      /// - Parameters:
      ///   - model: The language model instance.
      ///   - transcript: The transcript to prewarm with.
      func prewarm(model: RecordingProfileModel, transcript: Transcript) {}

      /// Executes a single turn according to the model's recorder script.
      ///
      /// - Parameters:
      ///   - request: The generation request.
      ///   - model: The language model instance.
      ///   - channel: The event channel to stream into.
      nonisolated(nonsending) func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: RecordingProfileModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        model.eventLog?.record("executor(\(model.id))")
        let recorded = RecordedRequest(
          modelID: model.id,
          transcriptEntries: Array(request.transcript),
          generationOptions: request.generationOptions,
          contextOptions: request.contextOptions,
          enabledToolNames: request.enabledToolDefinitions.map(\.name)
        )
        let action = model.recorder.nextTurn(for: recorded)
        switch action {
        case .text(let text, let reasoning):
          if let reasoning {
            await channel.send(
              .reasoning(entryID: UUID().uuidString, action: .appendText(reasoning, tokenCount: 1))
            )
          }
          await channel.send(
            .response(entryID: UUID().uuidString, action: .appendText(text, tokenCount: 2))
          )
        case .toolCalls(let calls, let reasoning):
          if let reasoning {
            await channel.send(
              .reasoning(entryID: UUID().uuidString, action: .appendText(reasoning, tokenCount: 1))
            )
          }
          let entryID = UUID().uuidString
          for (callID, name, argsJSON) in calls {
            await channel.send(
              .toolCalls(
                entryID: entryID,
                action: .toolCall(
                  id: callID,
                  name: name,
                  action: .appendArguments(argsJSON, tokenCount: 1)
                )
              )
            )
          }
        }
      }
    }

    /// Identifier of this model instance.
    let id: String

    /// Configuration key used for executor caching.
    let configKey: String

    /// Shared recorder instance.
    let recorder: Recorder

    /// Optional event log for ordering verification.
    let eventLog: ProfileEventLog?

    /// Creates a recording model.
    ///
    /// - Parameters:
    ///   - id: The model identifier.
    ///   - configKey: The executor configuration key.
    ///   - recorder: The shared request recorder.
    ///   - eventLog: Optional event log.
    init(
      id: String = "default",
      configKey: String = "default",
      recorder: Recorder = Recorder(),
      eventLog: ProfileEventLog? = nil
    ) {
      self.id = id
      self.configKey = configKey
      self.recorder = recorder
      self.eventLog = eventLog
    }

    /// Capabilities supported by `RecordingProfileModel`.
    var capabilities: LanguageModelCapabilities {
      LanguageModelCapabilities([.toolCalling, .guidedGeneration, .reasoning, .vision])
    }

    /// Executor configuration for this model.
    var executorConfiguration: Executor.Configuration {
      Executor.Configuration(key: configKey)
    }
  }

  /// Empty generable arguments for profile test tools.
  @Generable
  struct ProfileTestToolArgs {}

  /// A simple test tool for `DynamicProfileTests`.
  struct ProfileTestTool: Tool {
    /// The tool argument type.
    typealias Arguments = ProfileTestToolArgs

    /// The tool name.
    let name: String

    /// The tool description.
    let description = "A test tool for dynamic profiles."

    /// Event log to record tool execution.
    let eventLog: ProfileEventLog?

    /// Error to throw when called, if any.
    let errorToThrow: (any Error & Sendable)?

    /// Bound counter session property.
    @SessionProperty(\.profileTurnCount)
    var turnCount

    /// Creates a profile test tool.
    ///
    /// - Parameters:
    ///   - name: The tool name.
    ///   - eventLog: Optional event log.
    ///   - errorToThrow: Optional error to throw during `call`.
    init(
      name: String,
      eventLog: ProfileEventLog? = nil,
      errorToThrow: (any Error & Sendable)? = nil
    ) {
      self.name = name
      self.eventLog = eventLog
      self.errorToThrow = errorToThrow
    }

    /// Executes the tool.
    ///
    /// - Parameter arguments: The decoded tool arguments.
    /// - Returns: A string output containing the tool name and incremented turn count.
    func call(arguments: ProfileTestToolArgs) async throws -> String {
      turnCount += 1
      eventLog?.record("tool.\(name)(count=\(turnCount))")
      if let errorToThrow {
        throw errorToThrow
      }
      return "out-\(name)"
    }
  }

  /// Custom error used to test hook and tool failure propagation.
  enum ProfileTestError: Error, Equatable {
    /// Thrown from an `onPrompt` hook.
    case onPromptFailed

    /// Thrown from an `onReasoning` hook.
    case onReasoningFailed

    /// Thrown from an `onToolCall` hook.
    case onToolCallFailed

    /// Thrown from an `onToolOutput` hook.
    case onToolOutputFailed

    /// Thrown from an `onResponse` hook.
    case onResponseFailed
  }

  // MARK: - Test Profile Types

  /// A basic leaf profile wrapping instructions and a model modifier.
  struct BasicLeafProfile: LanguageModelSession.DynamicProfile {
    /// The model to apply.
    let model: RecordingProfileModel

    /// The instruction text.
    let instructionText: String

    /// The profile body.
    var body: some LanguageModelSession.DynamicProfile {
      Profile {
        Instructions(instructionText)
      }
      .model(model)
    }
  }

  /// A profile that switches between two branches using `@SessionProperty` and `if`/`else`.
  struct BranchingProfile: LanguageModelSession.DynamicProfile {
    /// Model for the first branch.
    let firstModel: RecordingProfileModel

    /// Model for the second branch.
    let secondModel: RecordingProfileModel

    /// Event log for lifecycle hooks.
    let log: ProfileEventLog

    /// Session property controlling which branch is active.
    @SessionProperty(\.profileSwitchFlag)
    var useFirst

    /// The conditional profile body.
    var body: some LanguageModelSession.DynamicProfile {
      if useFirst {
        Profile {
          Instructions("Branch A instructions")
        }
        .model(firstModel)
        .onActivate {
          log.record("A.inner.activate")
        }
        .onDeactivate {
          log.record("A.inner.deactivate")
        }
      } else {
        Profile {
          Instructions("Branch B instructions")
        }
        .model(secondModel)
        .onActivate {
          log.record("B.inner.activate")
        }
        .onDeactivate {
          log.record("B.inner.deactivate")
        }
      }
    }
  }

  /// A custom `DynamicProfileModifier` that applies temperature and lifecycle hooks.
  struct CustomTemperatureAndHookModifier: LanguageModelSession.DynamicProfileModifier {
    /// Temperature to apply.
    let temperature: Double

    /// Tag to record in `log`.
    let tag: String

    /// Event log for hook recording.
    let log: ProfileEventLog

    /// Session property read inside the modifier.
    @SessionProperty(\.profileTurnCount)
    var turnCount

    /// Wraps `content` with temperature and prompt/response hooks.
    ///
    /// - Parameter content: The wrapped profile content placeholder.
    /// - Returns: The modified dynamic profile.
    func body(content: Content) -> some LanguageModelSession.DynamicProfile {
      content
        .temperature(temperature)
        .onPrompt { _ in
          let current = turnCount
          log.record("\(tag).onPrompt(count=\(current))")
        }
        .onResponse { _ in
          log.record("\(tag).onResponse")
        }
    }
  }

  /// A minimal profile whose `body` is `Never` to test `AnyDynamicProfile` and `Profile` primitives.
  struct ErasedContainerProfile: LanguageModelSession.DynamicProfile {
    /// The type-erased child profile.
    let erased: LanguageModelSession.AnyDynamicProfile

    /// The profile body.
    var body: some LanguageModelSession.DynamicProfile {
      erased
    }
  }

  // MARK: - Test Suite

  /// Unit tests for the `DynamicProfile` subsystem, modifiers, and lifecycle hooks.
  @Suite("DynamicProfile Tests")
  struct DynamicProfileTests {
    @Test
    func profileInitEvaluatesInstructionsAndModel() async throws {
      let recorder = RecordingProfileModel.Recorder(turns: [.text("hello-world")])
      let model = RecordingProfileModel(id: "m1", recorder: recorder)
      let profile = BasicLeafProfile(model: model, instructionText: "You are helpful.")

      let session = LanguageModelSession(profile: profile)
      let response = try await session.respond(to: "Hi")

      #expect(response.content == "hello-world")
      let request = try #require(recorder.requests.first)
      #expect(request.modelID == "m1")
      #expect(session.transcript.count == 3)
    }

    @Test
    func anyDynamicProfileErasesConcreteProfile() async throws {
      let recorder = RecordingProfileModel.Recorder(turns: [
        .text("from-erased"),
        .text("from-erased"),
      ])
      let model = RecordingProfileModel(id: "erased-model", recorder: recorder)
      let leaf1 = LanguageModelSession.Profile { Instructions("Erased instructions") }.model(model)
      let leaf2 = LanguageModelSession.Profile { Instructions("Erased instructions") }.model(model)
      // `init(erasing:)` (which delegates to `init(_:)`) keeps the erased profile in a disconnected
      // region, so it can be sent to a session; passing an existential to `init(_:)` here would tie
      // it to the test's isolation.
      let erased1 = LanguageModelSession.AnyDynamicProfile(erasing: leaf1)
      let erased2 = LanguageModelSession.AnyDynamicProfile(erasing: leaf2)
      let container = ErasedContainerProfile(erased: erased1)

      let session1 = LanguageModelSession(profile: container)
      let session2 = LanguageModelSession(profile: erased2)
      let r1 = try await session1.respond(to: "P1")
      let r2 = try await session2.respond(to: "P2")

      #expect(r1.content == "from-erased")
      #expect(r2.content == "from-erased")
      #expect(recorder.requests.count == 2)
    }

    @Test
    func innerModifiersWinOverOuterModifiersAndPerCallWinsOverProfile() async throws {
      let recorder = RecordingProfileModel.Recorder(turns: [
        .text("turn-1"),
        .text("turn-2"),
      ])
      let innerModel = RecordingProfileModel(id: "inner-model", recorder: recorder)
      let outerModel = RecordingProfileModel(id: "outer-model", recorder: recorder)
      let existModel: any LanguageModel = outerModel
      let profile = LanguageModelSession.Profile {
        Instructions("Precedence test")
        ProfileTestTool(name: "t1")
      }
      .model(innerModel)
      .temperature(0.2)
      .maximumResponseTokens(50)
      .samplingMode(.greedy)
      .reasoningLevel(.light)
      .toolCallingMode(.allowed)
      .transcriptErrorHandlingPolicy(.preserveTranscript)
      .model(existModel)
      .temperature(0.9)
      .maximumResponseTokens(500)
      .samplingMode(.random(top: 10))
      .reasoningLevel(.deep)
      .toolCallingMode(.disallowed)
      .transcriptErrorHandlingPolicy(.revertTranscript)

      let session = LanguageModelSession(profile: profile)
      _ = try await session.respond(to: "Use profile defaults")
      _ = try await session.respond(
        to: "Override per-call",
        options: GenerationOptions(
          samplingMode: .random(top: 5),
          temperature: 0.75,
          maximumResponseTokens: 120,
          toolCallingMode: .disallowed
        ),
        contextOptions: ContextOptions(reasoningLevel: .moderate)
      )

      #expect(session.transcriptErrorHandlingPolicy?.behavior == .preserve)
      let req1 = try #require(recorder.requests.first)
      #expect(req1.modelID == "inner-model")
      #expect(req1.generationOptions.temperature == 0.2)
      #expect(req1.generationOptions.maximumResponseTokens == 50)
      #expect(req1.generationOptions.samplingMode == .greedy)
      #expect(req1.generationOptions.toolCallingMode == .allowed)
      #expect(req1.contextOptions.reasoningLevel == .light)
      #expect(req1.enabledToolNames == ["t1"])

      let req2 = try #require(recorder.requests.last)
      #expect(req2.generationOptions.temperature == 0.75)
      #expect(req2.generationOptions.maximumResponseTokens == 120)
      #expect(req2.generationOptions.samplingMode == .random(top: 5))
      #expect(req2.generationOptions.toolCallingMode == .disallowed)
      #expect(req2.contextOptions.reasoningLevel == .moderate)
      #expect(req2.enabledToolNames.isEmpty)
    }

    @Test
    func nilScalarOptionClearsInnerModifierValue() async throws {
      let recorder = RecordingProfileModel.Recorder()
      let model = RecordingProfileModel(id: "m", recorder: recorder)
      let profile = LanguageModelSession.Profile {
        Instructions("Clear options")
      }
      .model(model)
      .temperature(nil)
      .temperature(0.8)
      .maximumResponseTokens(nil)
      .maximumResponseTokens(100)

      let session = LanguageModelSession(profile: profile)
      _ = try await session.respond(to: "Check cleared")

      let req = try #require(recorder.requests.first)
      #expect(req.generationOptions.temperature == nil)
      #expect(req.generationOptions.maximumResponseTokens == nil)
    }

    @Test
    func customDynamicProfileModifierBindsSessionPropertyAndWrapsContent() async throws {
      let log = ProfileEventLog()
      let recorder = RecordingProfileModel.Recorder()
      let model = RecordingProfileModel(id: "m", recorder: recorder, eventLog: log)
      let modifier = CustomTemperatureAndHookModifier(temperature: 0.4, tag: "custom", log: log)
      let profile = LanguageModelSession.Profile {
        Instructions("Modified profile")
      }
      .model(model)
      .modifier(modifier)

      let session = LanguageModelSession(profile: profile)
      session.properties.profileTurnCount = 7
      _ = try await session.respond(to: "Hello")

      let req = try #require(recorder.requests.first)
      #expect(req.generationOptions.temperature == 0.4)
      #expect(log.all == ["custom.onPrompt(count=7)", "executor(m)", "custom.onResponse"])
    }

    @Test
    func historyTransformRunsOuterToInnerWithoutMutatingSessionTranscript() async throws {
      let log = ProfileEventLog()
      let recorder = RecordingProfileModel.Recorder()
      let model = RecordingProfileModel(id: "m", recorder: recorder, eventLog: log)
      let profile = LanguageModelSession.Profile {
        Instructions("System")
      }
      .model(model)
      .historyTransform { entries in
        log.record("transform.inner(count=\(entries.count))")
        return Array(entries.suffix(1))
      }
      .historyTransform { entries in
        log.record("transform.outer(count=\(entries.count))")
        return entries
      }

      let session = LanguageModelSession(profile: profile)
      _ = try await session.respond(to: "First prompt")

      let req = try #require(recorder.requests.first)
      #expect(req.transcriptEntries.count == 1)
      #expect(session.transcript.count == 3)
      #expect(
        log.all == [
          "transform.outer(count=2)",
          "transform.inner(count=2)",
          "executor(m)",
        ]
      )
    }

    @Test
    func lifecycleHooksExecuteInnerToOuterAcrossToolAndReasoningTurn() async throws {
      let log = ProfileEventLog()
      let recorder = RecordingProfileModel.Recorder(turns: [
        .toolCalls([("call-1", "weather", "{}")], reasoning: "thinking-1"),
        .text("sunny", reasoning: "thinking-2"),
      ])
      let model = RecordingProfileModel(id: "m", recorder: recorder, eventLog: log)
      let profile = LanguageModelSession.Profile {
        Instructions("Assistant")
        ProfileTestTool(name: "weather", eventLog: log)
      }
      .model(model)
      .onPrompt { _ in
        log.record("inner.onPrompt")
      }
      .onPrompt {
        log.record("outer.onPrompt")
      }
      .onReasoning { reasoning in
        log.record("inner.onReasoning(\(reasoning.segments.count))")
      }
      .onReasoning {
        log.record("outer.onReasoning")
      }
      .onToolCall { call in
        log.record("inner.onToolCall(\(call.toolName))")
      }
      .onToolCall {
        log.record("outer.onToolCall")
      }
      .onToolOutput { call, _ in
        log.record("inner.onToolOutput(\(call.toolName))")
      }
      .onToolOutput {
        log.record("outer.onToolOutput")
      }
      .onResponse { _ in
        log.record("inner.onResponse")
      }
      .onResponse {
        log.record("outer.onResponse")
      }

      let session = LanguageModelSession(profile: profile)
      let response = try await session.respond(to: "Weather?")

      #expect(response.content == "sunny")
      #expect(
        log.all == [
          "inner.onPrompt",
          "outer.onPrompt",
          "executor(m)",
          "inner.onReasoning(1)",
          "outer.onReasoning",
          "inner.onToolCall(weather)",
          "outer.onToolCall",
          "tool.weather(count=1)",
          "inner.onToolOutput(weather)",
          "outer.onToolOutput",
          "executor(m)",
          "inner.onReasoning(1)",
          "outer.onReasoning",
          "inner.onResponse",
          "outer.onResponse",
        ]
      )
    }

    @Test
    func onToolCallHooksRunForEveryCallBeforeAnyToolRuns() async throws {
      let log = ProfileEventLog()
      let recorder = RecordingProfileModel.Recorder(turns: [
        .toolCalls([("call-1", "weather", "{}"), ("call-2", "news", "{}")]),
        .text("done"),
      ])
      let model = RecordingProfileModel(id: "m", recorder: recorder)
      let profile = LanguageModelSession.Profile {
        Instructions("Assistant")
        ProfileTestTool(name: "weather", eventLog: log)
        ProfileTestTool(name: "news", eventLog: log)
      }
      .model(model)
      .onToolCall { call in
        log.record("onToolCall(\(call.toolName))")
      }

      let session = LanguageModelSession(profile: profile)
      _ = try await session.respond(to: "Weather and news?")

      #expect(
        Array(log.all.prefix(2)) == ["onToolCall(weather)", "onToolCall(news)"]
      )
      #expect(log.all.count == 4)
    }

    @Test
    func onToolCallErrorWrapsInToolCallErrorWhileOtherHookErrorsPropagateDirectly() async throws {
      let recorder = RecordingProfileModel.Recorder(turns: [
        .toolCalls([("c1", "weather", "{}")])
      ])
      let model = RecordingProfileModel(id: "m", recorder: recorder)
      let profile = LanguageModelSession.Profile {
        ProfileTestTool(name: "weather")
      }
      .model(model)
      .onToolCall { _ in
        throw ProfileTestError.onToolCallFailed
      }

      let session = LanguageModelSession(profile: profile)
      var caughtToolCallError: LanguageModelSession.ToolCallError?
      do {
        _ = try await session.respond(to: "Call tool")
      } catch let error as LanguageModelSession.ToolCallError {
        caughtToolCallError = error
      }

      let toolError = try #require(caughtToolCallError)
      #expect(toolError.tool.name == "weather")
    }

    @Test
    func onActivateAndOnDeactivateFireOnInitialSessionAndBranchTransitions() async throws {
      let log = ProfileEventLog()
      let recorder = RecordingProfileModel.Recorder(turns: [
        .text("r1"),
        .text("r2"),
      ])
      let modelA = RecordingProfileModel(id: "A", recorder: recorder, eventLog: log)
      let modelB = RecordingProfileModel(id: "B", recorder: recorder, eventLog: log)
      let profile = BranchingProfile(firstModel: modelA, secondModel: modelB, log: log)
        .onActivate {
          log.record("root.outer.activate")
        }
        .onDeactivate {
          log.record("root.outer.deactivate")
        }

      let session = LanguageModelSession(profile: profile)
      _ = try await session.respond(to: "Turn 1")
      session.properties.profileSwitchFlag = false
      _ = try await session.respond(to: "Turn 2")

      #expect(
        log.all == [
          "root.outer.activate",
          "A.inner.activate",
          "executor(A)",
          "A.inner.deactivate",
          "B.inner.activate",
          "executor(B)",
        ]
      )
    }

    @Test
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    func streamResponseRunsHooksInOrderAndSupportsConditionalBuilder() async throws {
      let log = ProfileEventLog()
      let recorder = RecordingProfileModel.Recorder(turns: [
        .text("streamed-answer", reasoning: "stream-reason")
      ])
      let model = RecordingProfileModel(id: "stream-m", recorder: recorder, eventLog: log)
      @LanguageModelSession.DynamicProfileBuilder
      func makeProfile(flag: Bool) -> some LanguageModelSession.DynamicProfile {
        if #available(macOS 15.0, iOS 18.0, *) {
          if flag {
            LanguageModelSession.Profile { Instructions("Stream profile") }
              .model(model)
              .onPrompt { _ in log.record("stream.onPrompt") }
              .onReasoning { _ in log.record("stream.onReasoning") }
              .onResponse { _ in log.record("stream.onResponse") }
          } else {
            LanguageModelSession.Profile { Instructions("Fallback") }.model(model)
          }
        } else {
          LanguageModelSession.Profile { Instructions("Old") }.model(model)
        }
      }

      let session = LanguageModelSession(profile: makeProfile(flag: true))
      let response = try await session.streamResponse(to: "Stream it").collect()

      #expect(response.content == "streamed-answer")
      #expect(
        log.all == [
          "stream.onPrompt",
          "executor(stream-m)",
          "stream.onReasoning",
          "stream.onResponse",
        ]
      )
    }

    @Test
    func hookErrorsRespectRevertAndPreserveTranscriptPolicies() async throws {
      let recorder = RecordingProfileModel.Recorder(turns: [
        .text("r1", reasoning: "think-1"),
        .text("r2", reasoning: "think-2"),
      ])
      let model = RecordingProfileModel(id: "m", recorder: recorder)
      let revertProfile = LanguageModelSession.Profile { Instructions("Sys") }
        .model(model)
        .transcriptErrorHandlingPolicy(.revertTranscript)
        .onReasoning { _ in
          throw ProfileTestError.onReasoningFailed
        }
      let preserveProfile = LanguageModelSession.Profile { Instructions("Sys") }
        .model(model)
        .transcriptErrorHandlingPolicy(.preserveTranscript)
        .onResponse { _ in
          throw ProfileTestError.onResponseFailed
        }

      let revertSession = LanguageModelSession(profile: revertProfile)
      let preserveSession = LanguageModelSession(profile: preserveProfile)
      var revertErr: ProfileTestError?
      var preserveErr: ProfileTestError?
      do {
        _ = try await revertSession.respond(to: "P1")
      } catch let error as ProfileTestError {
        revertErr = error
      }
      do {
        _ = try await preserveSession.respond(to: "P2")
      } catch let error as ProfileTestError {
        preserveErr = error
      }

      #expect(revertErr == .onReasoningFailed)
      #expect(revertSession.transcript.count == 1)
      #expect(preserveErr == .onResponseFailed)
      #expect(preserveSession.transcript.count == 4)
    }

    @Test
    func missingModelModifierDefaultsToSystemLanguageModel() async throws {
      let profile = LanguageModelSession.Profile {
        Instructions("Profile without an explicit model modifier")
      }

      let session = LanguageModelSession(profile: profile)
      #expect(session.transcript.count == 1)

      await #expect(throws: SystemLanguageModel.Error.self) {
        _ = try await session.respond(to: "Hello")
      }
    }

    @Test
    func deallocatingSessionDoesNotInvokeOnDeactivate() async throws {
      let log = ProfileEventLog()
      let model = RecordingProfileModel(id: "m", eventLog: log)
      do {
        let profile = LanguageModelSession.Profile { Instructions("Sys") }
          .model(model)
          .onActivate { log.record("activated") }
          .onDeactivate { log.record("deactivated") }
        let session = LanguageModelSession(profile: profile)
        _ = try await session.respond(to: "Run once")
      }

      #expect(log.all == ["activated", "executor(m)"])
    }
  }
#endif  // compiler(>=6.4)
