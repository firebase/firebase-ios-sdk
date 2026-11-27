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

  /// Tests for `Transcript.HistoryView` and `Transcript.history`, matching Apple's framework.
  @Suite("Transcript.HistoryView")
  struct HistoryViewTests {
    // MARK: - Fixtures

    /// Returns an instructions entry whose ID and text are `id`.
    private static func instructions(_ id: String) -> Transcript.Entry {
      .instructions(
        Transcript.Instructions(
          id: id,
          segments: [.text(Transcript.TextSegment(id: "s-\(id)", content: id))],
          toolDefinitions: []
        )
      )
    }

    /// Returns a prompt entry whose ID and text are `id`.
    private static func prompt(_ id: String) -> Transcript.Entry {
      .prompt(
        Transcript.Prompt(
          id: id, segments: [.text(Transcript.TextSegment(id: "s-\(id)", content: id))])
      )
    }

    /// Returns a response entry whose ID and text are `id`.
    private static func response(_ id: String) -> Transcript.Entry {
      .response(
        Transcript.Response(
          id: id,
          assetIDs: [],
          segments: [.text(Transcript.TextSegment(id: "s-\(id)", content: id))]
        )
      )
    }

    /// Returns the IDs of `entries`, in order.
    private static func ids(_ entries: some Sequence<Transcript.Entry>) -> [String] {
      entries.map(\.id)
    }

    /// Returns the transcript offset of `index`.
    private static func offset(_ index: Transcript.HistoryView.Index) -> Int {
      index.offset
    }

    // MARK: - Reading

    /// A transcript and the history Apple's runtime reads from it.
    struct ReadCase: Sendable, CustomTestStringConvertible {
      /// The case's name in test output.
      let name: String

      /// The transcript entries.
      let entries: [Transcript.Entry]

      /// The IDs of the entries `history` contains.
      let expectedIDs: [String]

      /// The transcript offset of `history.startIndex`.
      let expectedStart: Int

      /// The transcript offset of `history.endIndex`.
      let expectedEnd: Int

      /// The test description.
      var testDescription: String { name }
    }

    /// The cases for reading through a history view.
    static let readCases: [ReadCase] = [
      ReadCase(
        name: "empty",
        entries: [],
        expectedIDs: [],
        expectedStart: 0,
        expectedEnd: 0
      ),
      ReadCase(
        name: "[I]",
        entries: [instructions("I1")],
        expectedIDs: [],
        expectedStart: 1,
        expectedEnd: 1
      ),
      ReadCase(
        name: "[P,R]",
        entries: [prompt("P1"), response("R1")],
        expectedIDs: ["P1", "R1"],
        expectedStart: 0,
        expectedEnd: 2
      ),
      ReadCase(
        name: "[I,P,R]",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        expectedIDs: ["P1", "R1"],
        expectedStart: 1,
        expectedEnd: 3
      ),
      ReadCase(
        name: "[I,P,I,R]",
        entries: [instructions("I1"), prompt("P1"), instructions("I2"), response("R1")],
        expectedIDs: ["P1", "I2", "R1"],
        expectedStart: 1,
        expectedEnd: 4
      ),
      ReadCase(
        name: "[P,I,R]",
        entries: [prompt("P1"), instructions("I1"), response("R1")],
        expectedIDs: ["P1", "I1", "R1"],
        expectedStart: 0,
        expectedEnd: 3
      ),
      ReadCase(
        name: "[I,I,P]",
        entries: [instructions("I1"), instructions("I2"), prompt("P1")],
        expectedIDs: ["I2", "P1"],
        expectedStart: 1,
        expectedEnd: 3
      ),
    ]

    @Test(arguments: readCases)
    func readsEntriesAfterLeadingInstructions(_ readCase: ReadCase) {
      let transcript = Transcript(entries: readCase.entries)

      let history = transcript.history

      #expect(Self.ids(history) == readCase.expectedIDs)
      #expect(history.count == readCase.expectedIDs.count)
      #expect(history.isEmpty == readCase.expectedIDs.isEmpty)
      #expect(Self.offset(history.startIndex) == readCase.expectedStart)
      #expect(Self.offset(history.endIndex) == readCase.expectedEnd)
    }

    // MARK: - Writing through Transcript.history

    /// A mutation of `Transcript.history` and the transcript Apple's runtime produced.
    struct WriteCase: Sendable, CustomTestStringConvertible {
      /// The case's name in test output.
      let name: String

      /// The transcript entries before the mutation.
      let entries: [Transcript.Entry]

      /// The mutation to apply.
      let mutation: @Sendable (inout Transcript) -> Void

      /// The IDs of the transcript entries after the mutation.
      let expectedIDs: [String]

      /// The count of `history` after the mutation.
      let expectedHistoryCount: Int

      /// The test description.
      var testDescription: String { name }
    }

    /// The cases for writing through `Transcript.history`.
    static let writeCases: [WriteCase] = [
      WriteCase(
        name: "[I].history.append(P)",
        entries: [instructions("I1")],
        mutation: { $0.history.append(prompt("Px")) },
        expectedIDs: ["I1", "Px"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[].history.append(P)",
        entries: [],
        mutation: { $0.history.append(prompt("Px")) },
        expectedIDs: ["Px"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[].history.append(I)",
        entries: [],
        mutation: { $0.history.append(instructions("Ix")) },
        expectedIDs: ["Ix"],
        expectedHistoryCount: 0
      ),
      WriteCase(
        name: "[P].history.append(R)",
        entries: [prompt("P1")],
        mutation: { $0.history.append(response("Rx")) },
        expectedIDs: ["P1", "Rx"],
        expectedHistoryCount: 2
      ),
      WriteCase(
        name: "[I,P].history.append(contentsOf: [P,R])",
        entries: [instructions("I1"), prompt("P1")],
        mutation: { $0.history.append(contentsOf: [prompt("Py"), response("Ry")]) },
        expectedIDs: ["I1", "P1", "Py", "Ry"],
        expectedHistoryCount: 3
      ),
      WriteCase(
        name: "[I,P,R].history.insert(P, at: start)",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: { $0.history.insert(prompt("Pins"), at: $0.history.startIndex) },
        expectedIDs: ["I1", "Pins", "P1", "R1"],
        expectedHistoryCount: 3
      ),
      WriteCase(
        name: "[I,P,R].history[start] = P",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: { $0.history[$0.history.startIndex] = prompt("Psub") },
        expectedIDs: ["I1", "Psub", "R1"],
        expectedHistoryCount: 2
      ),
      WriteCase(
        name: "[I,P,R].history.replaceSubrange(all, with: [P])",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: {
          $0.history.replaceSubrange(
            $0.history.startIndex..<$0.history.endIndex,
            with: [prompt("Prep")]
          )
        },
        expectedIDs: ["I1", "Prep"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[I,P,R,P,R].history.replaceSubrange(1..<3, with: [R])",
        entries: [instructions("I1"), prompt("P1"), response("R1"), prompt("P2"), response("R2")],
        mutation: {
          let history = $0.history
          let lower = history.index(history.startIndex, offsetBy: 1)
          let upper = history.index(history.startIndex, offsetBy: 3)
          $0.history.replaceSubrange(lower..<upper, with: [response("Rrep")])
        },
        expectedIDs: ["I1", "P1", "Rrep", "R2"],
        expectedHistoryCount: 3
      ),
      WriteCase(
        name: "[I,P,R].history.removeAll()",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: { $0.history.removeAll() },
        expectedIDs: ["I1"],
        expectedHistoryCount: 0
      ),
      WriteCase(
        name: "[I,P,R].history.removeFirst()",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: { $0.history.removeFirst() },
        expectedIDs: ["I1", "R1"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[I,P,R].history.removeLast()",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: { $0.history.removeLast() },
        expectedIDs: ["I1", "P1"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[I,P,R].history = []",
        entries: [instructions("I1"), prompt("P1"), response("R1")],
        mutation: { $0.history = [] },
        expectedIDs: ["I1"],
        expectedHistoryCount: 0
      ),
      WriteCase(
        name: "[I,P].history = [I2,P2]",
        entries: [instructions("I1"), prompt("P1")],
        mutation: { $0.history = [instructions("I2"), prompt("P2")] },
        expectedIDs: ["I1", "I2", "P2"],
        expectedHistoryCount: 2
      ),
      WriteCase(
        name: "[P,R].history = [I2,P2]",
        entries: [prompt("P1"), response("R1")],
        mutation: { $0.history = [instructions("I2"), prompt("P2")] },
        expectedIDs: ["I2", "P2"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[P,I,R].history.removeFirst()",
        entries: [prompt("P1"), instructions("I1"), response("R1")],
        mutation: { $0.history.removeFirst() },
        expectedIDs: ["I1", "R1"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[I].history = [P]",
        entries: [instructions("I1")],
        mutation: { $0.history = [prompt("Px")] },
        expectedIDs: ["I1", "Px"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[I,P,I,R].history = []",
        entries: [instructions("I1"), prompt("P1"), instructions("I2"), response("R1")],
        mutation: { $0.history = [] },
        expectedIDs: ["I1"],
        expectedHistoryCount: 0
      ),
      WriteCase(
        name: "[I,I,P].history.removeFirst()",
        entries: [instructions("I1"), instructions("I2"), prompt("P1")],
        mutation: { $0.history.removeFirst() },
        expectedIDs: ["I1", "P1"],
        expectedHistoryCount: 1
      ),
      WriteCase(
        name: "[I,P,R,P,R].history = history.suffix(2)",
        entries: [instructions("I1"), prompt("P1"), response("R1"), prompt("P2"), response("R2")],
        mutation: { $0.history = $0.history.suffix(2) },
        expectedIDs: ["I1", "P2", "R2"],
        expectedHistoryCount: 2
      ),
    ]

    @Test(arguments: writeCases)
    func writesPreserveLeadingInstructions(_ writeCase: WriteCase) {
      var transcript = Transcript(entries: writeCase.entries)

      writeCase.mutation(&transcript)

      #expect(Self.ids(transcript) == writeCase.expectedIDs)
      #expect(transcript.history.count == writeCase.expectedHistoryCount)
    }

    // MARK: - Indices

    @Test
    func indicesCompareByOffsetAcrossViews() {
      let withInstructions = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"),
      ]).history
      let withoutInstructions = Transcript(entries: [Self.prompt("P1"), Self.response("R1")])
        .history

      let startsAreEqual = withInstructions.startIndex == withoutInstructions.startIndex
      let distance = withoutInstructions.startIndex.distance(to: withInstructions.startIndex)
      let distinctStarts = Set([withInstructions.startIndex, withoutInstructions.startIndex])

      #expect(!startsAreEqual)
      #expect(withoutInstructions.startIndex < withInstructions.startIndex)
      #expect(!(withInstructions.startIndex < withoutInstructions.startIndex))
      #expect(distance == 1)
      #expect(withInstructions.endIndex != withoutInstructions.endIndex)
      #expect(distinctStarts.count == 2)
    }

    @Test
    func indexArithmeticMatchesOffsets() {
      let history = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"),
      ]).history

      let advanced = history.startIndex.advanced(by: 1)
      let after = history.index(after: history.startIndex)
      let before = history.startIndex.advanced(by: -1)
      let offsetByTwo = history.index(history.startIndex, offsetBy: 2)

      #expect(Self.offset(advanced) == 2)
      #expect(advanced == after)
      #expect(Self.offset(before) == 0)
      #expect(history.startIndex.distance(to: history.endIndex) == 2)
      #expect(offsetByTwo == history.endIndex)
      #expect(history.indices.map(Self.offset) == [1, 2])
    }

    @Test
    func indexValidAfterInsertAddressesNewEntry() {
      var transcript = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"),
      ])
      let oldStart = transcript.history.startIndex

      transcript.history.insert(Self.prompt("P0"), at: transcript.history.startIndex)

      #expect(transcript.history[oldStart].id == "P0")
      #expect(transcript[1].id == "P0")
    }

    // MARK: - Slicing

    @Test
    func slicesShareIndicesWithTheirParent() {
      let history = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"), Self.prompt("P2"),
        Self.response("R2"),
      ]).history
      let second = history.index(after: history.startIndex)

      let slice: Transcript.HistoryView = history[second..<history.endIndex]

      #expect(Self.ids(slice) == ["R1", "P2", "R2"])
      #expect(slice.startIndex == second)
      #expect(slice[second].id == "R1")
      #expect(Self.offset(slice.endIndex) == 5)
      #expect(Self.offset(history.suffix(2).startIndex) == 3)
      #expect(Self.offset(history.dropFirst().startIndex) == 2)
      #expect(Self.ids(history.prefix(1)) == ["P1"])
    }

    @Test
    func rebuildingASliceStartsAtOffsetZero() {
      let history = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"), Self.prompt("P2"),
        Self.response("R2"),
      ]).history

      let rebuilt = Transcript.HistoryView(history.suffix(2))

      #expect(Self.ids(rebuilt) == ["P2", "R2"])
      #expect(Self.offset(rebuilt.startIndex) == 0)
      #expect(Self.offset(rebuilt.endIndex) == 2)
    }

    @Test
    func assigningThroughARangeSubscriptReplacesTheRange() {
      var history = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"), Self.prompt("P2"),
        Self.response("R2"),
      ]).history
      let second = history.index(after: history.startIndex)

      history[second..<history.endIndex] = [Self.response("Rx")]

      #expect(Self.ids(history) == ["P1", "Rx"])
      #expect(Self.offset(history.startIndex) == 1)
      #expect(Self.offset(history.endIndex) == 3)
    }

    @Test
    func appendingToASliceExtendsItsOffsets() {
      let history = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"), Self.prompt("P2"),
        Self.response("R2"),
      ]).history
      var slice = history[history.index(after: history.startIndex)..<history.endIndex]

      slice.append(Self.prompt("Pz"))

      #expect(Self.ids(slice) == ["R1", "P2", "R2", "Pz"])
      #expect(Self.offset(slice.startIndex) == 2)
      #expect(Self.offset(slice.endIndex) == 6)
    }

    @Test
    func removeAllResetsOffsetsUnlessKeepingCapacity() {
      let history = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"),
      ]).history
      var removedAll = history
      var removedKeepingCapacity = history
      var removedSubrange = history

      removedAll.removeAll()
      removedKeepingCapacity.removeAll(keepingCapacity: true)
      removedSubrange.removeSubrange(removedSubrange.startIndex..<removedSubrange.endIndex)

      #expect(removedAll.isEmpty)
      #expect(Self.offset(removedAll.startIndex) == 0)
      #expect(Self.offset(removedKeepingCapacity.startIndex) == 1)
      #expect(Self.offset(removedSubrange.startIndex) == 1)
    }

    // MARK: - Standalone values

    @Test
    func arrayLiteralKeepsEveryEntry() {
      let literal: Transcript.HistoryView = [Self.instructions("I2"), Self.prompt("P2")]

      var transcript = Transcript(entries: [Self.instructions("I1")])
      transcript.history = literal

      #expect(Self.ids(literal) == ["I2", "P2"])
      #expect(Self.offset(literal.startIndex) == 0)
      #expect(Self.ids(transcript) == ["I1", "I2", "P2"])
      #expect(transcript.history.count == 2)
    }

    @Test
    func emptyAndSequenceInitializers() {
      let empty = Transcript.HistoryView()
      let fromSequence = Transcript.HistoryView([Self.prompt("P1"), Self.response("R1")])
      var appended: Transcript.HistoryView = []

      appended.append(Self.prompt("Pa"))

      #expect(empty.isEmpty)
      #expect(empty.startIndex == empty.endIndex)
      #expect(Self.offset(empty.startIndex) == 0)
      #expect(Self.ids(fromSequence) == ["P1", "R1"])
      #expect(Self.ids(appended) == ["Pa"])
      #expect(Self.offset(appended.endIndex) == 1)
    }

    @Test
    func elementsEqualIgnoresIndices() {
      let withInstructions = Transcript(entries: [
        Self.instructions("I1"), Self.prompt("P1"), Self.response("R1"),
      ]).history
      let withoutInstructions = Transcript(entries: [Self.prompt("P1"), Self.response("R1")])
        .history

      let viewsMatch = withInstructions.elementsEqual(withoutInstructions)
      let arrayMatches = withInstructions.elementsEqual([Self.prompt("P1"), Self.response("R1")])

      #expect(viewsMatch)
      #expect(arrayMatches)
    }
  }
#endif  // compiler(>=6.4)
