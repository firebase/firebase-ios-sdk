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
  import Observation
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - Test SessionProperty Entries

  /// A custom sendable struct used to test `@SessionPropertyEntry` and `_modify` accessors.
  struct TestSessionMetadata: Equatable, Sendable {
    /// A numeric revision counter.
    var revision: Int

    /// A list of string tags.
    var tags: [String]
  }

  /// A manual `SessionPropertyKey` used to test direct subscript access on `SessionPropertyValues`.
  struct ManualTagPropertyKey: SessionPropertyKey {
    /// The default value for `ManualTagPropertyKey`.
    static var defaultValue: String {
      "manual-default"
    }
  }

  extension SessionPropertyValues {
    /// An integer counter session property entry.
    @SessionPropertyEntry
    var testCounter: Int = 0

    /// A string label session property entry.
    @SessionPropertyEntry
    var testLabel: String = "initial"

    /// A structured metadata session property entry.
    @SessionPropertyEntry
    var testMetadata: TestSessionMetadata = TestSessionMetadata(revision: 1, tags: ["seed"])
  }

  // MARK: - Test Suite

  /// Unit tests for `SessionPropertyKey`, `SessionPropertyValues`, `@SessionPropertyEntry`,
  /// `LanguageModelSession.SessionProperty`, and `SessionPropertyBinder`.
  @Suite("SessionProperty Tests")
  struct SessionPropertyTests {
    // MARK: - Support Types

    /// A minimal mock language model for constructing test sessions.
    private struct StubModel: LanguageModel {
      /// A no-op executor for `StubModel`.
      struct Executor: LanguageModelExecutor {
        /// The associated language model type.
        typealias Model = StubModel

        /// Configuration for `Executor`.
        struct Configuration: Hashable, Sendable {
          /// Identifier key.
          let id: String
        }

        /// Creates an executor with `configuration`.
        init(configuration: Configuration) throws {}

        /// Prewarms the executor.
        func prewarm(model: StubModel, transcript: Transcript) {}

        /// Responds with a static text message.
        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: StubModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          await channel.send(.response(entryID: "r-1", action: .appendText("ok", tokenCount: 1)))
        }
      }

      /// Capabilities supported by `StubModel`.
      var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.toolCalling, .guidedGeneration, .reasoning, .vision])
      }

      /// The executor configuration for `StubModel`.
      var executorConfiguration: Executor.Configuration {
        Executor.Configuration(id: "stub")
      }
    }

    /// Empty generable arguments for test tools.
    @Generable
    struct EmptyArgs {}

    /// A tool that uses `Tool.SessionProperty` to read and increment `testCounter`.
    private struct CounterTool: Tool {
      /// The tool argument type.
      typealias Arguments = EmptyArgs

      /// The tool name.
      let name: String

      /// The tool description.
      let description = "Increments the session counter."

      /// The amount to add when called.
      let delta: Int

      /// Optional cyclic class reference to verify `SessionPropertyBinder` skips class graphs.
      let cycleNode: CyclicReferenceNode?

      /// Bound counter session property.
      @SessionProperty(\.testCounter)
      var counter

      /// Bound history session property.
      @SessionProperty(\.history)
      var history

      /// Exposes the synthesized `_counter` wrapper for detached-task capture testing.
      var capturedCounterWrapper: SessionProperty<Int> {
        _counter
      }

      /// Executes the tool and returns the updated counter string.
      func call(arguments: EmptyArgs) async throws -> String {
        counter += delta
        return "\(counter)"
      }
    }

    /// A reference type with a self-cycle to verify `SessionPropertyBinder` skips classes.
    private final class CyclicReferenceNode: Sendable {
      /// Self-referential link.
      let next = Mutex<CyclicReferenceNode?>(nil)
    }

    /// A nested container holding tools in structs, arrays, tuples, optionals, and enums.
    private struct NestedToolContainer {
      /// An enum wrapping a tool.
      enum Branch {
        case active(CounterTool)
        case inactive
      }

      /// Direct nested tool.
      var primaryTool: CounterTool

      /// Type-erased tool array.
      var erasedTools: [any Tool]

      /// Optional tool.
      var optionalTool: CounterTool?

      /// Nil optional tool.
      var nilTool: CounterTool?

      /// Tuple of tools.
      var tupleTools: (CounterTool, CounterTool)

      /// Enum branch containing a tool.
      var branch: Branch
    }

    // MARK: - Tests

    @Test
    func macroExpansionAndSubscriptAccess() {
      let session = LanguageModelSession(model: StubModel(), instructions: "System")

      session.properties.testCounter = 42
      session.properties.testLabel = "updated-label"
      session.properties.testMetadata.revision += 9
      session.properties.testMetadata.tags.append("mutated-in-place")
      session.properties[ManualTagPropertyKey.self] = "custom-manual"

      #expect(session.properties.testCounter == 42)
      #expect(session.properties.testLabel == "updated-label")
      #expect(
        session.properties.testMetadata
          == TestSessionMetadata(revision: 10, tags: ["seed", "mutated-in-place"])
      )
      #expect(session.properties[ManualTagPropertyKey.self] == "custom-manual")
    }

    @Test
    func defaultValuesBeforeMutation() {
      let session = LanguageModelSession(model: StubModel())

      let counter = session.properties.testCounter
      let label = session.properties.testLabel
      let metadata = session.properties.testMetadata
      let manual = session.properties[ManualTagPropertyKey.self]

      #expect(counter == 0)
      #expect(label == "initial")
      #expect(metadata == TestSessionMetadata(revision: 1, tags: ["seed"]))
      #expect(manual == "manual-default")
    }

    @Test
    func unboundSessionPropertyOutsideSession() {
      let counterProp = LanguageModelSession.SessionProperty(\.testCounter)
      let labelProp = LanguageModelSession.SessionProperty(\.testLabel)
      let historyProp = LanguageModelSession.SessionProperty(\.history)
      let initialCounter = counterProp.wrappedValue
      let initialLabel = labelProp.wrappedValue
      let initialHistoryCount = historyProp.wrappedValue.count

      counterProp.wrappedValue = 99
      labelProp.wrappedValue = "ignored"
      historyProp.wrappedValue = [
        .prompt(
          Transcript.Prompt(
            id: "p-1",
            segments: [.text(.init(id: "s-1", content: "ignored"))]
          )
        )
      ]

      #expect(initialCounter == 0)
      #expect(initialLabel == "initial")
      #expect(initialHistoryCount == 0)
      #expect(counterProp.wrappedValue == 0)
      #expect(labelProp.wrappedValue == "initial")
      #expect(historyProp.wrappedValue.isEmpty)
    }

    @Test
    func observationTrackingForCustomPropertiesAndHistory() {
      let session = LanguageModelSession(model: StubModel(), instructions: "Initial instructions")
      let counterChanged = Mutex(false)
      let labelChanged = Mutex(false)
      let historyChanged = Mutex(false)
      withObservationTracking {
        _ = session.properties.testCounter
      } onChange: {
        counterChanged.withLock { $0 = true }
      }
      withObservationTracking {
        _ = session.properties.testLabel
      } onChange: {
        labelChanged.withLock { $0 = true }
      }
      withObservationTracking {
        _ = session.properties.history
      } onChange: {
        historyChanged.withLock { $0 = true }
      }

      session.properties.testCounter = 11
      session.properties.history = [
        .prompt(
          Transcript.Prompt(
            id: "p-1",
            segments: [.text(.init(id: "s-1", content: "Hello"))]
          )
        )
      ]

      #expect(counterChanged.withLock { $0 })
      #expect(!labelChanged.withLock { $0 })
      #expect(historyChanged.withLock { $0 })
      #expect(session.properties.history.count == 1)
      #expect(session.transcript.count == 2)
    }

    @Test
    func historyWriteModesAndToolCallNoOp() {
      let session = LanguageModelSession(model: StubModel(), instructions: "Keep me")
      let initialMutationCount = session.state.withLock { $0.externalMutationCount }
      let promptA = Transcript.Entry.prompt(
        Transcript.Prompt(id: "p-a", segments: [.text(.init(id: "s-a", content: "Prompt A"))])
      )
      let promptB = Transcript.Entry.prompt(
        Transcript.Prompt(id: "p-b", segments: [.text(.init(id: "s-b", content: "Prompt B"))])
      )
      let promptC = Transcript.Entry.prompt(
        Transcript.Prompt(id: "p-c", segments: [.text(.init(id: "s-c", content: "Prompt C"))])
      )

      SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
        session.properties.history = [promptA]
      }
      let afterInternalCount = session.state.withLock { $0.externalMutationCount }
      let afterInternalHistoryCount = session.properties.history.count
      SessionPropertyValues.$isExecutingToolCall.withValue(true) {
        session.properties.history = [promptB]
      }
      let afterToolNoOpHistory = Array(session.properties.history)
      session.properties.history = [promptC]
      let afterExternalCount = session.state.withLock { $0.externalMutationCount }

      #expect(afterInternalCount == initialMutationCount)
      #expect(afterInternalHistoryCount == 1)
      #expect(afterToolNoOpHistory.count == 1)
      if case .prompt(let keptPrompt) = afterToolNoOpHistory.first {
        #expect(keptPrompt.id == "p-a")
      } else {
        Issue.record("Expected prompt-a to remain after tool-call history write no-op")
      }
      #expect(afterExternalCount == initialMutationCount + 1)
      #expect(session.properties.history.count == 1)
      #expect(session.transcript.count == 2)
    }

    @Test
    func binderBindsNestedToolsArraysOptionalsTuplesAndEnums() async throws {
      let session = LanguageModelSession(model: StubModel(), instructions: "Bind test")
      session.properties.testCounter = 10
      let cycle = CyclicReferenceNode()
      cycle.next.withLock { $0 = cycle }
      let container = NestedToolContainer(
        primaryTool: CounterTool(name: "primary", delta: 1, cycleNode: cycle),
        erasedTools: [
          CounterTool(name: "erased1", delta: 2, cycleNode: cycle),
          CounterTool(name: "erased2", delta: 3, cycleNode: nil),
        ],
        optionalTool: CounterTool(name: "optional", delta: 4, cycleNode: nil),
        nilTool: nil,
        tupleTools: (
          CounterTool(name: "tuple1", delta: 5, cycleNode: nil),
          CounterTool(name: "tuple2", delta: 6, cycleNode: nil)
        ),
        branch: .active(CounterTool(name: "branch", delta: 7, cycleNode: nil))
      )

      SessionPropertyBinder.bind(container, to: session.properties)
      _ = try await container.primaryTool.call(arguments: EmptyArgs())
      for tool in container.erasedTools {
        let counterTool = try #require(tool as? CounterTool)
        _ = try await counterTool.call(arguments: EmptyArgs())
      }
      let optionalTool = try #require(container.optionalTool)
      _ = try await optionalTool.call(arguments: EmptyArgs())
      _ = try await container.tupleTools.0.call(arguments: EmptyArgs())
      _ = try await container.tupleTools.1.call(arguments: EmptyArgs())
      if case .active(let branchTool) = container.branch {
        _ = try await branchTool.call(arguments: EmptyArgs())
      }

      #expect(session.properties.testCounter == 38)
      #expect(container.primaryTool.counter == 38)
    }

    @Test
    func boundWrapperSharesStorageInDetachedTaskWhileFreshWrapperReadsDefault() async {
      let session = LanguageModelSession(model: StubModel())
      session.properties.testCounter = 20
      let tool = CounterTool(name: "detached", delta: 5, cycleNode: nil)
      SessionPropertyBinder.bind(tool, to: session.properties)
      let capturedWrapper = tool.capturedCounterWrapper

      let inlineFresh = LanguageModelSession.SessionProperty(\.testCounter).wrappedValue
      let childFresh = await Task {
        LanguageModelSession.SessionProperty(\.testCounter).wrappedValue
      }.value
      let detachedFresh = await Task.detached {
        LanguageModelSession.SessionProperty(\.testCounter).wrappedValue
      }.value
      let detachedCapturedBefore = await Task.detached {
        let current = capturedWrapper.wrappedValue
        capturedWrapper.wrappedValue = current + 15
        return current
      }.value

      #expect(inlineFresh == 0)
      #expect(childFresh == 0)
      #expect(detachedFresh == 0)
      #expect(detachedCapturedBefore == 20)
      #expect(session.properties.testCounter == 35)
      #expect(tool.counter == 35)
    }

    // MARK: - History writes during a call

    @Test(arguments: [false, true])
    func historyWriteFromOutsideACallThrows(streaming: Bool) async throws {
      let entered = SessionObservationTests.Signal()
      let release = SessionObservationTests.Signal()
      let session = SessionObservationTests.makeSession(
        script: SessionObservationTests.gatedScript(entered: entered, release: release))
      let call = Task {
        if streaming {
          _ = try await session.streamResponse(to: "Hi").collect()
        } else {
          _ = try await session.respond(to: "Hi")
        }
      }
      await entered.wait()

      session.properties.history = [.prompt(Transcript.Prompt(id: "outside", segments: []))]
      release.open()
      let result = await call.result

      guard case .failure(let error) = result,
        case .transcriptMutationWhileResponding = error as? LanguageModelSession.Error
      else {
        Issue.record("Expected transcriptMutationWhileResponding, got \(result)")
        return
      }
    }

    /// A hook that clears the history, and the transcript and response entries that result.
    struct HookClearCase: Sendable, CustomTestStringConvertible {
      /// The hook that clears the history.
      let hook: HistoryClearingProfile.Hook

      /// The kinds of the transcript's entries after the call.
      let expectedTranscript: [String]

      /// The kinds of the response's `transcriptEntries`.
      let expectedResponseEntries: [String]

      /// The test description.
      var testDescription: String { "\(hook)" }
    }

    /// The hooks to clear the history from, with the results Apple's framework produces.
    static let hookClearCases: [HookClearCase] = [
      HookClearCase(
        hook: .onPrompt,
        expectedTranscript: ["I", "Reason", "TC", "TO", "Reason", "R"],
        expectedResponseEntries: ["Reason", "TC", "TO", "Reason", "R"]
      ),
      HookClearCase(hook: .onReasoning, expectedTranscript: ["I"], expectedResponseEntries: []),
      HookClearCase(
        hook: .onToolCall,
        expectedTranscript: ["I", "TO", "Reason", "R"],
        expectedResponseEntries: ["TO", "Reason", "R"]
      ),
      HookClearCase(
        hook: .onToolOutput,
        expectedTranscript: ["I", "TO", "Reason", "R"],
        expectedResponseEntries: ["TO", "Reason", "R"]
      ),
      HookClearCase(hook: .onResponse, expectedTranscript: ["I"], expectedResponseEntries: []),
    ]

    @Test(arguments: hookClearCases, [false, true])
    func historyWritesFromHooksArePartOfTheCall(
      _ testCase: HookClearCase, streaming: Bool
    ) async throws {
      let session = LanguageModelSession(profile: HistoryClearingProfile(hook: testCase.hook))

      let (content, entries) = try await Self.respond(to: session, streaming: streaming)

      #expect(content == "done")
      #expect(Self.kinds(of: session.transcript) == testCase.expectedTranscript)
      #expect(Self.kinds(of: entries) == testCase.expectedResponseEntries)
    }

    @Test(arguments: [false, true])
    func responseEntriesFollowThePromptAfterAnOnResponseTrim(streaming: Bool) async throws {
      let session = LanguageModelSession(
        profile: HistoryClearingProfile(hook: .trimSeedInOnResponse))
      session.transcript = Transcript(entries: [
        .prompt(Transcript.Prompt(id: HistoryClearingProfile.seedPromptID, segments: [])),
        .response(
          Transcript.Response(id: HistoryClearingProfile.seedResponseID, assetIDs: [], segments: [])
        ),
      ])

      let (content, entries) = try await Self.respond(to: session, streaming: streaming)

      #expect(content == "done")
      #expect(
        Self.kinds(of: session.transcript) == ["I", "P", "Reason", "TC", "TO", "Reason", "R"])
      #expect(Self.kinds(of: entries) == ["Reason", "TC", "TO", "Reason", "R"])
    }

    /// Responds to a fixed prompt, streaming or not.
    ///
    /// - Parameters:
    ///   - session: The session to respond with.
    ///   - streaming: Whether to use `streamResponse`.
    /// - Returns: The response's content and transcript entries.
    private static func respond(
      to session: LanguageModelSession, streaming: Bool
    ) async throws -> (String, [Transcript.Entry]) {
      if streaming {
        let response = try await session.streamResponse(to: "Count").collect()
        return (response.content, Array(response.transcriptEntries))
      }
      let response = try await session.respond(to: "Count")
      return (response.content, Array(response.transcriptEntries))
    }

    /// Returns a short name for the kind of each entry.
    ///
    /// - Parameter entries: The entries to name.
    /// - Returns: `I`, `P`, `Reason`, `TC`, `TO`, or `R` for each entry.
    private static func kinds(of entries: some Sequence<Transcript.Entry>) -> [String] {
      entries.map { entry in
        switch entry {
        case .instructions: "I"
        case .prompt: "P"
        case .reasoning: "Reason"
        case .toolCalls: "TC"
        case .toolOutput: "TO"
        case .response: "R"
        default: "other"
        }
      }
    }

    // MARK: - Traps

    // Exit tests spawn a child process, which Swift Testing doesn't support on iOS, tvOS, watchOS,
    // or visionOS.
    #if os(macOS) || os(Linux)
      @Test
      func sessionPropertyInAClassToolTraps() async {
        await #expect(processExitsWith: .failure) {
          let tool = ClassCounterTool()
          _ = LanguageModelSession(model: StubModel(), tools: [tool])
          _ = tool.counter
        }
      }

      @Test
      func inheritedSessionPropertyInAClassToolTraps() async {
        await #expect(processExitsWith: .failure) {
          let tool = SubclassCounterTool()
          _ = LanguageModelSession(model: StubModel(), tools: [tool])
          _ = tool.counter
        }
      }
    #endif  // os(macOS) || os(Linux)
  }

  /// A profile that answers with reasoning and a tool call, and writes the history from one hook.
  struct HistoryClearingProfile: LanguageModelSession.DynamicProfile {
    /// The hook that writes the history.
    enum Hook: Sendable {
      /// Clears the history in `onPrompt`.
      case onPrompt
      /// Clears the history in `onReasoning`.
      case onReasoning
      /// Clears the history in `onToolCall`.
      case onToolCall
      /// Clears the history in `onToolOutput`.
      case onToolOutput
      /// Clears the history in `onResponse`.
      case onResponse
      /// Removes the seeded entries in `onResponse`.
      case trimSeedInOnResponse
    }

    /// The ID of the seeded prompt that `trimSeedInOnResponse` removes.
    static let seedPromptID = "seed-prompt"

    /// The ID of the seeded response that `trimSeedInOnResponse` removes.
    static let seedResponseID = "seed-response"

    /// Sends reasoning, then a `note` tool call on the first turn and "done" on the second.
    static let script: SessionObservationTests.ScriptModel.Script = { request, channel in
      await channel.send(.reasoning(action: .appendText("thinking", tokenCount: 1)))
      if case .toolOutput = request.transcript.last {
        await channel.send(.response(action: .appendText("done", tokenCount: 1)))
        return
      }
      await channel.send(
        .toolCalls(
          action: .toolCall(
            id: "call-\(request.transcript.count)", name: "note",
            action: .appendArguments(#"{"text":"a"}"#, tokenCount: 1))
        )
      )
    }

    /// The hook that writes the history.
    let hook: Hook

    /// The session's history.
    @SessionProperty(\.history)
    var history

    /// The profile body.
    var body: some LanguageModelSession.DynamicProfile {
      let hook = hook
      let clear: @Sendable (Hook) -> Void = { current in
        guard current == hook else { return }
        history = []
      }
      let trimSeed: @Sendable () -> Void = {
        guard hook == .trimSeedInOnResponse else { return }
        history = history.filter { entry in
          entry.id != Self.seedPromptID && entry.id != Self.seedResponseID
        }
      }
      return Profile {
        Instructions("Be brief.")
        SessionObservationTests.NoteTool()
      }
      .model(SessionObservationTests.ScriptModel(script: Self.script))
      .onPrompt { clear(.onPrompt) }
      .onReasoning { clear(.onReasoning) }
      .onToolCall { clear(.onToolCall) }
      .onToolOutput { clear(.onToolOutput) }
      .onResponse {
        clear(.onResponse)
        trimSeed()
      }
    }
  }

  /// A class tool with a `@SessionProperty`, which isn't supported.
  private class ClassCounterTool: Tool, @unchecked Sendable {
    /// The tool name.
    let name = "classCounter"

    /// The tool description.
    let description = "Increments the session counter."

    /// Bound counter session property.
    @SessionProperty(\.testCounter)
    var counter

    /// Increments the counter and returns its new value.
    func call(arguments: SessionPropertyTests.EmptyArgs) async throws -> String {
      counter += 1
      return "\(counter)"
    }
  }

  /// A subclass of a class tool whose `@SessionProperty` is inherited.
  private final class SubclassCounterTool: ClassCounterTool, @unchecked Sendable {}
#endif  // compiler(>=6.4)
