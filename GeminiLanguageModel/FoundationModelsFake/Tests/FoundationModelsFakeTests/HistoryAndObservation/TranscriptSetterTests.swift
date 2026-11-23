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
  import Testing

  @testable import FoundationModelsFake

  /// Tests for what `LanguageModelSession.transcript`'s setter and `init(model:tools:transcript:)`
  /// store, matching Apple's framework.
  @Suite("LanguageModelSession transcript setter")
  struct TranscriptSetterTests {
    // MARK: - Fixtures

    /// A tool excluded from the instructions' tool definitions.
    struct HiddenTool: Tool {
      /// The arguments: `text`.
      typealias Arguments = SessionObservationTests.NoteTool.Arguments

      /// The tool name.
      let name = "hidden"

      /// The tool description.
      let description = "Not listed in instructions."

      /// Excluded from instructions.
      let includesSchemaInInstructions = false

      /// Returns `"hidden"`.
      ///
      /// - Parameter arguments: The arguments.
      /// - Returns: `"hidden"`.
      @concurrent func call(arguments: Arguments) async throws -> String {
        "hidden"
      }
    }

    /// The definition of the `note` tool.
    static let noteDefinition = Transcript.ToolDefinition(tool: SessionObservationTests.NoteTool())

    /// The definition of the hidden tool.
    static let hiddenDefinition = Transcript.ToolDefinition(tool: HiddenTool())

    /// A model that answers with one text event.
    static let model = SessionObservationTests.ScriptModel(
      script: SessionObservationTests.textScript(count: 1, usage: false)
    )

    /// Returns a prompt entry whose ID is `id`.
    static func prompt(_ id: String) -> Transcript.Entry {
      .prompt(Transcript.Prompt(id: id, segments: []))
    }

    /// Returns an instructions entry whose ID and text are `id`, with `toolDefinitions`.
    static func instructions(
      _ id: String,
      toolDefinitions: [Transcript.ToolDefinition] = []
    ) -> Transcript.Entry {
      .instructions(
        Transcript.Instructions(
          id: id,
          segments: [.text(Transcript.TextSegment(id: "s-\(id)", content: id))],
          toolDefinitions: toolDefinitions
        )
      )
    }

    /// Returns the instructions in `entry`, or `nil`.
    static func instructions(in entry: Transcript.Entry?) -> Transcript.Instructions? {
      guard case .instructions(let instructions) = entry else { return nil }
      return instructions
    }

    /// Creates a session with instructions and the `note` tool.
    static func makeSession() -> LanguageModelSession {
      LanguageModelSession(
        model: model,
        tools: [SessionObservationTests.NoteTool()],
        instructions: Instructions("Be brief.")
      )
    }

    // MARK: - Sessions with tools in instructions

    @Test
    func settingWithoutInstructionsInsertsAToolsOnlyEntry() throws {
      let session = Self.makeSession()
      let initialID = try #require(session.transcript.first?.id)

      session.transcript = Transcript(entries: [Self.prompt("P1")])

      let inserted = try #require(Self.instructions(in: session.transcript.first))
      #expect(session.transcript.map(\.id).dropFirst() == ["P1"])
      #expect(inserted.id != initialID)
      #expect(inserted.segments.isEmpty)
      #expect(inserted.toolDefinitions == [Self.noteDefinition])
    }

    @Test
    func insertedEntryKeepsOneIDPerSession() throws {
      let session = Self.makeSession()

      session.transcript = Transcript(entries: [Self.prompt("P1")])
      let firstID = try #require(session.transcript.first?.id)
      session.transcript = Transcript(entries: [Self.instructions("I2"), Self.prompt("P2")])
      session.transcript = Transcript(entries: [Self.prompt("P3")])

      #expect(session.transcript.first?.id == firstID)
    }

    @Test
    func settingAnEmptyTranscriptLeavesOnlyTheInsertedEntry() throws {
      let session = Self.makeSession()

      session.transcript = Transcript()

      let inserted = try #require(Self.instructions(in: session.transcript.first))
      #expect(session.transcript.count == 1)
      #expect(inserted.toolDefinitions == [Self.noteDefinition])
    }

    @Test(arguments: [[], [hiddenDefinition], [hiddenDefinition, noteDefinition]])
    func leadingInstructionsGetTheSessionsToolDefinitions(
      _ toolDefinitions: [Transcript.ToolDefinition]
    ) throws {
      let session = Self.makeSession()

      session.transcript = Transcript(entries: [
        Self.instructions("I2", toolDefinitions: toolDefinitions), Self.prompt("P1"),
      ])

      let leading = try #require(Self.instructions(in: session.transcript.first))
      #expect(session.transcript.map(\.id) == ["I2", "P1"])
      #expect(leading.segments == [.text(Transcript.TextSegment(id: "s-I2", content: "I2"))])
      #expect(leading.toolDefinitions == [Self.noteDefinition])
    }

    @Test
    func laterInstructionsEntriesAreUnchanged() throws {
      let session = Self.makeSession()

      session.transcript = Transcript(entries: [Self.prompt("P1"), Self.instructions("Ilater")])

      let later = try #require(Self.instructions(in: session.transcript.last))
      #expect(session.transcript.count == 3)
      #expect(later.id == "Ilater")
      #expect(later.toolDefinitions.isEmpty)
    }

    @Test
    func historyWritesKeepTheOriginalInstructionsEntry() throws {
      let session = Self.makeSession()
      let original = try #require(session.transcript.first)

      session.transcript.history = [Self.prompt("H1")]
      let afterAssign = session.transcript
      session.transcript.history = []

      #expect(afterAssign.first == original)
      #expect(afterAssign.map(\.id).dropFirst() == ["H1"])
      #expect(Array(session.transcript) == [original])
    }

    @Test
    func removingTheLeadingEntryInsertsTheSessionsEntry() throws {
      let session = Self.makeSession()
      session.transcript.append(Self.prompt("A1"))

      session.transcript.removeFirst()

      let inserted = try #require(Self.instructions(in: session.transcript.first))
      #expect(inserted.id == session.insertedInstructionsID)
      #expect(inserted.segments.isEmpty)
      #expect(inserted.toolDefinitions == [Self.noteDefinition])
      #expect(session.transcript.map(\.id).dropFirst() == ["A1"])
    }

    @Test
    func eachSetNotifiesOnce() {
      let session = Self.makeSession()
      let recorder = SessionObservationTests.Recorder(session: session)

      session.transcript = Transcript(entries: [Self.prompt("P1")])
      session.transcript.history = [Self.prompt("H1")]

      #expect(recorder.properties == [.transcript, .transcript])
    }

    // MARK: - Sessions without tools in instructions

    @Test
    func instructionsWithoutToolsAreNotKept() {
      let session = LanguageModelSession(model: Self.model, instructions: Instructions("Be brief."))

      session.transcript = Transcript(entries: [Self.prompt("P1")])

      #expect(session.transcript.map(\.id) == ["P1"])
    }

    @Test
    func toolsExcludedFromInstructionsAreNotKept() {
      let session = LanguageModelSession(model: Self.model, tools: [HiddenTool()])

      session.transcript = Transcript(entries: [Self.prompt("P1")])

      #expect(session.transcript.map(\.id) == ["P1"])
    }

    @Test
    func sessionsWithoutToolsStoreTheValueAsIs() {
      let session = LanguageModelSession(model: Self.model)
      let value = Transcript(entries: [
        Self.instructions("I2", toolDefinitions: [Self.hiddenDefinition]), Self.prompt("P1"),
      ])

      session.transcript = value

      #expect(session.transcript == value)
    }

    // MARK: - init(model:tools:transcript:)

    @Test
    func initWithToolsInsertsAnEntryWithItsOwnID() throws {
      let session = LanguageModelSession(
        model: Self.model,
        tools: [SessionObservationTests.NoteTool()],
        transcript: Transcript(entries: [Self.prompt("P0")])
      )
      let initEntry = try #require(Self.instructions(in: session.transcript.first))

      session.transcript = Transcript(entries: [Self.prompt("P1")])

      let setEntry = try #require(Self.instructions(in: session.transcript.first))
      #expect(initEntry.segments.isEmpty)
      #expect(initEntry.toolDefinitions == [Self.noteDefinition])
      #expect(setEntry.id != initEntry.id)
    }

    @Test
    func initWithToolsRewritesLeadingToolDefinitions() throws {
      let session = LanguageModelSession(
        model: Self.model,
        tools: [SessionObservationTests.NoteTool()],
        transcript: Transcript(entries: [Self.instructions("I0"), Self.prompt("P0")])
      )

      let leading = try #require(Self.instructions(in: session.transcript.first))
      #expect(session.transcript.map(\.id) == ["I0", "P0"])
      #expect(leading.toolDefinitions == [Self.noteDefinition])
    }

    @Test
    func initWithoutToolsStoresTheTranscriptAsIs() {
      let transcript = Transcript(entries: [Self.prompt("P0")])

      let session = LanguageModelSession(model: Self.model, transcript: transcript)

      #expect(session.transcript == transcript)
    }

    // MARK: - Reverts

    @Test
    func revertRestoresTheExactPreCallTranscript() async throws {
      let session = LanguageModelSession(
        model: SessionObservationTests.ScriptModel(script: SessionObservationTests.failingScript),
        tools: [SessionObservationTests.NoteTool()],
        transcript: Transcript(entries: [Self.prompt("P0")])
      )
      let preCall = session.transcript

      await #expect(throws: SessionObservationTests.ScriptError.self) {
        try await session.respond(to: "Hi")
      }

      #expect(session.transcript == preCall)
    }
  }
#endif  // compiler(>=6.4)
