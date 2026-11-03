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

  /// Tests for releasing a `ResponseStream` (and its iterators) while generation runs, matching
  /// Apple's framework.
  ///
  /// Releasing every copy of a stream while its executor is still running cancels the call: the
  /// error-handling policy decides the transcript and no turn usage is added. Retaining the stream,
  /// or releasing it after the final turn's executor returned, lets the response commit.
  @Suite("Releasing a response stream")
  struct StreamReleaseTests {
    // MARK: - Fixtures

    typealias Signal = SessionObservationTests.Signal

    /// A tool that opens `entered`, then sleeps until cancelled.
    struct SleepingTool: Tool {
      /// The arguments: `text`.
      typealias Arguments = SessionObservationTests.NoteTool.Arguments

      /// The tool name.
      let name = "sleeper"

      /// The tool description.
      let description = "Sleeps until cancelled."

      /// Opened when the tool starts.
      let entered: Signal

      /// Opens `entered`, then sleeps for a minute or until cancelled.
      ///
      /// - Parameter arguments: The arguments.
      /// - Returns: `"woke"`.
      @concurrent func call(arguments: Arguments) async throws -> String {
        entered.open()
        try await Task.sleep(for: .seconds(60))
        return "woke"
      }
    }

    /// The policies to test: whether each preserves.
    static let policies = [false, true]

    /// Creates a session for `script` with the `note` tool and any `extraTools`.
    static func makeSession(
      script: @escaping SessionObservationTests.ScriptModel.Script,
      preserves: Bool,
      extraTools: [any Tool] = []
    ) -> LanguageModelSession {
      let session = LanguageModelSession(
        model: SessionObservationTests.ScriptModel(script: script),
        tools: [SessionObservationTests.NoteTool()] + extraTools,
        instructions: Instructions("Be brief.")
      )
      session.transcriptErrorHandlingPolicy = preserves ? .preserveTranscript : nil
      return session
    }

    // MARK: - Release while generating

    @Test(arguments: policies)
    func releasingMidTurnCancelsTheCall(preserves: Bool) async throws {
      let entered = Signal()
      let session = Self.makeSession(
        script: SessionObservationTests.sleepingScript(entered: entered),
        preserves: preserves
      )
      let preCall = session.transcript

      do {
        let stream = session.streamResponse(to: "Hi")
        await entered.wait()
        try await SessionObservationTests.waitUntil { session.transcript.count == 3 }
        withExtendedLifetime(stream) {}
      }
      try await SessionObservationTests.waitUntil { !session.isResponding }

      if preserves {
        #expect(session.transcript.count == 3)
        #expect(SessionObservationTests.responseText(session.transcript.last) == "a")
      } else {
        #expect(session.transcript == preCall)
      }
      #expect(session.usage.output.totalTokenCount == 0)
    }

    @Test(arguments: policies)
    func releasingBeforeAnyEventCancelsTheCall(preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: SessionObservationTests.gatedScript(entered: entered, release: release),
        preserves: preserves
      )
      let preCall = session.transcript

      _ = session.streamResponse(to: "Hi")
      try await SessionObservationTests.waitUntil { !session.isResponding }
      release.open()

      if preserves {
        #expect(session.transcript.count == 2)
        guard case .prompt = session.transcript.last else {
          Issue.record("Expected the prompt to stay, got \(session.transcript)")
          return
        }
      } else {
        #expect(session.transcript == preCall)
      }
    }

    @Test(arguments: policies)
    func releasingDuringAToolCancelsTheCall(preserves: Bool) async throws {
      let entered = Signal()
      let session = Self.makeSession(
        script: PreserveMergeTests.toolScript(
          tool: "sleeper",
          gateTurnOne: false,
          entered: Signal(),
          release: Signal()
        ),
        preserves: preserves,
        extraTools: [SleepingTool(entered: entered)]
      )
      let preCall = session.transcript

      do {
        let stream = session.streamResponse(to: "Hi")
        await entered.wait()
        withExtendedLifetime(stream) {}
      }
      try await SessionObservationTests.waitUntil { !session.isResponding }

      if preserves {
        #expect(session.transcript.count == 3)
        guard case .toolCalls = session.transcript.last else {
          Issue.record("Expected the tool calls to stay, got \(session.transcript)")
          return
        }
      } else {
        #expect(session.transcript == preCall)
      }
      #expect(session.usage.output.totalTokenCount == 1)
    }

    @Test
    func sessionAcceptsANewCallAfterARelease() async throws {
      let entered = Signal()
      let callCount = Mutex(0)
      let sleepingScript = SessionObservationTests.sleepingScript(entered: entered)
      let textScript = SessionObservationTests.textScript(count: 1)
      let session = Self.makeSession(
        script: { request, channel in
          let call = callCount.withLock {
            $0 += 1
            return $0
          }
          if call == 1 {
            try await sleepingScript(request, channel)
          } else {
            try await textScript(request, channel)
          }
        },
        preserves: false
      )
      do {
        let stream = session.streamResponse(to: "Hi")
        await entered.wait()
        withExtendedLifetime(stream) {}
      }
      try await SessionObservationTests.waitUntil { !session.isResponding }

      let response = try await session.respond(to: "Again")

      #expect(response.content == "t1")
      #expect(session.isResponding == false)
      #expect(callCount.withLock { $0 } == 2)
    }

    // MARK: - Kept streams

    @Test
    func retainingTheStreamAfterBreakingCommits() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: SessionObservationTests.gatedScript(entered: entered, release: release),
        preserves: false
      )
      let stream = session.streamResponse(to: "Hi")

      for try await _ in stream {
        break
      }
      release.open()
      try await SessionObservationTests.waitUntil { !session.isResponding }
      withExtendedLifetime(stream) {}

      #expect(session.transcript.count == 3)
      #expect(SessionObservationTests.responseText(session.transcript.last) == "ab")
    }

    @Test
    func releasingAfterTheCallFinishedKeepsTheResponse() async throws {
      let session = Self.makeSession(script: SessionObservationTests.textScript(), preserves: false)

      do {
        let stream = session.streamResponse(to: "Hi")
        try await SessionObservationTests.waitUntil { !session.isResponding }
        withExtendedLifetime(stream) {}
      }

      #expect(session.transcript.count == 3)
      #expect(SessionObservationTests.responseText(session.transcript.last) == "t1t2t3")
    }

    @Test
    func collectHoldsTheStream() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(
        script: SessionObservationTests.gatedScript(entered: entered, release: release),
        preserves: false
      )

      let task = Task { try await session.streamResponse(to: "Hi").collect() }
      await entered.wait()
      release.open()
      let response = try await task.value

      #expect(response.content == "ab")
    }

    // MARK: - Tools during cancellation

    /// A tool that ignores cancellation: it waits for `release`, then returns its output.
    struct StubbornTool: Tool {
      /// The arguments: `text`.
      typealias Arguments = SessionObservationTests.NoteTool.Arguments

      /// The tool name.
      let name = "stubborn"

      /// The tool description.
      let description = "Ignores cancellation."

      /// Opened when the tool starts.
      let entered: Signal

      /// Awaited (ignoring cancellation) before the tool returns.
      let release: Signal

      /// Waits for `release`, then returns `"stubborn"`.
      ///
      /// - Parameter arguments: The arguments.
      /// - Returns: `"stubborn"`.
      @concurrent func call(arguments: Arguments) async throws -> String {
        entered.open()
        await release.wait()
        return "stubborn"
      }
    }

    /// Creates a session whose model calls `tool` (the stubborn or sleeping tool).
    static func makeToolSession(
      tool: String,
      entered: Signal,
      release: Signal,
      preserves: Bool
    ) -> LanguageModelSession {
      makeSession(
        script: PreserveMergeTests.toolScript(
          tool: tool,
          gateTurnOne: false,
          entered: Signal(),
          release: Signal()
        ),
        preserves: preserves,
        extraTools: [
          StubbornTool(entered: entered, release: release), SleepingTool(entered: entered),
        ]
      )
    }

    /// Matches Apple's runtime: a tool that ignores cancellation still gets its output appended,
    /// and the call then stops before the next turn.
    @Test(arguments: policies)
    func releasingDuringAToolThatIgnoresCancellationKeepsItsOutput(preserves: Bool) async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeToolSession(
        tool: "stubborn",
        entered: entered,
        release: release,
        preserves: preserves
      )
      let preCall = session.transcript

      do {
        let stream = session.streamResponse(to: "Hi")
        await entered.wait()
        withExtendedLifetime(stream) {}
      }
      release.open()
      try await SessionObservationTests.waitUntil { !session.isResponding }

      if preserves {
        #expect(session.transcript.count == 4)
        guard case .toolOutput = session.transcript.last else {
          Issue.record("Expected the tool output to stay, got \(session.transcript)")
          return
        }
      } else {
        #expect(session.transcript == preCall)
      }
    }

    /// `collect()` surfaces a cooperative tool's
    /// `ToolCallError(CancellationError)`, and `CancellationError` when the tool ignored it.
    @Test(arguments: [false, true])
    func collectAfterCancellingDuringAToolSurfacesApplesError(toolIgnoresCancellation: Bool)
      async throws
    {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeToolSession(
        tool: toolIgnoresCancellation ? "stubborn" : "sleeper",
        entered: entered,
        release: release,
        preserves: true
      )
      let task = Task { () -> (loopError: (any Error)?, collectError: (any Error)?) in
        let stream = session.streamResponse(to: "Hi")
        var loopError: (any Error)?
        do {
          for try await _ in stream {}
        } catch {
          loopError = error
        }
        do {
          _ = try await stream.collect()
          return (loopError, nil)
        } catch {
          return (loopError, error)
        }
      }

      await entered.wait()
      task.cancel()
      release.open()
      let (loopError, collectError) = await task.value

      #expect(loopError == nil)
      if toolIgnoresCancellation {
        #expect(collectError is CancellationError)
      } else {
        let error = try #require(collectError as? LanguageModelSession.ToolCallError)
        #expect(error.underlyingError is CancellationError)
      }
    }

    /// `respond` throws `CancellationError` and,
    /// under `.preserveTranscript`, keeps the tool output.
    @Test
    func respondCancelledDuringAToolThatIgnoresCancellation() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeToolSession(
        tool: "stubborn",
        entered: entered,
        release: release,
        preserves: true
      )
      let task = Task { try await session.respond(to: "Hi") }

      await entered.wait()
      task.cancel()
      release.open()
      let result = await task.result

      #expect(throws: CancellationError.self) { try result.get() }
      #expect(session.transcript.count == 4)
      guard case .toolOutput = session.transcript.last else {
        Issue.record("Expected the tool output to stay, got \(session.transcript)")
        return
      }
    }
  }
#endif  // compiler(>=6.4)
