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
    /// Counter property entry for dynamic instructions session tests.
    @SessionPropertyEntry
    var dynamicSessionCounter: Int = 0
  }

  // MARK: - DynamicInstructionsSessionTests

  /// Integration tests for `LanguageModelSession(model:dynamicInstructions:history:)`, static tool
  /// `@SessionProperty` binding, and `@SessionProperty(\.history)` tool-call no-op behavior.
  @Suite("DynamicInstructions Session Tests")
  struct DynamicInstructionsSessionTests {
    // MARK: - Support Types

    /// Error thrown by scripted test turns.
    private struct ScriptedTurnError: Error, Equatable {
      /// Error message.
      let message: String
    }

    /// Observable state mutated between turns or inside tools.
    private final class MutableInstructionState: Observable, Sendable {
      /// Mutex-backed text state.
      private let _text: Mutex<String>

      /// Mutex-backed items array.
      private let _items: Mutex<[String]>

      /// Mutex-backed extra flag.
      private let _includeExtra: Mutex<Bool>

      /// Registrar for `Observable` tracking.
      private let _$observationRegistrar = ObservationRegistrar()

      /// Creates observable instruction state.
      init(text: String = "v1", items: [String] = ["a", "b"], includeExtra: Bool = false) {
        self._text = Mutex(text)
        self._items = Mutex(items)
        self._includeExtra = Mutex(includeExtra)
      }

      /// Current text value.
      var text: String {
        get {
          _$observationRegistrar.access(self, keyPath: \.text)
          return _text.withLock { $0 }
        }
        set {
          _$observationRegistrar.withMutation(of: self, keyPath: \.text) {
            _text.withLock { $0 = newValue }
          }
        }
      }

      /// Current items list.
      var items: [String] {
        get {
          _$observationRegistrar.access(self, keyPath: \.items)
          return _items.withLock { $0 }
        }
        set {
          _$observationRegistrar.withMutation(of: self, keyPath: \.items) {
            _items.withLock { $0 = newValue }
          }
        }
      }

      /// Whether to include extra instructions.
      var includeExtra: Bool {
        get {
          _$observationRegistrar.access(self, keyPath: \.includeExtra)
          return _includeExtra.withLock { $0 }
        }
        set {
          _$observationRegistrar.withMutation(of: self, keyPath: \.includeExtra) {
            _includeExtra.withLock { $0 = newValue }
          }
        }
      }
    }

    /// Empty arguments for test tools.
    @Generable
    struct EmptyArgs {}

    /// Configurable tool for dynamic instructions tests.
    private struct InstructionsTestTool: Tool {
      /// Tool arguments type.
      typealias Arguments = EmptyArgs

      /// Tool name.
      let name: String

      /// Tool description.
      let description: String

      /// Whether schema is included in instructions.
      let includeSchema: Bool

      /// Output string returned when called.
      let outputText: String

      /// Optional callback invoked when the tool executes.
      let onCall: (@Sendable () -> Void)?

      /// Creates a test tool.
      init(
        name: String,
        description: String = "A test tool.",
        includeSchema: Bool = true,
        outputText: String = "done",
        onCall: (@Sendable () -> Void)? = nil
      ) {
        self.name = name
        self.description = description
        self.includeSchema = includeSchema
        self.outputText = outputText
        self.onCall = onCall
      }

      /// Whether this tool's schema appears in the transcript's `.instructions` entry.
      var includesSchemaInInstructions: Bool {
        includeSchema
      }

      /// Executes the tool.
      func call(arguments: EmptyArgs) async throws -> String {
        onCall?()
        return outputText
      }
    }

    /// Tool that tests `@SessionProperty` binding and `\.history` write no-op inside `Tool.call`.
    private struct PropertyAndHistoryTool: Tool {
      /// Tool arguments type.
      typealias Arguments = EmptyArgs

      /// Tool name.
      let name = "propTool"

      /// Tool description.
      let description = "Reads/writes session counter and attempts to overwrite history."

      /// Bound session counter property.
      @SessionProperty(\.dynamicSessionCounter)
      var counter

      /// Bound session history property.
      @SessionProperty(\.history)
      var history

      /// Executes the tool.
      func call(arguments: EmptyArgs) async throws -> String {
        let beforeHistoryCount = history.count
        history = [
          .prompt(
            Transcript.Prompt(
              id: "ignored-in-tool",
              segments: [.text(.init(id: "seg-ignored", content: "Should be ignored"))]
            )
          )
        ]
        let afterHistoryCount = history.count
        counter += 10
        return "counter=\(counter),hist=\(beforeHistoryCount)->\(afterHistoryCount)"
      }
    }

    /// Recorder and turn queue for `ScriptedSessionModel`.
    private final class ModelDriver: Sendable {
      /// Handler closure for a single turn.
      typealias TurnHandler =
        @Sendable (
          Int,
          LanguageModelExecutorGenerationRequest,
          LanguageModelExecutorGenerationChannel
        ) async throws -> Void

      /// Mutable driver state.
      private struct State: Sendable {
        /// Next turn index.
        var turnIndex: Int = 0

        /// Recorded generation requests in order.
        var requests: [LanguageModelExecutorGenerationRequest] = []
      }

      /// Mutex guarding `State`.
      private let state = Mutex(State())

      /// Turn handler closure.
      private let handler: TurnHandler

      /// Creates a model driver.
      init(handler: @escaping TurnHandler) {
        self.handler = handler
      }

      /// Records `request` and runs the handler for this turn.
      nonisolated(nonsending) func handle(
        request: LanguageModelExecutorGenerationRequest,
        channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        let turn = state.withLock { state -> Int in
          let idx = state.turnIndex
          state.turnIndex += 1
          state.requests.append(request)
          return idx
        }
        try await handler(turn, request, channel)
      }

      /// All recorded requests.
      var recordedRequests: [LanguageModelExecutorGenerationRequest] {
        state.withLock { $0.requests }
      }
    }

    /// Scriptable language model for session tests.
    private struct ScriptedSessionModel: LanguageModel {
      /// Executor for `ScriptedSessionModel`.
      struct Executor: LanguageModelExecutor {
        /// Associated language model type.
        typealias Model = ScriptedSessionModel

        /// Executor configuration.
        struct Configuration: Hashable, Sendable {
          /// Configuration identifier.
          let id: UUID
        }

        /// Stored configuration.
        let configuration: Configuration

        /// Creates an executor.
        init(configuration: Configuration) throws {
          self.configuration = configuration
        }

        /// Prewarms the executor.
        func prewarm(model: ScriptedSessionModel, transcript: Transcript) {}

        /// Streams events for `request`.
        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: ScriptedSessionModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          try await model.driver.handle(request: request, channel: channel)
        }
      }

      /// Unique model configuration ID.
      let id = UUID()

      /// Driver handling requests.
      let driver: ModelDriver

      /// Creates a scripted model.
      init(handler: @escaping ModelDriver.TurnHandler) {
        self.driver = ModelDriver(handler: handler)
      }

      /// Model capabilities.
      var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning, .vision])
      }

      /// Executor configuration.
      var executorConfiguration: Executor.Configuration {
        Executor.Configuration(id: id)
      }
    }

    // MARK: - DynamicInstructions Types

    /// Scenario 1: Empty dynamic instructions body.
    private struct EmptyBodyInstructions: DynamicInstructions {
      /// Empty body.
      var body: some DynamicInstructions {
        EmptyDynamicInstructions()
      }
    }

    /// Scenario 2: Tools-only dynamic instructions body.
    private struct ToolsOnlyInstructions: DynamicInstructions {
      /// Body containing only tools.
      var body: some DynamicInstructions {
        InstructionsTestTool(name: "alpha", description: "Alpha tool", outputText: "alpha-out")
        InstructionsTestTool(name: "beta", description: "Beta tool", outputText: "beta-out")
      }
    }

    /// Scenario 3: Multi-segment dynamic instructions body.
    private struct MultiSegmentInstructions: DynamicInstructions {
      /// Observable state.
      let state: MutableInstructionState

      /// Body yielding multiple separate instruction segments.
      var body: some DynamicInstructions {
        Instructions("Block 1")
        if state.includeExtra {
          Instructions("Branch True")
        } else {
          Instructions("Branch False")
        }
        if state.includeExtra {
          Instructions("Optional Present")
        }
        AnyDynamicInstructions(
          Instructions {
            "Builder Line A"
            "Builder Line B"
          }
        )
      }
    }

    /// Scenario 4: Duplicate tool names in dynamic instructions.
    private struct DuplicateToolInstructions: DynamicInstructions {
      /// Body with two tools sharing the name `"dup"`.
      var body: some DynamicInstructions {
        Instructions("Duplicate tools test")
        InstructionsTestTool(
          name: "dup", description: "First dup description", outputText: "from-first")
        InstructionsTestTool(
          name: "dup", description: "Second dup description", outputText: "from-second")
      }
    }

    /// Scenario 5: Schema filtering in dynamic instructions.
    private struct SchemaFilterInstructions: DynamicInstructions {
      /// Body with one visible-schema tool and one hidden-schema tool.
      var body: some DynamicInstructions {
        Instructions("Schema filter test")
        InstructionsTestTool(
          name: "visibleTool",
          description: "Visible in instructions",
          includeSchema: true,
          outputText: "visible-out"
        )
        InstructionsTestTool(
          name: "hiddenTool",
          description: "Hidden from instructions",
          includeSchema: false,
          outputText: "hidden-out"
        )
      }
    }

    /// Scenarios 6 & 7: Simple text dynamic instructions backed by observable state.
    private struct SimpleDynamicInstructions: DynamicInstructions {
      /// Observable state.
      let state: MutableInstructionState

      /// Body reading `state.text`.
      var body: some DynamicInstructions {
        Instructions("Dynamic: \(state.text)")
      }
    }

    /// Scenario 8: Dynamic instructions with a tool that mutates state mid-turn.
    private struct StatefulToolInstructions: DynamicInstructions {
      /// Observable state.
      let state: MutableInstructionState

      /// Body reading `state.text` and registering the `"bump"` tool.
      var body: some DynamicInstructions {
        Instructions("State=\(state.text)")
        InstructionsTestTool(
          name: "bump",
          description: "Bumps state",
          outputText: "bumped",
          onCall: {
            state.text = "v3-from-tool"
          }
        )
      }
    }

    /// Identifiable item for Scenario 9.
    private struct IdentifiableItem: Identifiable, Sendable {
      /// Item identifier.
      let id: String

      /// Item label.
      let label: String
    }

    /// Scenario 9: Dynamic instructions using `DynamicInstructions.ForEach`.
    private struct ForEachDynamicInstructions: DynamicInstructions {
      /// Observable state.
      let state: MutableInstructionState

      /// Body expanding `state.items` via both `ForEach` initializers.
      var body: some DynamicInstructions {
        Instructions("Header")
        DynamicInstructions.ForEach(state.items, id: \.self) { item in
          Instructions("Item: \(item)")
          InstructionsTestTool(
            name: "tool_\(item)",
            description: "Tool for \(item)",
            outputText: "out_\(item)"
          )
        }
        DynamicInstructionsForEach(
          state.items.map { IdentifiableItem(id: $0, label: "ID-\($0)") }
        ) { ident in
          Instructions(ident.label)
        }
      }
    }

    /// Dynamic instructions reading `@SessionProperty` via `DynamicInstructions.SessionProperty`.
    private struct SessionPropertyInstructions: DynamicInstructions {
      /// Bound counter property using `DynamicInstructions.SessionProperty`.
      @SessionProperty(\.dynamicSessionCounter)
      var counter

      /// Body interpolating `counter` and registering `PropertyAndHistoryTool`.
      var body: some DynamicInstructions {
        Instructions("Counter=\(counter)")
        PropertyAndHistoryTool()
      }
    }

    // MARK: - Helpers

    /// Extracts text segments from an instructions entry.
    private static func instructionTexts(in entry: Transcript.Entry?) -> [String] {
      guard case .instructions(let inst) = entry else { return [] }
      return inst.segments.compactMap { seg in
        if case .text(let ts) = seg { return ts.content }
        return nil
      }
    }

    // MARK: - Tests

    @Test
    func emptyBodyOmitsInstructionsEntry() async throws {
      let model = ScriptedSessionModel { _, _, channel in
        await channel.send(.response(entryID: "resp-1", action: .appendText("ack", tokenCount: 1)))
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: EmptyBodyInstructions()
      )

      let initCount = session.transcript.count
      let response = try await session.respond(to: "hello")

      #expect(initCount == 0)
      #expect(response.content == "ack")
      #expect(session.transcript.count == 2)
      let recorded = try #require(model.driver.recordedRequests.first)
      #expect(recorded.transcript.count == 1)
      if case .prompt = recorded.transcript.first {
        // Expected leading prompt with no instructions entry.
      } else {
        Issue.record("Expected request transcript to start with .prompt")
      }
    }

    @Test
    func toolsOnlyBodyEmitsEmptySegmentsWithToolDefinitions() async throws {
      let model = ScriptedSessionModel { turn, _, channel in
        if turn == 0 {
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "alpha",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        } else {
          await channel.send(
            .response(entryID: "resp-1", action: .appendText("done", tokenCount: 1)))
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: ToolsOnlyInstructions()
      )

      guard case .instructions(let initInst) = session.transcript.first else {
        Issue.record("Expected leading .instructions entry")
        return
      }
      let response = try await session.respond(to: "run alpha")

      #expect(initInst.segments.isEmpty)
      #expect(initInst.toolDefinitions.map(\.name) == ["alpha", "beta"])
      #expect(response.content == "done")
      #expect(session.transcript.count == 5)
    }

    @Test
    func multiSegmentsPreservesBoundariesAndReevaluates() async throws {
      let state = MutableInstructionState(includeExtra: false)
      let model = ScriptedSessionModel { turn, _, channel in
        await channel.send(
          .response(
            entryID: "resp-\(turn + 1)", action: .appendText("ok-\(turn + 1)", tokenCount: 1))
        )
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: MultiSegmentInstructions(state: state)
      )

      let turn0Texts = Self.instructionTexts(in: session.transcript.first)
      _ = try await session.respond(to: "turn 1")
      state.includeExtra = true
      _ = try await session.respond(to: "turn 2")
      let turn1Texts = Self.instructionTexts(in: session.transcript.first)

      #expect(
        turn0Texts == ["Block 1", "Branch False", "Builder Line A", "Builder Line B"]
      )
      #expect(
        turn1Texts == [
          "Block 1", "Branch True", "Optional Present", "Builder Line A", "Builder Line B",
        ]
      )
    }

    @Test
    func duplicateToolNamesDeduplicateFirstWins() async throws {
      let model = ScriptedSessionModel { turn, _, channel in
        if turn == 0 {
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "dup",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        } else {
          await channel.send(
            .response(entryID: "resp-1", action: .appendText("done", tokenCount: 1)))
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: DuplicateToolInstructions()
      )

      guard case .instructions(let inst) = session.transcript.first else {
        Issue.record("Expected leading .instructions entry")
        return
      }
      let response = try await session.respond(to: "call dup")

      #expect(inst.toolDefinitions.count == 1)
      #expect(inst.toolDefinitions.first?.description == "First dup description")
      let req0 = try #require(model.driver.recordedRequests.first)
      #expect(req0.enabledToolDefinitions.count == 1)
      #expect(req0.enabledToolDefinitions.first?.description == "First dup description")
      #expect(response.content == "done")
      guard case .toolOutput(let toolOutput) = session.transcript[3],
        case .text(let outputText) = toolOutput.segments.first
      else {
        Issue.record("Expected tool output from first duplicate tool")
        return
      }
      #expect(outputText.content == "from-first")
    }

    @Test
    func schemaInInstructionsFiltersTranscriptWhileKeepingToolCallable() async throws {
      let model = ScriptedSessionModel { turn, _, channel in
        if turn == 0 {
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "hiddenTool",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        } else {
          await channel.send(
            .response(entryID: "resp-1", action: .appendText("called hidden", tokenCount: 1))
          )
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: SchemaFilterInstructions()
      )

      guard case .instructions(let inst) = session.transcript.first else {
        Issue.record("Expected leading .instructions entry")
        return
      }
      let response = try await session.respond(to: "invoke hidden")

      #expect(inst.toolDefinitions.map(\.name) == ["visibleTool"])
      let req0 = try #require(model.driver.recordedRequests.first)
      #expect(req0.enabledToolDefinitions.map(\.name) == ["visibleTool", "hiddenTool"])
      if case .instructions(let reqInst) = req0.transcript.first {
        #expect(reqInst.toolDefinitions.map(\.name) == ["visibleTool"])
      } else {
        Issue.record("Expected leading .instructions in request transcript")
      }
      #expect(response.content == "called hidden")
    }

    @Test
    func initHistoryInstructionsReplacesInPlaceOrPrepends() async throws {
      let state = MutableInstructionState(text: "fresh")
      let model = ScriptedSessionModel { turn, _, channel in
        await channel.send(
          .response(
            entryID: "resp-\(turn + 1)", action: .appendText("ok-\(turn + 1)", tokenCount: 1))
        )
      }
      let seedWithInst: [Transcript.Entry] = [
        .instructions(
          Transcript.Instructions(
            id: "seed-inst-id",
            segments: [.text(.init(id: "seed-seg-1", content: "Seed Instructions"))],
            toolDefinitions: []
          )
        ),
        .prompt(
          Transcript.Prompt(
            id: "seed-prompt-id",
            segments: [.text(.init(id: "seed-seg-2", content: "Seed Prompt"))]
          )
        ),
      ]
      let seedNoInst: [Transcript.Entry] = [
        .prompt(
          Transcript.Prompt(
            id: "seed-only-prompt",
            segments: [.text(.init(id: "seed-seg-only", content: "Prompt Without Instructions"))]
          )
        )
      ]

      let sessionWithInst = LanguageModelSession(
        model: model,
        dynamicInstructions: SimpleDynamicInstructions(state: state),
        history: seedWithInst
      )
      let sessionNoInst = LanguageModelSession(
        model: model,
        dynamicInstructions: SimpleDynamicInstructions(state: state),
        history: seedNoInst
      )
      let response = try await sessionWithInst.respond(to: "follow up")

      #expect(sessionWithInst.transcript.first?.id == "seed-inst-id")
      #expect(Self.instructionTexts(in: sessionWithInst.transcript.first) == ["Dynamic: fresh"])
      #expect(sessionNoInst.transcript.count == 2)
      #expect(Self.instructionTexts(in: sessionNoInst.transcript.first) == ["Dynamic: fresh"])
      #expect(sessionNoInst.transcript[1].id == "seed-only-prompt")
      #expect(response.content == "ok-1")
      #expect(sessionWithInst.transcript.count == 4)
    }

    @Test
    func revertInstructionsTextKeepsReevaluatedInstructionsOnFailure() async throws {
      let state = MutableInstructionState(text: "v1")
      let model = ScriptedSessionModel { turn, _, channel in
        if turn == 0 {
          await channel.send(
            .response(entryID: "resp-1", action: .appendText("turn1-ok", tokenCount: 1))
          )
        } else {
          throw ScriptedTurnError(message: "turn2-failed")
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: SimpleDynamicInstructions(state: state)
      )
      let initialID = try #require(session.transcript.first?.id)

      _ = try await session.respond(to: "turn 1")
      state.text = "v2"
      await #expect(throws: ScriptedTurnError.self) {
        try await session.respond(to: "turn 2 fails")
      }

      #expect(session.transcript.count == 3)
      #expect(session.transcript.first?.id == initialID)
      #expect(Self.instructionTexts(in: session.transcript.first) == ["Dynamic: v2"])
    }

    @Test
    func inplaceIDPreservationAcrossTurnsAndToolContinuations() async throws {
      let state = MutableInstructionState(text: "v1")
      let model = ScriptedSessionModel { turn, _, channel in
        switch turn {
        case 0:
          await channel.send(.response(entryID: "resp-1", action: .appendText("r1", tokenCount: 1)))
        case 1:
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "bump",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        default:
          await channel.send(.response(entryID: "resp-2", action: .appendText("r2", tokenCount: 1)))
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: StatefulToolInstructions(state: state)
      )

      let id0 = try #require(session.transcript.first?.id)
      _ = try await session.respond(to: "first")
      let id1 = try #require(session.transcript.first?.id)
      state.text = "v2-between-turns"
      _ = try await session.respond(to: "second with tool")
      let id2 = try #require(session.transcript.first?.id)

      #expect(id0 == id1)
      #expect(id1 == id2)
      #expect(Self.instructionTexts(in: session.transcript.first) == ["State=v3-from-tool"])
      let requests = model.driver.recordedRequests
      #expect(requests.count == 3)
      #expect(Self.instructionTexts(in: requests[0].transcript.first) == ["State=v1"])
      #expect(Self.instructionTexts(in: requests[1].transcript.first) == ["State=v2-between-turns"])
      #expect(Self.instructionTexts(in: requests[2].transcript.first) == ["State=v3-from-tool"])
    }

    @Test
    func forEachDynamicUpdatesSegmentsAndToolsAcrossTurns() async throws {
      let state = MutableInstructionState(items: ["x", "y"])
      let model = ScriptedSessionModel { turn, _, channel in
        await channel.send(
          .response(
            entryID: "resp-\(turn + 1)", action: .appendText("ok-\(turn + 1)", tokenCount: 1))
        )
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: ForEachDynamicInstructions(state: state)
      )
      let initialID = try #require(session.transcript.first?.id)

      _ = try await session.respond(to: "with x, y")
      state.items = ["z", "x", "w"]
      _ = try await session.respond(to: "with z, x, w")
      state.items = []
      _ = try await session.respond(to: "with empty")

      #expect(session.transcript.first?.id == initialID)
      let requests = model.driver.recordedRequests
      #expect(requests.count == 3)
      #expect(requests[0].enabledToolDefinitions.map(\.name) == ["tool_x", "tool_y"])
      #expect(requests[1].enabledToolDefinitions.map(\.name) == ["tool_z", "tool_x", "tool_w"])
      #expect(requests[2].enabledToolDefinitions.isEmpty)
      #expect(Self.instructionTexts(in: session.transcript.first) == ["Header"])
    }

    @Test
    func staticInitBindsToolSessionPropertyAndIgnoresHistoryWriteInToolCall() async throws {
      let model = ScriptedSessionModel { turn, _, channel in
        if turn == 0 {
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "propTool",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        } else {
          await channel.send(
            .response(entryID: "resp-1", action: .appendText("done", tokenCount: 1)))
        }
      }
      let session = LanguageModelSession(
        model: model,
        tools: [PropertyAndHistoryTool()],
        instructions: "Static init property binding"
      )
      session.properties.dynamicSessionCounter = 42

      let response = try await session.respond(to: "run propTool")

      #expect(response.content == "done")
      #expect(session.properties.dynamicSessionCounter == 52)
      guard case .toolOutput(let output) = session.transcript[3],
        case .text(let textSeg) = output.segments.first
      else {
        Issue.record("Expected tool output")
        return
      }
      #expect(textSeg.content == "counter=52,hist=2->2")
    }

    @Test
    func dynamicInstructionsSessionPropertyReadsAndUpdatesAcrossTurns() async throws {
      let model = ScriptedSessionModel { turn, _, channel in
        if turn == 0 {
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "propTool",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        } else {
          await channel.send(
            .response(entryID: "resp-1", action: .appendText("done", tokenCount: 1)))
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: SessionPropertyInstructions()
      )
      session.properties.dynamicSessionCounter = 5

      _ = try await session.respond(to: "increment in tool")

      let requests = model.driver.recordedRequests
      #expect(requests.count == 2)
      #expect(Self.instructionTexts(in: requests[0].transcript.first) == ["Counter=5"])
      #expect(Self.instructionTexts(in: requests[1].transcript.first) == ["Counter=15"])
      #expect(session.properties.dynamicSessionCounter == 15)
    }

    @Test
    func streamResponseDynamicInstructionsReevaluatesAndPreservesUpdatedInstructionsOnRevert()
      async throws
    {
      let state = MutableInstructionState(text: "s1")
      let model = ScriptedSessionModel { turn, _, channel in
        switch turn {
        case 0:
          await channel.send(
            .toolCalls(
              entryID: "tc-1",
              action: .toolCall(
                id: "call-1",
                name: "bump",
                action: .appendArguments("{}", tokenCount: 1)
              )
            )
          )
        case 1:
          await channel.send(
            .response(entryID: "s-ok", action: .appendText("streamed-ok", tokenCount: 1))
          )
        default:
          throw ScriptedTurnError(message: "stream-turn-failed")
        }
      }
      let session = LanguageModelSession(
        model: model,
        dynamicInstructions: StatefulToolInstructions(state: state)
      )
      let initialID = try #require(session.transcript.first?.id)

      let stream1 = session.streamResponse(to: "stream with tool")
      for try await _ in stream1 {}
      state.text = "s4-before-fail"
      let stream2 = session.streamResponse(to: "stream fails")
      do {
        for try await _ in stream2 {}
      } catch {}

      #expect(session.transcript.first?.id == initialID)
      #expect(Self.instructionTexts(in: session.transcript.first) == ["State=s4-before-fail"])
      let requests = model.driver.recordedRequests
      #expect(requests.count == 3)
      #expect(Self.instructionTexts(in: requests[0].transcript.first) == ["State=s1"])
      #expect(Self.instructionTexts(in: requests[1].transcript.first) == ["State=v3-from-tool"])
      #expect(Self.instructionTexts(in: requests[2].transcript.first) == ["State=s4-before-fail"])
    }
  }
#endif  // compiler(>=6.4)
