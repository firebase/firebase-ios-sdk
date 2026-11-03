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
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  @Suite("LanguageModelSession Unit Tests")
  struct LanguageModelSessionTests {
    // MARK: - Test Support Types

    private struct HiddenSchemaTool: Tool {
      typealias Arguments = MacroFixtures.Address
      let name = "hiddenTool"
      let description = "A tool excluded from instructions schema."
      let includesSchemaInInstructions = false

      func call(arguments: MacroFixtures.Address) async throws -> String {
        "hidden:\(arguments.city)"
      }
    }

    private struct VisibleSchemaTool: Tool {
      typealias Arguments = MacroFixtures.Address
      let name = "visibleTool"
      let description = "A tool included in instructions schema."
      let includesSchemaInInstructions = true

      func call(arguments: MacroFixtures.Address) async throws -> String {
        "visible:\(arguments.city)"
      }
    }

    private struct CountingModel: LanguageModel {
      struct Executor: LanguageModelExecutor {
        typealias Model = CountingModel

        struct Configuration: Hashable, Sendable {
          let key: String
        }

        static let initCounts = Mutex<[String: Int]>([:])

        let configuration: Configuration

        init(configuration: Configuration) throws {
          self.configuration = configuration
          Self.initCounts.withLock { counts in
            counts[configuration.key, default: 0] += 1
          }
        }

        func prewarm(model: CountingModel, transcript: Transcript) {}

        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: CountingModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          await channel.send(
            .response(
              entryID: nil,
              action: .appendText(model.replyText, tokenCount: 2)
            )
          )
        }
      }

      let configKey: String
      let replyText: String

      var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning, .vision])
      }

      var executorConfiguration: Executor.Configuration {
        Executor.Configuration(key: configKey)
      }
    }

    private struct SampleStreamError: Error, Equatable {}

    private final class StreamStepGate: Sendable {
      private struct State: Sendable {
        var isOpen = false
        var waiter: CheckedContinuation<Void, Never>?
      }

      private let state = Mutex(State())

      func wait() async {
        await withCheckedContinuation { continuation in
          let resumeImmediately = state.withLock { state -> Bool in
            if state.isOpen {
              return true
            }
            state.waiter = continuation
            return false
          }
          if resumeImmediately {
            continuation.resume()
          }
        }
      }

      func open() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
          state.isOpen = true
          let current = state.waiter
          state.waiter = nil
          return current
        }
        waiter?.resume()
      }
    }

    private struct CancellableStreamModel: LanguageModel {
      struct Executor: LanguageModelExecutor {
        typealias Model = CancellableStreamModel

        struct Configuration: Hashable, Sendable {
          let key: String
        }

        init(configuration: Configuration) throws {}

        func prewarm(model: CancellableStreamModel, transcript: Transcript) {}

        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: CancellableStreamModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          let promptText: String =
            if case .prompt(let promptEntry) = request.transcript.last,
              case .text(let segment) = promptEntry.segments.first
            {
              segment.content
            } else {
              ""
            }

          if promptText.hasPrefix("cancel:") {
            await channel.send(
              .response(entryID: nil, action: .appendText("partial", tokenCount: 1)))
            try await Task.sleep(for: .seconds(10))
            return
          }

          if promptText.hasPrefix("throw-cancel:") {
            await channel.send(
              .response(entryID: nil, action: .appendText("partial", tokenCount: 2)))
            throw CancellationError()
          }

          if promptText.hasPrefix("gated:"), let gate = model.gate {
            await channel.send(.response(entryID: nil, action: .appendText("part1", tokenCount: 1)))
            await gate.wait()
            await channel.send(.response(entryID: nil, action: .appendText("part2", tokenCount: 1)))
            return
          }

          await channel.send(.response(entryID: nil, action: .appendText("ok", tokenCount: 1)))
        }
      }

      let configKey: String
      let gate: StreamStepGate?

      var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning, .vision])
      }

      var executorConfiguration: Executor.Configuration {
        Executor.Configuration(key: configKey)
      }
    }

    private struct ConditionalFailureModel: LanguageModel {
      struct Executor: LanguageModelExecutor {
        typealias Model = ConditionalFailureModel

        struct Configuration: Hashable, Sendable {
          let key: String
        }

        init(configuration: Configuration) throws {}

        func prewarm(model: ConditionalFailureModel, transcript: Transcript) {}

        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: ConditionalFailureModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          let shouldFail =
            if case .prompt(let promptEntry) = request.transcript.last,
              case .text(let segment) = promptEntry.segments.first
            {
              segment.content.hasPrefix("fail:")
            } else {
              false
            }

          await channel.send(
            .response(
              entryID: nil,
              action: .appendText(model.replyText, tokenCount: 2)
            )
          )
          if shouldFail {
            throw SampleStreamError()
          }
        }
      }

      let configKey: String
      let replyText: String

      var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning, .vision])
      }

      var executorConfiguration: Executor.Configuration {
        Executor.Configuration(key: configKey)
      }
    }

    // MARK: - Initializers & Tool Definition Filtering

    @Test
    func sessionInitializersAndIncludesSchemaInInstructions() {
      let model = CountingModel(configKey: "init-test", replyText: "ok")
      let visible = VisibleSchemaTool()
      let hidden = HiddenSchemaTool()

      let session = LanguageModelSession(
        model: model,
        tools: [visible, hidden],
        instructions: "Follow rules."
      )

      #expect(session.transcript.count == 1)
      guard case .instructions(let instructionsEntry) = session.transcript.first else {
        Issue.record("Expected instructions entry")
        return
      }
      #expect(instructionsEntry.toolDefinitions.count == 1)
      #expect(instructionsEntry.toolDefinitions.first?.name == "visibleTool")

      let builderSession = LanguageModelSession(model: model) {
        "Line 1"
        "Line 2"
      }
      #expect(builderSession.transcript.count == 1)

      let emptySession = LanguageModelSession(model: model)
      #expect(emptySession.transcript.isEmpty)
    }

    // MARK: - Per-Session Executor Caching

    /// Executors are cached per session, as in Apple's session: sessions with equal
    /// configurations get separate executors.
    @Test
    func executorCachingIsPerSession() async throws {
      let keyA = "cache-key-A-\(UUID().uuidString)"
      let keyB = "cache-key-B-\(UUID().uuidString)"

      let sessionA1 = LanguageModelSession(
        model: CountingModel(configKey: keyA, replyText: "first"))
      let sessionA2 = LanguageModelSession(
        model: CountingModel(configKey: keyA, replyText: "second"))
      let sessionB = LanguageModelSession(model: CountingModel(configKey: keyB, replyText: "third"))

      let r1 = try await sessionA1.respond(to: "Hi")
      let r2 = try await sessionA2.respond(to: "Hi again")
      let r3 = try await sessionB.respond(to: "Hi B")

      #expect(r1.content == "first")
      #expect(r2.content == "second")
      #expect(r3.content == "third")

      let countA = CountingModel.Executor.initCounts.withLock { $0[keyA] ?? 0 }
      let countB = CountingModel.Executor.initCounts.withLock { $0[keyB] ?? 0 }
      #expect(countA == 2)
      #expect(countB == 1)
    }

    // MARK: - All 18 respond Overloads

    @Test
    func allEighteenRespondOverloads() async throws {
      let textModel = CountingModel(configKey: "respond-text", replyText: "hello")
      let jsonModel = CountingModel(
        configKey: "respond-json",
        replyText: #"{"street":"1 Main","city":"London"}"#
      )
      let expectedAddress = MacroFixtures.Address(street: "1 Main", city: "London")

      let sText = LanguageModelSession(model: textModel)
      let sJSON = LanguageModelSession(model: jsonModel)
      let schema = MacroFixtures.Address.generationSchema

      // Legacy 1-3: String output
      let r1 = try await sText.respond(to: Prompt("p1"))
      let r2 = try await sText.respond(to: "p2")
      let r3 = try await sText.respond { "p3" }
      #expect(r1.content == "hello")
      #expect(r2.content == "hello")
      #expect(r3.content == "hello")

      // Legacy 4-6: GenerationSchema output
      let r4 = try await sJSON.respond(to: Prompt("p4"), schema: schema)
      let r5 = try await sJSON.respond(to: "p5", schema: schema)
      let r6 = try await sJSON.respond(schema: schema) { "p6" }
      #expect(try MacroFixtures.Address(r4.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r5.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r6.content) == expectedAddress)

      // Legacy 7-9: Generable type output
      let r7 = try await sJSON.respond(to: Prompt("p7"), generating: MacroFixtures.Address.self)
      let r8 = try await sJSON.respond(to: "p8", generating: MacroFixtures.Address.self)
      let r9 = try await sJSON.respond(generating: MacroFixtures.Address.self) { "p9" }
      #expect(r7.content == expectedAddress)
      #expect(r8.content == expectedAddress)
      #expect(r9.content == expectedAddress)

      // New 10-12: String output with contextOptions & metadata
      let r10 = try await sText.respond(
        to: Prompt("p10"),
        contextOptions: ContextOptions(),
        metadata: ["k": "v"]
      )
      let r11 = try await sText.respond(
        to: "p11",
        contextOptions: ContextOptions(),
        metadata: ["k": "v"]
      )
      let r12 = try await sText.respond(
        contextOptions: ContextOptions(),
        metadata: ["k": "v"]
      ) { "p12" }
      #expect(r10.content == "hello")
      #expect(r11.content == "hello")
      #expect(r12.content == "hello")

      // New 13-15: GenerationSchema output with contextOptions & metadata
      let r13 = try await sJSON.respond(
        to: Prompt("p13"),
        schema: schema,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      )
      let r14 = try await sJSON.respond(
        to: "p14",
        schema: schema,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      )
      let r15 = try await sJSON.respond(
        schema: schema,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ) { "p15" }
      #expect(try MacroFixtures.Address(r13.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r14.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r15.content) == expectedAddress)

      // New 16-18: Generable type output with contextOptions & metadata
      let r16 = try await sJSON.respond(
        to: Prompt("p16"),
        generating: MacroFixtures.Address.self,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      )
      let r17 = try await sJSON.respond(
        to: "p17",
        generating: MacroFixtures.Address.self,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      )
      let r18 = try await sJSON.respond(
        generating: MacroFixtures.Address.self,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ) { "p18" }
      #expect(r16.content == expectedAddress)
      #expect(r17.content == expectedAddress)
      #expect(r18.content == expectedAddress)

      // Generable where Content == String sets schema to nil
      let rStringGenerable = try await sText.respond(to: "pString", generating: String.self)
      #expect(rStringGenerable.content == "hello")
    }

    // MARK: - All 18 streamResponse Overloads

    @Test
    func allEighteenStreamResponseOverloads() async throws {
      let textModel = CountingModel(configKey: "stream-text", replyText: "streamed")
      let jsonModel = CountingModel(
        configKey: "stream-json",
        replyText: #"{"street":"1 Main","city":"London"}"#
      )
      let expectedAddress = MacroFixtures.Address(street: "1 Main", city: "London")

      let sText = LanguageModelSession(model: textModel)
      let sJSON = LanguageModelSession(model: jsonModel)
      let schema = MacroFixtures.Address.generationSchema

      // Legacy 1-3: String output
      let r1 = try await sText.streamResponse(to: Prompt("p1")).collect()
      let r2 = try await sText.streamResponse(to: "p2").collect()
      let r3 = try await sText.streamResponse { "p3" }.collect()
      #expect(r1.content == "streamed")
      #expect(r2.content == "streamed")
      #expect(r3.content == "streamed")

      // Legacy 4-6: GenerationSchema output
      let r4 = try await sJSON.streamResponse(to: Prompt("p4"), schema: schema).collect()
      let r5 = try await sJSON.streamResponse(to: "p5", schema: schema).collect()
      let r6 = try await sJSON.streamResponse(schema: schema) { "p6" }.collect()
      #expect(try MacroFixtures.Address(r4.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r5.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r6.content) == expectedAddress)

      // Legacy 7-9: Generable type output
      let r7 = try await sJSON.streamResponse(
        to: Prompt("p7"),
        generating: MacroFixtures.Address.self
      ).collect()
      let r8 = try await sJSON.streamResponse(
        to: "p8",
        generating: MacroFixtures.Address.self
      ).collect()
      let r9 = try await sJSON.streamResponse(generating: MacroFixtures.Address.self) {
        "p9"
      }.collect()
      #expect(r7.content == expectedAddress)
      #expect(r8.content == expectedAddress)
      #expect(r9.content == expectedAddress)

      // New 10-12: String output with contextOptions & metadata
      let r10 = try await sText.streamResponse(
        to: Prompt("p10"),
        contextOptions: ContextOptions(),
        metadata: ["k": "v"]
      ).collect()
      let r11 = try await sText.streamResponse(
        to: "p11",
        contextOptions: ContextOptions(),
        metadata: ["k": "v"]
      ).collect()
      let r12 = try await sText.streamResponse(
        contextOptions: ContextOptions(),
        metadata: ["k": "v"]
      ) { "p12" }.collect()
      #expect(r10.content == "streamed")
      #expect(r11.content == "streamed")
      #expect(r12.content == "streamed")

      // New 13-15: GenerationSchema output with contextOptions & metadata
      let r13 = try await sJSON.streamResponse(
        to: Prompt("p13"),
        schema: schema,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ).collect()
      let r14 = try await sJSON.streamResponse(
        to: "p14",
        schema: schema,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ).collect()
      let r15 = try await sJSON.streamResponse(
        schema: schema,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ) { "p15" }.collect()
      #expect(try MacroFixtures.Address(r13.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r14.content) == expectedAddress)
      #expect(try MacroFixtures.Address(r15.content) == expectedAddress)

      // New 16-18: Generable type output with contextOptions & metadata
      let r16 = try await sJSON.streamResponse(
        to: Prompt("p16"),
        generating: MacroFixtures.Address.self,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ).collect()
      let r17 = try await sJSON.streamResponse(
        to: "p17",
        generating: MacroFixtures.Address.self,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ).collect()
      let r18 = try await sJSON.streamResponse(
        generating: MacroFixtures.Address.self,
        contextOptions: ContextOptions(includeSchemaInPrompt: false),
        metadata: ["k": "v"]
      ) { "p18" }.collect()
      #expect(r16.content == expectedAddress)
      #expect(r17.content == expectedAddress)
      #expect(r18.content == expectedAddress)
    }

    // MARK: - Refusal Explanation & ExplanationStream

    @Test
    func refusalExplanationAndStream() async throws {
      let refusal = LanguageModelError.Refusal(
        explanation: "I cannot assist with that.",
        debugDescription: "Refused"
      )

      let explanation = try await refusal.explanation
      #expect(explanation.content == "I cannot assist with that.")
      #expect(explanation.rawContent == GeneratedContent("I cannot assist with that."))
      #expect(explanation.transcriptEntries.isEmpty)
      #expect(explanation.usage.totalTokenCount == 0)

      var snapshots: [String] = []
      let stream = refusal.explanationStream
      for try await snap in stream {
        snapshots.append(snap.content)
      }
      let collected = try await stream.collect()
      #expect(snapshots == ["I cannot assist with that."])
      #expect(collected.content == "I cannot assist with that.")
      #expect(collected.transcriptEntries.isEmpty)
    }

    // MARK: - Stream Final Conversion Failure & Repeated ToolCall ID Flat Lookup

    @Test
    func streamResponseConvertFinalFailureFinishesSnapshotsBeforeFailingCollect() async throws {
      // Missing required "city" field so PartiallyGenerated succeeds on snapshots,
      // while final Address conversion throws in collect().
      let incompleteModel = CountingModel(
        configKey: "stream-incomplete-address",
        replyText: #"{"street":"1 Main"}"#
      )
      let session = LanguageModelSession(model: incompleteModel)
      let stream = session.streamResponse(
        to: "Make an address",
        generating: MacroFixtures.Address.self
      )

      var snapshots: [MacroFixtures.Address.PartiallyGenerated] = []
      for try await snap in stream {
        snapshots.append(snap.content)
      }

      #expect(!snapshots.isEmpty)
      #expect(snapshots.last?.street == "1 Main")
      #expect(snapshots.last?.city == nil)
      await #expect(throws: GeneratedContent.ParsingError.self) {
        _ = try await stream.collect()
      }
    }

    @Test
    func repeatedToolCallIDWithNilEntryIDUpdatesExistingEntryInPlace() throws {
      var transcript = Transcript(entries: [
        .toolCalls(
          Transcript.ToolCalls(
            id: "earlier-entry",
            [
              Transcript.ToolCall(
                id: "call-1",
                toolName: "visibleTool",
                arguments: try GeneratedContent(json: #"{"street":"Old","city":"Rome"}"#)
              )
            ]
          )
        )
      ])

      var reducer = LanguageModelSession.TurnReducer(schema: nil)
      let event = LanguageModelExecutorGenerationChannel.Event.toolCalls(
        entryID: nil,
        action: .toolCall(
          id: "call-1",
          name: "visibleTool",
          action: .appendArguments(#"{"street":"New","city":"Oslo"}"#, tokenCount: 2)
        )
      )
      _ = try reducer.apply(event, to: &transcript)

      #expect(transcript.count == 1)
      #expect(reducer.createdToolCallsEntryIndices.isEmpty)
      let entry = try #require(transcript.first)
      guard case .toolCalls(let callsEntry) = entry else {
        Issue.record("Expected toolCalls entry")
        return
      }
      #expect(callsEntry.id == "earlier-entry")
      #expect(callsEntry.calls.count == 1)
      let updatedCall = try #require(callsEntry.calls.first)
      let decoded = try MacroFixtures.Address(updatedCall.arguments)
      #expect(decoded == MacroFixtures.Address(street: "New", city: "Oslo"))
    }

    // MARK: - Stream Completion Ordering Regression Tests

    @Test
    func backToBackStreamResponseAndRespondNeverRacesIsResponding() async throws {
      let model = CountingModel(configKey: "race-regression-ok", replyText: "ok")
      let session = LanguageModelSession(model: model)
      let iterations = 200

      for i in 0..<iterations {
        let c1 = try await session.streamResponse(to: "collect-a-\(i)").collect()
        #expect(!session.isResponding)
        #expect(c1.content == "ok")

        let c2 = try await session.streamResponse(to: "collect-b-\(i)").collect()
        #expect(!session.isResponding)
        #expect(c2.content == "ok")

        var lastSnapshot: String?
        for try await snapshot in session.streamResponse(to: "iter-\(i)") {
          lastSnapshot = snapshot.content
        }
        #expect(!session.isResponding)
        #expect(lastSnapshot == "ok")

        let r = try await session.respond(to: "respond-\(i)")
        #expect(!session.isResponding)
        #expect(r.content == "ok")
      }

      #expect(session.transcript.count == iterations * 4 * 2)
      #expect(session.usage.totalTokenCount == iterations * 4 * 2)
    }

    @Test
    func backToBackStreamResponseFailureImmediatelyLeavesSessionIdle() async throws {
      let failingOrOkModel = ConditionalFailureModel(
        configKey: "race-regression-fail",
        replyText: #"{"street":"1 Main"}"#
      )
      let session = LanguageModelSession(model: failingOrOkModel)
      let iterations = 200

      for i in 0..<iterations {
        await #expect(throws: SampleStreamError.self) {
          _ = try await session.streamResponse(to: "fail:collect-\(i)").collect()
        }
        #expect(!session.isResponding)

        await #expect(throws: SampleStreamError.self) {
          for try await _ in session.streamResponse(to: "fail:iter-\(i)") {}
        }
        #expect(!session.isResponding)

        await #expect(throws: GeneratedContent.ParsingError.self) {
          _ = try await session.streamResponse(
            to: "incomplete-address-\(i)",
            generating: MacroFixtures.Address.self
          ).collect()
        }
        #expect(!session.isResponding)

        let recovered = try await session.respond(to: "ok-\(i)")
        #expect(!session.isResponding)
        #expect(recovered.content == #"{"street":"1 Main"}"#)
      }

      // Each iteration has 2 reverted mid-stream errors + 1 committed final-conversion failure
      // (prompt + response) + 1 committed respond (prompt + response) = 4 entries per iteration.
      #expect(session.transcript.count == iterations * 4)
    }

    @Test
    func cancelledStreamResponseRevertRemovesPromptAndLeavesSessionIdle() async throws {
      let model = CancellableStreamModel(configKey: "cancel-stream-revert-200", gate: nil)
      let session = LanguageModelSession(model: model)
      let iterations = 200

      for i in 0..<iterations {
        let sawFirstSnapshot = StreamStepGate()
        let task = Task {
          for try await _ in session.streamResponse(to: "cancel:\(i)") {
            sawFirstSnapshot.open()
          }
        }
        await sawFirstSnapshot.wait()
        task.cancel()
        let taskResult = await task.result

        #expect(throws: Never.self) { try taskResult.get() }
        #expect(!session.isResponding)
        #expect(session.transcript.count == i * 2)
        let response = try await session.respond(to: "after:\(i)")
        #expect(!session.isResponding)
        #expect(response.content == "ok")
        #expect(session.transcript.count == (i + 1) * 2)
      }

      #expect(session.usage.totalTokenCount == iterations)
    }

    @Test
    func executorThrownCancellationErrorBehavesAsExecutorError() async throws {
      let model = CancellableStreamModel(configKey: "executor-throws-cancellation", gate: nil)
      let revertStreamSession = LanguageModelSession(model: model)
      revertStreamSession.transcriptErrorHandlingPolicy = .revertTranscript
      let preserveStreamSession = LanguageModelSession(model: model)
      preserveStreamSession.transcriptErrorHandlingPolicy = .preserveTranscript
      let preserveRespondSession = LanguageModelSession(model: model)
      preserveRespondSession.transcriptErrorHandlingPolicy = .preserveTranscript

      await #expect(throws: CancellationError.self) {
        for try await _ in revertStreamSession.streamResponse(to: "throw-cancel:revert") {}
      }
      await #expect(throws: CancellationError.self) {
        for try await _ in preserveStreamSession.streamResponse(to: "throw-cancel:preserve") {}
      }
      await #expect(throws: CancellationError.self) {
        _ = try await preserveRespondSession.respond(to: "throw-cancel:respond")
      }

      #expect(revertStreamSession.transcript.isEmpty)
      #expect(revertStreamSession.usage.output.totalTokenCount == 2)
      #expect(preserveStreamSession.transcript.count == 2)
      #expect(preserveStreamSession.usage.output.totalTokenCount == 2)
      #expect(preserveRespondSession.transcript.count == 1)
      #expect(preserveRespondSession.usage.output.totalTokenCount == 0)
    }

    @Test
    func shrinkingTranscriptMidStreamThrowsTranscriptMutationWhileResponding() async throws {
      let gate = StreamStepGate()
      let model = CancellableStreamModel(configKey: "shrink-transcript-mid-stream", gate: gate)
      let session = LanguageModelSession(model: model)
      _ = try await session.respond(to: "seed")
      let seededCount = session.transcript.count

      let stream = session.streamResponse(to: "gated:shrink")
      var iterator = stream.makeAsyncIterator()
      let firstSnapshot = try await iterator.next()
      session.transcript = Transcript()
      gate.open()

      #expect(firstSnapshot?.content == "part1")
      await #expect(throws: LanguageModelSession.Error.transcriptMutationWhileResponding) {
        while try await iterator.next() != nil {}
      }
      await #expect(throws: LanguageModelSession.Error.transcriptMutationWhileResponding) {
        _ = try await stream.collect()
      }
      #expect(!session.isResponding)
      #expect(session.transcript.count == seededCount)
    }

    @Test
    func anySendableHashableDistinguishesDynamicTypesWithCompatibleCasts() {
      let directValue: Int = 7
      let optionalValue: Int? = 7

      let wrappedDirect = LanguageModelSession.AnySendableHashable(directValue)
      let wrappedOptional = LanguageModelSession.AnySendableHashable(optionalValue)

      #expect(((directValue as any Hashable) as? Int?) == optionalValue)
      #expect(((optionalValue as any Hashable) as? Int) == directValue)
      #expect(wrappedDirect != wrappedOptional)
      #expect(wrappedOptional != wrappedDirect)
    }
  }
#endif  // compiler(>=6.4)
