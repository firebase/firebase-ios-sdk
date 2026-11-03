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
  import Dispatch
  import Observation
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  /// Tests for the `Observable` conformance of `LanguageModelSession`.
  ///
  /// The expected notification sequences match Apple's framework. Abbreviations in comments:
  /// `R` is `isResponding`, `T` is `transcript`, and `U` is `usage`.
  @Suite("LanguageModelSession observation")
  struct SessionObservationTests {
    // MARK: - Test support

    /// An observable property of the session.
    enum Property: String, Sendable {
      case transcript
      case isResponding
      case usage
    }

    /// One notification: the property and its value read from inside `onChange` (the old value).
    struct Note: Sendable, Equatable {
      /// The property that notified.
      let property: Property

      /// The property's value read inside `onChange`, before the mutation.
      let oldValue: String
    }

    /// Records every notification from a session's observable properties, in order.
    ///
    /// Each `onChange` reads the session synchronously and re-registers, so a session that notified
    /// while holding its state lock would deadlock here.
    final class Recorder: Sendable {
      /// Mutable recorder state.
      private struct State: Sendable {
        /// Whether `onChange` should re-register.
        var isActive = true

        /// The notifications so far.
        var notes: [Note] = []
      }

      /// The observed session.
      private let session: LanguageModelSession

      /// The recorder state.
      private let state = Mutex(State())

      /// Starts observing `transcript`, `isResponding`, and `usage` of `session`.
      ///
      /// - Parameter session: The session to observe.
      init(session: LanguageModelSession) {
        self.session = session
        track(.transcript)
        track(.isResponding)
        track(.usage)
      }

      /// The notifications so far.
      var notes: [Note] {
        state.withLock { $0.notes }
      }

      /// The properties that notified so far, in order.
      var properties: [Property] {
        notes.map(\.property)
      }

      /// Stops re-registering after the next notification of each property.
      func stop() {
        state.withLock { $0.isActive = false }
      }

      /// Reads `property` from the session and describes its value.
      private func read(_ property: Property) -> String {
        switch property {
        case .transcript:
          "\(session.transcript.count)"
        case .isResponding:
          "\(session.isResponding)"
        case .usage:
          "\(session.usage.output.totalTokenCount)"
        }
      }

      /// Observes `property` and re-registers after each change while active.
      private func track(_ property: Property) {
        withObservationTracking {
          _ = read(property)
        } onChange: { [self] in
          let oldValue = read(property)
          let isActive = state.withLock { state -> Bool in
            state.notes.append(Note(property: property, oldValue: oldValue))
            return state.isActive
          }
          if isActive {
            track(property)
          }
        }
      }
    }

    /// A one-shot signal that tasks can wait for.
    final class Signal: Sendable {
      /// Mutable signal state.
      private struct State: Sendable {
        /// Whether the signal has fired.
        var isOpen = false

        /// The tasks waiting for the signal.
        var waiters: [CheckedContinuation<Void, Never>] = []
      }

      /// The signal state.
      private let state = Mutex(State())

      /// Waits until `open()` is called.
      func wait() async {
        await withCheckedContinuation { continuation in
          let resumeNow = state.withLock { state -> Bool in
            guard !state.isOpen else { return true }
            state.waiters.append(continuation)
            return false
          }
          if resumeNow {
            continuation.resume()
          }
        }
      }

      /// Fires the signal and resumes every waiter.
      func open() {
        let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
          state.isOpen = true
          defer { state.waiters = [] }
          return state.waiters
        }
        for waiter in waiters {
          waiter.resume()
        }
      }
    }

    /// A model whose executor runs a script for each request.
    struct ScriptModel: LanguageModel {
      /// The script an executor runs for one request.
      typealias Script =
        @Sendable (LanguageModelExecutorGenerationRequest, LanguageModelExecutorGenerationChannel)
        async throws -> Void

      /// The executor that runs `script`.
      struct Executor: LanguageModelExecutor {
        /// The model this executor serves.
        typealias Model = ScriptModel

        /// An empty configuration: every script model shares one executor.
        struct Configuration: Hashable, Sendable {}

        /// Creates an executor.
        init(configuration: Configuration) throws {}

        /// Does nothing.
        func prewarm(model: ScriptModel, transcript: Transcript) {}

        /// Runs the model's script.
        nonisolated(nonsending) func respond(
          to request: LanguageModelExecutorGenerationRequest,
          model: ScriptModel,
          streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws {
          try await model.script(request, channel)
        }
      }

      /// The script to run for each request.
      let script: Script

      /// Tool calling and guided generation.
      var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.toolCalling, .guidedGeneration])
      }

      /// The shared configuration.
      var executorConfiguration: Executor.Configuration {
        Executor.Configuration()
      }
    }

    /// A tool that returns a fixed note.
    struct NoteTool: Tool {
      /// The arguments: `text`.
      struct Arguments: SingleStringArguments {
        /// The note text.
        var text: String

        /// The property's name.
        static var propertyName: String { "text" }

        /// The property's value.
        var value: String { text }

        /// Creates arguments.
        ///
        /// - Parameter value: The note text.
        init(value: String) { self.text = value }
      }

      /// The tool name.
      let name = "note"

      /// The tool description.
      let description = "Returns a note."

      /// Returns `"noted"`.
      ///
      /// - Parameter arguments: The arguments.
      /// - Returns: `"noted"`.
      @concurrent func call(arguments: Arguments) async throws -> String {
        "noted"
      }
    }

    /// A test failure thrown by scripts.
    struct ScriptError: Error {}

    /// Sends `count` text events and, if `usage` is `true`, a closing `updateUsage` event.
    static func textScript(count: Int = 3, usage: Bool = true) -> ScriptModel.Script {
      { _, channel in
        for index in 1...count {
          await channel.send(.response(action: .appendText("t\(index)", tokenCount: 1)))
        }
        if usage {
          await channel.send(
            .response(
              action: .updateUsage(
                input: .init(totalTokenCount: 10, cachedTokenCount: 0),
                output: .init(totalTokenCount: count, reasoningTokenCount: 0)
              )
            )
          )
        }
      }
    }

    /// Calls `note` twice, then answers with one text event after the tool outputs.
    ///
    /// Call IDs include the transcript length, because a call ID that matches an earlier call
    /// updates that call instead of creating a new one.
    static let toolScript: ScriptModel.Script = { request, channel in
      if case .toolOutput = request.transcript.last {
        await channel.send(.response(action: .appendText("done", tokenCount: 1)))
        return
      }
      let turn = request.transcript.count
      for id in ["call\(turn)-a", "call\(turn)-b"] {
        await channel.send(
          .toolCalls(
            action: .toolCall(
              id: id, name: "note", action: .appendArguments(#"{"text":"a"}"#, tokenCount: 1))
          )
        )
      }
    }

    /// Sends one text event, then throws.
    static let failingScript: ScriptModel.Script = { _, channel in
      await channel.send(.response(action: .appendText("partial", tokenCount: 1)))
      throw ScriptError()
    }

    /// Sends one text event, opens `entered`, then waits for `release` before finishing.
    static func gatedScript(entered: Signal, release: Signal) -> ScriptModel.Script {
      { _, channel in
        await channel.send(.response(action: .appendText("a", tokenCount: 1)))
        entered.open()
        await release.wait()
        await channel.send(.response(action: .appendText("b", tokenCount: 1)))
      }
    }

    /// Sends one text event, opens `entered`, then sleeps until cancelled.
    static func sleepingScript(entered: Signal) -> ScriptModel.Script {
      { _, channel in
        await channel.send(.response(action: .appendText("a", tokenCount: 1)))
        entered.open()
        try await Task.sleep(for: .seconds(60))
      }
    }

    /// Creates a session with instructions, the `note` tool, and `script`.
    static func makeSession(
      script: @escaping ScriptModel.Script,
      policy: TranscriptErrorHandlingPolicy? = nil
    ) -> LanguageModelSession {
      let session = LanguageModelSession(
        model: ScriptModel(script: script),
        tools: [NoteTool()],
        instructions: Instructions("Be brief.")
      )
      session.transcriptErrorHandlingPolicy = policy
      return session
    }

    /// The error-handling policies to test, each with whether it reverts the transcript.
    static let policies: [(TranscriptErrorHandlingPolicy?, Bool)] = [
      (nil, true),
      (.revertTranscript, true),
      (.preserveTranscript, false),
    ]

    /// Polls until `condition` holds, failing with its own issue after about five seconds.
    static func waitUntil(
      sourceLocation: SourceLocation = #_sourceLocation,
      _ condition: () -> Bool
    ) async throws {
      for _ in 0..<500 where !condition() {
        try await Task.sleep(for: .milliseconds(10))
      }
      try #require(
        condition(), "Timed out waiting for the condition", sourceLocation: sourceLocation)
    }

    /// Writes `session.transcript.history = [marker]` from inside the `onChange` of the `nth`
    /// notification of one property, as an observer that trims history would.
    final class ReentrantWriter: Sendable {
      /// The ID of the prompt entry the writer stores.
      static let markerID = "observer-write"

      /// The session to write.
      private let session: LanguageModelSession

      /// The property whose notification triggers the write.
      private let property: Property

      /// The notification number that triggers the write.
      private let nth: Int

      /// The notifications seen so far.
      private let count = Mutex(0)

      /// Arms the writer.
      ///
      /// - Parameters:
      ///   - session: The session to write.
      ///   - property: The property whose notification triggers the write.
      ///   - nth: The notification number (from 1) that triggers the write.
      init(session: LanguageModelSession, property: Property, nth: Int) {
        self.session = session
        self.property = property
        self.nth = nth
        arm()
      }

      /// Whether the write happened.
      var didWrite: Bool {
        count.withLock { $0 >= nth }
      }

      /// Observes `property` until the `nth` notification, then writes.
      private func arm() {
        withObservationTracking {
          switch property {
          case .transcript: _ = session.transcript
          case .isResponding: _ = session.isResponding
          case .usage: _ = session.usage
          }
        } onChange: { [self] in
          let notification = count.withLock { count -> Int in
            count += 1
            return count
          }
          if notification == nth {
            session.transcript.history = [
              .prompt(Transcript.Prompt(id: Self.markerID, segments: []))
            ]
          } else if notification < nth {
            arm()
          }
        }
      }
    }

    /// Where an observer writes during a call, and whether the call detects it.
    struct ReentrantWriteCase: Sendable, CustomTestStringConvertible {
      /// The case's name in test output.
      let name: String

      /// Whether the call is `streamResponse` (otherwise `respond`).
      let isStream: Bool

      /// Whether the script calls the tool (otherwise it sends 3 text events and usage).
      let usesTool: Bool

      /// The property whose notification triggers the write.
      let property: Property

      /// The notification number that triggers the write.
      let nth: Int

      /// The test description.
      var testDescription: String { name }
    }

    /// Observer writes during a call. Each one must fail the call with
    /// `transcriptMutationWhileResponding` and revert to the pre-call transcript.
    static let detectedWriteCases: [ReentrantWriteCase] = [
      ReentrantWriteCase(
        name: "respond, prompt", isStream: false, usesTool: false, property: .transcript, nth: 1),
      ReentrantWriteCase(
        name: "respond, turn commit", isStream: false, usesTool: false, property: .transcript,
        nth: 2
      ),
      ReentrantWriteCase(
        name: "respond, turn usage", isStream: false, usesTool: false, property: .usage, nth: 1),
      ReentrantWriteCase(
        name: "respond, tool turn usage", isStream: false, usesTool: true, property: .usage, nth: 1),
      ReentrantWriteCase(
        name: "respond, tool output", isStream: false, usesTool: true, property: .transcript, nth: 3
      ),
      ReentrantWriteCase(
        name: "stream, prompt", isStream: true, usesTool: false, property: .transcript, nth: 1),
      ReentrantWriteCase(
        name: "stream, first event", isStream: true, usesTool: false, property: .transcript, nth: 2),
      ReentrantWriteCase(
        name: "stream, second event", isStream: true, usesTool: false, property: .transcript, nth: 3
      ),
      ReentrantWriteCase(
        name: "stream, turn end", isStream: true, usesTool: false, property: .transcript, nth: 6),
      ReentrantWriteCase(
        name: "stream, turn usage", isStream: true, usesTool: false, property: .usage, nth: 1),
      ReentrantWriteCase(
        name: "stream, tool output", isStream: true, usesTool: true, property: .transcript, nth: 5),
    ]

    // MARK: - Idle

    @Test
    func readsDoNotNotify() {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)

      for _ in 0..<5 {
        _ = session.transcript
        _ = session.isResponding
        _ = session.usage
        _ = session.transcriptErrorHandlingPolicy
      }

      #expect(recorder.notes.isEmpty)
    }

    /// An external write to `session.transcript`.
    enum ExternalWrite: String, CaseIterable, Sendable {
      case newValue
      case equalValue
      case inPlaceAppend
    }

    @Test(arguments: ExternalWrite.allCases)
    func externalTranscriptWritesNotifyOnce(_ write: ExternalWrite) {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)

      switch write {
      case .newValue:
        session.transcript = Transcript()
      case .equalValue:
        session.transcript = session.transcript
      case .inPlaceAppend:
        session.transcript.append(.prompt(Transcript.Prompt(segments: [])))
      }

      #expect(recorder.notes == [Note(property: .transcript, oldValue: "1")])
    }

    @Test
    func errorHandlingPolicyDoesNotNotify() {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)

      session.transcriptErrorHandlingPolicy = .preserveTranscript
      session.transcriptErrorHandlingPolicy = .preserveTranscript
      session.transcriptErrorHandlingPolicy = nil

      #expect(recorder.notes.isEmpty)
    }

    @Test
    func prewarmDoesNotNotify() {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)

      session.prewarm()
      session.prewarm(promptPrefix: Prompt("Hello"))

      #expect(recorder.notes.isEmpty)
    }

    // MARK: - respond

    @Test
    func respondNotifiesOncePerCommittedTurn() async throws {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)

      try await session.respond(to: "Hi")

      // R(start), T(prompt), T(turn), U(turn), R(end): events don't notify individually.
      #expect(
        recorder.notes == [
          Note(property: .isResponding, oldValue: "false"),
          Note(property: .transcript, oldValue: "1"),
          Note(property: .transcript, oldValue: "2"),
          Note(property: .usage, oldValue: "0"),
          Note(property: .isResponding, oldValue: "true"),
        ]
      )
    }

    @Test
    func respondNotifiesUsageForATurnWithoutTokens() async throws {
      let session = Self.makeSession(script: { _, channel in
        await channel.send(.response(action: .appendText("zero", tokenCount: 0)))
      })
      let recorder = Recorder(session: session)

      try await session.respond(to: "Hi")

      #expect(
        recorder.properties == [.isResponding, .transcript, .transcript, .usage, .isResponding])
    }

    @Test
    func respondNotifiesOncePerToolOutput() async throws {
      let session = Self.makeSession(script: Self.toolScript)
      let recorder = Recorder(session: session)

      try await session.respond(to: "Use the tool")

      // R, T(prompt), T+U(turn 1), T(output 1), T(output 2), T+U(turn 2), R.
      #expect(
        recorder.properties == [
          .isResponding, .transcript, .transcript, .usage, .transcript, .transcript, .transcript,
          .usage, .isResponding,
        ]
      )
      #expect(
        recorder.notes.filter { $0.property == .transcript }.map(\.oldValue) == [
          "1", "2", "3", "4", "5",
        ])
    }

    @Test(arguments: policies)
    func respondFailureNotifiesRevertOnlyWhenReverting(
      policy: TranscriptErrorHandlingPolicy?,
      reverts: Bool
    ) async {
      let session = Self.makeSession(script: Self.failingScript, policy: policy)
      let recorder = Recorder(session: session)

      await #expect(throws: ScriptError.self) {
        try await session.respond(to: "Hi")
      }

      let expected: [Property] =
        reverts
        ? [.isResponding, .transcript, .transcript, .isResponding]
        : [.isResponding, .transcript, .isResponding]
      #expect(recorder.properties == expected)
    }

    @Test(arguments: policies)
    func respondCancellationNotifiesPartialCommitThenRevert(
      policy: TranscriptErrorHandlingPolicy?,
      reverts: Bool
    ) async {
      let entered = Signal()
      let session = Self.makeSession(script: Self.sleepingScript(entered: entered), policy: policy)
      let recorder = Recorder(session: session)
      let task = Task {
        try await session.respond(to: "Hi")
      }
      await entered.wait()

      task.cancel()
      let result = await task.result

      #expect(throws: CancellationError.self) { try result.get() }
      let expected: [Property] =
        reverts
        ? [.isResponding, .transcript, .transcript, .transcript, .isResponding]
        : [.isResponding, .transcript, .transcript, .isResponding]
      #expect(recorder.properties == expected)
    }

    @Test
    func rejectedConcurrentRequestNotifiesIsResponding() async throws {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(script: Self.gatedScript(entered: entered, release: release))
      let recorder = Recorder(session: session)
      let first = Task {
        try await session.respond(to: "First")
      }
      await entered.wait()
      let notesBeforeRejection = recorder.notes.count

      await #expect(throws: LanguageModelSession.Error.self) {
        try await session.respond(to: "Second")
      }
      let rejectionNotes = Array(recorder.notes.dropFirst(notesBeforeRejection))
      release.open()
      _ = try await first.value

      #expect(rejectionNotes == [Note(property: .isResponding, oldValue: "true")])
      #expect(
        recorder.notes.suffix(3) == [
          Note(property: .transcript, oldValue: "2"),
          Note(property: .usage, oldValue: "0"),
          Note(property: .isResponding, oldValue: "false"),
        ]
      )
    }

    @Test
    func externalWriteDuringRespondNotifiesWriteMergeAndRevert() async {
      let entered = Signal()
      let release = Signal()
      let session = Self.makeSession(script: Self.gatedScript(entered: entered, release: release))
      let recorder = Recorder(session: session)
      let task = Task {
        try await session.respond(to: "Hi")
      }
      await entered.wait()

      session.transcript = Transcript()
      release.open()
      let result = await task.result

      // R, T(prompt), T(external write), T(turn merged onto the write), T(revert), R: the write
      // plus two more `transcript` notifications, as in Apple's session.
      #expect(throws: LanguageModelSession.Error.self) { try result.get() }
      #expect(
        recorder.properties == [
          .isResponding, .transcript, .transcript, .transcript, .transcript, .isResponding,
        ]
      )
    }

    // MARK: - streamResponse

    @Test
    func streamNotifiesPerEventAndAtTurnEnd() async throws {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)

      _ = try await session.streamResponse(to: "Hi").collect()

      // R, T(prompt), T x 4 (3 text events + updateUsage), T(turn end), U(turn), R.
      #expect(
        recorder.properties == [
          .isResponding, .transcript, .transcript, .transcript, .transcript, .transcript,
          .transcript,
          .usage, .isResponding,
        ]
      )
    }

    @Test
    func streamWithToolsNotifiesPerEventOutputAndTurn() async throws {
      let session = Self.makeSession(script: Self.toolScript)
      let recorder = Recorder(session: session)

      for try await _ in session.streamResponse(to: "Use the tool") {}

      // Apple's framework sends 8 transcript notifications for this shape; the fake matches.
      #expect(
        recorder.properties == [
          .isResponding, .transcript, .transcript, .transcript, .transcript, .usage, .transcript,
          .transcript, .transcript, .transcript, .usage, .isResponding,
        ]
      )
    }

    @Test(arguments: policies)
    func streamFailureNotifiesUsageThenRevert(
      policy: TranscriptErrorHandlingPolicy?,
      reverts: Bool
    ) async {
      let session = Self.makeSession(script: Self.failingScript, policy: policy)
      let recorder = Recorder(session: session)

      await #expect(throws: ScriptError.self) {
        for try await _ in session.streamResponse(to: "Hi") {}
      }

      let expected: [Property] =
        reverts
        ? [.isResponding, .transcript, .transcript, .usage, .transcript, .isResponding]
        : [.isResponding, .transcript, .transcript, .usage, .isResponding]
      #expect(recorder.properties == expected)
    }

    @Test(arguments: policies)
    func streamCancellationNotifiesTranscriptThenRevert(
      policy: TranscriptErrorHandlingPolicy?,
      reverts: Bool
    ) async {
      let entered = Signal()
      let session = Self.makeSession(script: Self.sleepingScript(entered: entered), policy: policy)
      let recorder = Recorder(session: session)
      let task = Task {
        for try await _ in session.streamResponse(to: "Hi") {}
      }
      await entered.wait()

      task.cancel()
      _ = await task.result

      // Whether the event before cancellation is applied first is timing-dependent, so only the
      // start and the cancellation tail are asserted.
      let properties = recorder.properties
      let tail: [Property] =
        reverts ? [.transcript, .transcript, .isResponding] : [.transcript, .isResponding]
      #expect(Array(properties.prefix(2)) == [.isResponding, .transcript])
      #expect(Array(properties.suffix(tail.count)) == tail)
      #expect(!properties.contains(.usage))
    }

    @Test
    func retainedStreamKeepsNotifyingWhileItDrains() async throws {
      let session = Self.makeSession(script: Self.textScript())
      let recorder = Recorder(session: session)
      let stream = session.streamResponse(to: "Hi")

      do {
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
      }
      try await Self.waitUntil { recorder.properties.filter { $0 == .isResponding }.count == 2 }
      withExtendedLifetime(stream) {}

      #expect(
        recorder.properties == [
          .isResponding, .transcript, .transcript, .transcript, .transcript, .transcript,
          .transcript,
          .usage, .isResponding,
        ]
      )
    }

    // MARK: - Reentrancy

    @Test(.timeLimit(.minutes(1)))
    func observersReadingTheSessionDoNotDeadlock() async throws {
      let iterations = 50
      let session = Self.makeSession(script: Self.toolScript)
      let recorder = Recorder(session: session)
      let reader = Task.detached {
        while !Task.isCancelled {
          _ = session.transcript
          _ = session.isResponding
          _ = session.usage
          await Task.yield()
        }
      }

      for _ in 0..<iterations {
        try await session.respond(to: "Use the tool")
        _ = try await session.streamResponse(to: "Use the tool").collect()
      }
      reader.cancel()
      recorder.stop()

      // respond: 9 notifications; streamResponse: 12 (see the tool tests above).
      #expect(recorder.notes.count == iterations * (9 + 12))
      #expect(session.isResponding == false)
    }

    // MARK: - Reentrant writes

    @Test(arguments: detectedWriteCases)
    func observerWriteDuringCallFailsAndReverts(_ writeCase: ReentrantWriteCase) async throws {
      let session = Self.makeSession(
        script: writeCase.usesTool ? Self.toolScript : Self.textScript())
      let preCallIDs = session.transcript.map(\.id)
      let writer = ReentrantWriter(
        session: session, property: writeCase.property, nth: writeCase.nth)

      let error = await #expect(throws: LanguageModelSession.Error.self) {
        if writeCase.isStream {
          for try await _ in session.streamResponse(to: "Hi") {}
        } else {
          try await session.respond(to: "Hi")
        }
      }

      #expect(writer.didWrite)
      let sessionError = try #require(error)
      guard case .transcriptMutationWhileResponding = sessionError else {
        Issue.record("Expected transcriptMutationWhileResponding, got \(sessionError)")
        return
      }
      #expect(session.transcript.map(\.id) == preCallIDs)
      #expect(session.isResponding == false)
    }

    @Test(arguments: [false, true])
    func observerWriteAtStartIsAPreCallWrite(isStream: Bool) async throws {
      let session = Self.makeSession(script: Self.textScript())
      let instructionsID = try #require(session.transcript.first?.id)
      let writer = ReentrantWriter(session: session, property: .isResponding, nth: 1)

      if isStream {
        _ = try await session.streamResponse(to: "Hi").collect()
      } else {
        try await session.respond(to: "Hi")
      }

      let ids = session.transcript.map(\.id)
      #expect(writer.didWrite)
      #expect(ids.count == 4)
      #expect(Array(ids.prefix(2)) == [instructionsID, ReentrantWriter.markerID])
    }

    @Test(arguments: [false, true])
    func observerWriteAtEndReplacesTheCommittedTranscript(isStream: Bool) async throws {
      let session = Self.makeSession(script: Self.textScript())
      let instructionsID = try #require(session.transcript.first?.id)
      let writer = ReentrantWriter(session: session, property: .isResponding, nth: 2)

      if isStream {
        for try await _ in session.streamResponse(to: "Hi") {}
      } else {
        try await session.respond(to: "Hi")
      }

      #expect(writer.didWrite)
      #expect(session.transcript.map(\.id) == [instructionsID, ReentrantWriter.markerID])
    }

    // MARK: - Cancellation after an external write

    /// The calls and policies for the write-then-cancel tests: whether the call is a stream, and
    /// whether the policy is `.preserveTranscript`.
    static let writeThenCancelCases: [(Bool, Bool)] = [
      (false, false), (false, true), (true, false), (true, true),
    ]

    /// Matches Apple's runtime: a cancelled `respond`
    /// throws the mutation error (keeping the write plus the partial response under
    /// `.preserveTranscript`), while a cancelled stream ends normally and the policy decides.
    @Test(arguments: writeThenCancelCases)
    func externalWriteThenCancellationMatchesApple(isStream: Bool, preserves: Bool) async throws {
      let entered = Signal()
      let session = Self.makeSession(
        script: Self.sleepingScript(entered: entered),
        policy: preserves ? .preserveTranscript : nil
      )
      let preCall = session.transcript
      let task = Task {
        if isStream {
          for try await _ in session.streamResponse(to: "Hi") {}
        } else {
          try await session.respond(to: "Hi")
        }
      }
      await entered.wait()
      if isStream {
        try await Self.waitUntil { session.transcript.count == 3 }
      }
      session.transcript = Transcript(entries: [.prompt(Transcript.Prompt(id: "ext", segments: []))]
      )
      let afterWrite = session.transcript

      task.cancel()
      let result = await task.result

      if isStream {
        #expect(throws: Never.self) { try result.get() }
        #expect(session.transcript == (preserves ? afterWrite : preCall))
      } else {
        let error = try #require(throws: LanguageModelSession.Error.self) { try result.get() }
        guard case .transcriptMutationWhileResponding = error else {
          Issue.record("Expected transcriptMutationWhileResponding, got \(error)")
          return
        }
        if preserves {
          #expect(Array(session.transcript.prefix(afterWrite.count)) == Array(afterWrite))
          #expect(session.transcript.count == afterWrite.count + 1)
          #expect(Self.responseText(session.transcript.last) == "a")
        } else {
          #expect(session.transcript == preCall)
        }
      }
      #expect(session.isResponding == false)
    }

    /// Returns the text of a response entry, or `nil`.
    static func responseText(_ entry: Transcript.Entry?) -> String? {
      guard case .response(let response) = entry else { return nil }
      return response.segments.compactMap { segment -> String? in
        if case .text(let text) = segment { return text.content }
        return nil
      }.joined()
    }

    @Test(arguments: [false, true])
    func observerWriteRevertsEvenUnderPreserve(isStream: Bool) async throws {
      let session = Self.makeSession(script: Self.textScript(), policy: .preserveTranscript)
      let preCallIDs = session.transcript.map(\.id)
      let writer = ReentrantWriter(session: session, property: .transcript, nth: 2)

      let error = await #expect(throws: LanguageModelSession.Error.self) {
        if isStream {
          for try await _ in session.streamResponse(to: "Hi") {}
        } else {
          try await session.respond(to: "Hi")
        }
      }

      #expect(writer.didWrite)
      let sessionError = try #require(error)
      guard case .transcriptMutationWhileResponding = sessionError else {
        Issue.record("Expected transcriptMutationWhileResponding, got \(sessionError)")
        return
      }
      #expect(session.transcript.map(\.id) == preCallIDs)
    }

    // MARK: - Classifying writes made from observers

    /// Runs `action` from inside the `onChange` of the `nth` notification of a session property.
    final class NthNotificationAction: Sendable {
      /// The observed session.
      private let session: LanguageModelSession

      /// The observed property.
      private let property: Property

      /// Runs on the `nth` notification.
      private let action: @Sendable () -> Void

      /// The notification number that triggers `action`.
      private let nth: Int

      /// The notifications seen so far.
      private let count = Mutex(0)

      /// Arms the observer.
      ///
      /// - Parameters:
      ///   - session: The observed session.
      ///   - property: The observed property.
      ///   - nth: The notification number (from 1) that triggers `action`.
      ///   - action: Runs inside that notification's `onChange`.
      init(
        _ session: LanguageModelSession,
        _ property: Property,
        nth: Int,
        action: @escaping @Sendable () -> Void
      ) {
        self.session = session
        self.property = property
        self.nth = nth
        self.action = action
        arm()
      }

      /// Observes until the `nth` notification, then runs `action`.
      private func arm() {
        withObservationTracking {
          switch property {
          case .transcript: _ = session.transcript
          case .isResponding: _ = session.isResponding
          case .usage: _ = session.usage
          }
        } onChange: { [self] in
          let notification = count.withLock { count -> Int in
            count += 1
            return count
          }
          if notification == nth {
            action()
          } else if notification < nth {
            arm()
          }
        }
      }
    }

    /// A task executor that runs jobs on a serial dispatch queue instead of the cooperative pool.
    final class QueueTaskExecutor: TaskExecutor {
      /// The queue that runs the jobs.
      private let queue: DispatchQueue

      /// Creates an executor with a new serial queue.
      ///
      /// - Parameter label: The queue's label.
      init(label: String) {
        queue = DispatchQueue(label: label)
      }

      /// Runs `job` on the queue.
      ///
      /// - Parameter job: The job to run.
      func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        let executor = asUnownedTaskExecutor()
        queue.async {
          unownedJob.runSynchronously(on: executor)
        }
      }
    }

    /// A `Task` started from `onChange` inherits the notification's task-local scope but writes
    /// later, while another notification of the session is in progress; it must count as an
    /// external write (merged or kept under `.preserveTranscript`), not as an observer write.
    @Test
    func writeFromATaskStartedInAnObserverIsExternal() async throws {
      let session = Self.makeSession(script: Self.textScript(), policy: .preserveTranscript)
      let gate = Signal()
      let written = DispatchSemaphore(value: 0)
      let waitResult = Mutex<DispatchTimeoutResult?>(nil)
      let afterWrite = Mutex<Transcript?>(nil)
      // The writer runs on its own queue, so the blocked notification below can't starve it of a
      // cooperative thread. It still inherits the notification's task-local values.
      let writerExecutor = QueueTaskExecutor(label: "writeFromATaskStartedInAnObserverIsExternal")
      let starter = NthNotificationAction(session, .transcript, nth: 1) {
        Task(executorPreference: writerExecutor) {
          await gate.wait()
          session.transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(id: "from-task", segments: []))
          ])
          afterWrite.withLock { $0 = session.transcript }
          written.signal()
        }
      }
      // `onChange` handlers are synchronous, so the usage notification has to block (rather than
      // suspend) to keep the write inside it.
      let blocker = NthNotificationAction(session, .usage, nth: 1) {
        gate.open()
        let result = written.wait(timeout: .now() + 5)
        waitResult.withLock { $0 = result }
      }

      let error = await #expect(throws: LanguageModelSession.Error.self) {
        try await session.respond(to: "Hi")
      }

      withExtendedLifetime((starter, blocker)) {}
      #expect(waitResult.withLock { $0 } == .success)
      let sessionError = try #require(error)
      guard case .transcriptMutationWhileResponding = sessionError else {
        Issue.record("Expected transcriptMutationWhileResponding, got \(sessionError)")
        return
      }
      let expected = try #require(afterWrite.withLock { $0 })
      #expect(session.transcript == expected)
    }

    /// Session A's observer writes session B, whose observer writes A: A's write still happens
    /// inside A's notification, so it's an observer write and reverts even under
    /// `.preserveTranscript`.
    @Test
    func observerWriteThroughAnotherSessionsObserverIsReentrant() async throws {
      let first = Self.makeSession(script: Self.textScript(), policy: .preserveTranscript)
      let second = Self.makeSession(script: Self.textScript())
      let preCall = first.transcript
      let firstObserver = NthNotificationAction(first, .transcript, nth: 2) {
        second.transcript = Transcript()
      }
      let secondObserver = NthNotificationAction(second, .transcript, nth: 1) {
        first.transcript.history = [.prompt(Transcript.Prompt(id: "nested", segments: []))]
      }

      let error = await #expect(throws: LanguageModelSession.Error.self) {
        try await first.respond(to: "Hi")
      }

      withExtendedLifetime((firstObserver, secondObserver)) {}
      let sessionError = try #require(error)
      guard case .transcriptMutationWhileResponding = sessionError else {
        Issue.record("Expected transcriptMutationWhileResponding, got \(sessionError)")
        return
      }
      #expect(first.transcript == preCall)
    }
  }
#endif  // compiler(>=6.4)
