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
  import Testing

  @testable import FoundationModelsFake

  /// Tests for external `transcript` writes during a call under each error-handling policy,
  /// matching Apple's framework.
  ///
  /// Every case throws `transcriptMutationWhileResponding` (or the error of the event that can't be
  /// applied on its own). `.revertTranscript` restores the pre-call transcript; `.preserveTranscript`
  /// keeps the external write and appends the call's events to it: `respond` appends the whole
  /// turn, and a stream appends only the event it was applying.
  @Suite("External writes under each error-handling policy")
  struct PreserveMergeTests {
    // MARK: - Fixtures

    typealias Signal = SessionObservationTests.Signal
    typealias ScriptModel = SessionObservationTests.ScriptModel

    /// A tool that opens `entered` and waits for `release`.
    struct GatedTool: Tool {
      /// The arguments: `text`.
      typealias Arguments = SessionObservationTests.NoteTool.Arguments

      /// The tool name.
      let name = "gated"

      /// The tool description.
      let description = "Waits for the test."

      /// Opened when the tool starts.
      let entered: Signal

      /// Awaited before the tool returns.
      let release: Signal

      /// Waits for `release`, then returns `"released"`.
      ///
      /// - Parameter arguments: The arguments.
      /// - Returns: `"released"`.
      @concurrent func call(arguments: Arguments) async throws -> String {
        entered.open()
        await release.wait()
        return "released"
      }
    }

    /// The external value the tests write: one prompt (the setter adds the tools entry in front).
    static let externalValue = Transcript(entries: [
      .prompt(Transcript.Prompt(id: "ext", segments: []))
    ])

    /// An external value whose index 2 (after the setter's tools entry) is a response entry.
    static let longerExternalValue = Transcript(entries: [
      .prompt(Transcript.Prompt(id: "e1", segments: [])),
      .response(
        Transcript.Response(
          id: "Rext",
          assetIDs: [],
          segments: [.text(Transcript.TextSegment(id: "s-Rext", content: "ext"))]
        )
      ),
      .prompt(Transcript.Prompt(id: "e2", segments: [])),
    ])

    /// Returns a text event with one token.
    static func text(_ content: String) -> LanguageModelExecutorGenerationChannel.Event {
      .response(action: .appendText(content, tokenCount: 1))
    }

    /// Sends `before`, opens `entered`, waits for `release`, then sends `after`.
    static func phasedScript(
      before: [LanguageModelExecutorGenerationChannel.Event],
      after: [LanguageModelExecutorGenerationChannel.Event],
      entered: Signal,
      release: Signal
    ) -> ScriptModel.Script {
      { _, channel in
        for event in before {
          await channel.send(event)
        }
        entered.open()
        await release.wait()
        for event in after {
          await channel.send(event)
        }
      }
    }

    /// Calls `tool` once (opening `entered` and waiting for `release` during turn 1 if
    /// `gateTurnOne`), then answers `"done"` after the tool output.
    static func toolScript(
      tool: String,
      gateTurnOne: Bool,
      entered: Signal,
      release: Signal
    ) -> ScriptModel.Script {
      { request, channel in
        if case .toolOutput = request.transcript.last {
          await channel.send(text("done"))
          return
        }
        await channel.send(
          .toolCalls(
            action: .toolCall(
              id: "call-\(request.transcript.count)",
              name: tool,
              action: .appendArguments(#"{"text":"a"}"#, tokenCount: 1)
            )
          )
        )
        if gateTurnOne {
          entered.open()
          await release.wait()
        }
      }
    }

    /// Creates a session with instructions, the `note` tool, any `extraTools`, and `script`.
    static func makeSession(
      script: @escaping ScriptModel.Script,
      preserves: Bool,
      extraTools: [any Tool] = []
    ) -> LanguageModelSession {
      let session = LanguageModelSession(
        model: ScriptModel(script: script),
        tools: [SessionObservationTests.NoteTool()] + extraTools,
        instructions: Instructions("Be brief.")
      )
      session.transcriptErrorHandlingPolicy = preserves ? .preserveTranscript : nil
      return session
    }

    /// Runs `call`, waits for `entered` (and, if given, for the transcript to reach
    /// `readyCount` entries), writes `value`, opens `release`, and returns the call's result with
    /// the transcripts before the call and after the write.
    static func writeDuringCall(
      session: LanguageModelSession,
      entered: Signal,
      release: Signal,
      value: Transcript = externalValue,
      readyCount: Int? = nil,
      call: @escaping @Sendable () async throws -> Void
    ) async throws -> (result: Result<Void, any Error>, preCall: Transcript, afterWrite: Transcript)
    {
      let preCall = session.transcript
      let task = Task { try await call() }
      await entered.wait()
      if let readyCount {
        try await SessionObservationTests.waitUntil { session.transcript.count == readyCount }
      }
      session.transcript = value
      let afterWrite = session.transcript
      release.open()
      let result = await task.result
      return (result, preCall, afterWrite)
    }

    /// Expects `result` to have failed with `transcriptMutationWhileResponding`.
    static func expectMutationError(
      _ result: Result<Void, any Error>,
      sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
      let error = try #require(
        throws: LanguageModelSession.Error.self,
        sourceLocation: sourceLocation
      ) { try result.get() }
      guard case .transcriptMutationWhileResponding = error else {
        Issue.record("Expected transcriptMutationWhileResponding, got \(error)")
        return
      }
    }

    /// The policies to test: whether each preserves.
    static let policies = [false, true]

    // MARK: - respond

    @Test(arguments: policies)
    func respondAppendsTheWholeTurnToTheWrite(preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.phasedScript(
          before: [Self.text("a")],
          after: [Self.text("b"), Self.text("c")],
          entered: entered,
          release: release
        ),
        preserves: preserves
      )

      let (result, preCall, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release
      ) { try await session.respond(to: "Hi") }

      try Self.expectMutationError(result)
      if preserves {
        #expect(Array(session.transcript.prefix(afterWrite.count)) == Array(afterWrite))
        #expect(session.transcript.count == afterWrite.count + 1)
        #expect(SessionObservationTests.responseText(session.transcript.last) == "abc")
      } else {
        #expect(session.transcript == preCall)
      }
      #expect(session.usage.output.totalTokenCount == 0)
    }

    @Test
    func respondAppendsANewEntryAfterALongerWrite() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.phasedScript(
          before: [Self.text("a")],
          after: [Self.text("b")],
          entered: entered,
          release: release
        ),
        preserves: true
      )

      let (result, _, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release,
        value: Self.longerExternalValue
      ) { try await session.respond(to: "Hi") }

      try Self.expectMutationError(result)
      #expect(Array(session.transcript.prefix(afterWrite.count)) == Array(afterWrite))
      #expect(SessionObservationTests.responseText(session.transcript.last) == "ab")
    }

    @Test(arguments: policies)
    func respondWriteDuringToolTurnAppendsTheToolCallsOnly(preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.toolScript(
          tool: "note", gateTurnOne: true, entered: entered, release: release),
        preserves: preserves
      )

      let (result, preCall, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release
      ) { try await session.respond(to: "Hi") }

      try Self.expectMutationError(result)
      if preserves {
        #expect(Array(session.transcript.prefix(afterWrite.count)) == Array(afterWrite))
        #expect(session.transcript.count == afterWrite.count + 1)
        guard case .toolCalls = session.transcript.last else {
          Issue.record(
            "Expected a tool calls entry, got \(String(describing: session.transcript.last))")
          return
        }
      } else {
        #expect(session.transcript == preCall)
      }
      #expect(session.usage.output.totalTokenCount == 0)
    }

    @Test(arguments: [(false, false), (false, true), (true, false), (true, true)])
    func writeDuringToolExecutionAppendsNoOutputs(isStream: Bool, preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.toolScript(
          tool: "gated", gateTurnOne: false, entered: entered, release: release),
        preserves: preserves,
        extraTools: [GatedTool(entered: entered, release: release)]
      )

      let (result, preCall, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release
      ) {
        if isStream {
          for try await _ in session.streamResponse(to: "Hi") {}
        } else {
          try await session.respond(to: "Hi")
        }
      }

      try Self.expectMutationError(result)
      #expect(session.transcript == (preserves ? afterWrite : preCall))
      #expect(session.usage.output.totalTokenCount == 1)
    }

    @Test
    func respondAppendsStructuredContent() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.phasedScript(
          before: [Self.text(#"{"city":"#)],
          after: [Self.text(#" "Paris", "street": "Main"}"#)],
          entered: entered,
          release: release
        ),
        preserves: true
      )

      let (result, _, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release
      ) { try await session.respond(to: "Hi", generating: MacroFixtures.Address.self) }

      try Self.expectMutationError(result)
      #expect(session.transcript.count == afterWrite.count + 1)
      guard case .response(let response) = session.transcript.last,
        case .structure(let structure) = response.segments.first
      else {
        Issue.record(
          "Expected a structured response, got \(String(describing: session.transcript.last))")
        return
      }
      #expect(try structure.content.value(String.self, forProperty: "city") == "Paris")
    }

    // MARK: - streamResponse

    @Test(arguments: policies)
    func streamAppendsOnlyTheEventItWasApplying(preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.phasedScript(
          before: [Self.text("a")],
          after: [Self.text("b"), Self.text("c")],
          entered: entered,
          release: release
        ),
        preserves: preserves
      )

      let (result, preCall, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release,
        readyCount: 3
      ) { for try await _ in session.streamResponse(to: "Hi") {} }

      try Self.expectMutationError(result)
      if preserves {
        #expect(Array(session.transcript.prefix(afterWrite.count)) == Array(afterWrite))
        #expect(session.transcript.count == afterWrite.count + 1)
        #expect(SessionObservationTests.responseText(session.transcript.last) == "b")
      } else {
        #expect(session.transcript == preCall)
      }
      #expect(session.usage.output.totalTokenCount == 0)
    }

    @Test
    func streamAppendsANewEntryAfterALongerWrite() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.phasedScript(
          before: [Self.text("a")],
          after: [Self.text("b")],
          entered: entered,
          release: release
        ),
        preserves: true
      )

      let (result, _, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release,
        value: Self.longerExternalValue,
        readyCount: 3
      ) { for try await _ in session.streamResponse(to: "Hi") {} }

      try Self.expectMutationError(result)
      #expect(Array(session.transcript.prefix(afterWrite.count)) == Array(afterWrite))
      #expect(session.transcript.count == afterWrite.count + 1)
      #expect(SessionObservationTests.responseText(session.transcript.last) == "b")
    }

    @Test
    func streamWriteAfterTheTurnsLastEventAppendsNothing() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.toolScript(
          tool: "note", gateTurnOne: true, entered: entered, release: release),
        preserves: true
      )

      let (result, _, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release,
        readyCount: 3
      ) { for try await _ in session.streamResponse(to: "Hi") {} }

      try Self.expectMutationError(result)
      #expect(session.transcript == afterWrite)
      #expect(session.usage.output.totalTokenCount == 0)
    }

    @Test(arguments: policies)
    func streamFragmentThatCantApplyAloneThrowsItsError(preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: Self.phasedScript(
          before: [Self.text(#"{"city":"#)],
          after: [Self.text(#" "Paris"}"#)],
          entered: entered,
          release: release
        ),
        preserves: preserves
      )

      let (result, preCall, afterWrite) = try await Self.writeDuringCall(
        session: session,
        entered: entered,
        release: release,
        readyCount: 3
      ) {
        for try await _ in session.streamResponse(to: "Hi", generating: MacroFixtures.Address.self)
        {}
      }

      #expect(throws: GeneratedContent.ParsingError.self) { try result.get() }
      #expect(session.transcript == (preserves ? afterWrite : preCall))
    }
  }
#endif  // compiler(>=6.4)
