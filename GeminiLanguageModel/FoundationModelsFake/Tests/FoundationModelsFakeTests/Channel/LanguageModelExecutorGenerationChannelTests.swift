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

  /// Tests for `LanguageModelExecutorGenerationChannel`'s rendezvous delivery, ordering,
  /// termination, cancellation, and event inspection.
  ///
  /// The expected semantics are described in the file header of
  /// `LanguageModelExecutorGenerationChannel.swift`.
  struct LanguageModelExecutorGenerationChannelTests {
    /// The channel under test.
    typealias Channel = LanguageModelExecutorGenerationChannel

    /// An error thrown into channels by these tests.
    struct ChannelTestError: Error, Equatable {
      /// A message identifying the error.
      var message: String
    }

    // MARK: - Helpers

    /// A response event appending `text` with a token count of 1.
    static func text(_ text: String) -> Channel.Event {
      .response(action: .appendText(text, tokenCount: 1))
    }

    /// The appended text of a response `appendText` event, or `nil` for any other event.
    static func appendedText(_ event: Channel.Event?) -> String? {
      guard case .response(let response) = event?.kind,
        case .appendText(let fragment) = response.action.kind
      else { return nil }
      return fragment.content
    }

    /// Iterates `channel` until it ends, returning the appended texts.
    static func collectTexts(_ channel: Channel) async throws -> [String] {
      var texts: [String] = []
      for try await event in channel {
        texts.append(appendedText(event) ?? "<other>")
      }
      return texts
    }

    /// Starts a task that sends `texts` in order and then finishes the channel.
    @discardableResult
    static func produce(_ texts: [String], into channel: Channel, finish: Bool = true) -> Task<
      Void, Never
    > {
      Task {
        for text in texts {
          await channel.send(Self.text(text))
        }
        if finish {
          channel.finish()
        }
      }
    }

    /// Polls until `condition` holds, failing with its own issue after about two seconds.
    static func waitUntil(
      sourceLocation: SourceLocation = #_sourceLocation,
      _ condition: () -> Bool
    ) async throws {
      for _ in 0..<2000 where !condition() {
        try await Task.sleep(for: .milliseconds(1))
      }
      try #require(
        condition(), "Timed out waiting for the condition", sourceLocation: sourceLocation)
    }

    // MARK: - Rendezvous delivery and ordering

    @Test
    func sendSuspendsUntilAConsumerTakesTheEvent() async throws {
      let channel = Channel()
      let delivered = Mutex(false)
      let sender = Task {
        await channel.send(Self.text("a"))
        delivered.withLock { $0 = true }
      }
      try await Self.waitUntil { channel.pendingSendCount == 1 }
      try await Task.sleep(for: .milliseconds(50))
      let deliveredBeforeConsuming = delivered.withLock { $0 }

      var iterator = channel.makeAsyncIterator()
      let event = try await iterator.next()
      await sender.value

      #expect(!deliveredBeforeConsuming)
      #expect(channel.pendingSendCount == 0)
      #expect(Self.appendedText(event) == "a")
      #expect(delivered.withLock { $0 })
    }

    @Test
    func sendIsHandedToASuspendedConsumer() async throws {
      let channel = Channel()
      let consumer = Task {
        var iterator = channel.makeAsyncIterator()
        return Self.appendedText(try await iterator.next())
      }
      try await Self.waitUntil { channel.pendingNextCount == 1 }

      await channel.send(Self.text("handoff"))

      #expect(try await consumer.value == "handoff")
      #expect(channel.pendingNextCount == 0)
    }

    @Test
    func eventsFromOneSenderArriveInOrder() async throws {
      let channel = Channel()
      let texts = (0..<2000).map(String.init)
      Self.produce(texts, into: channel)

      let received = try await Self.collectTexts(channel)

      #expect(received == texts)
    }

    @Test
    func copiesOfTheChannelShareOneRendezvous() async throws {
      let channel = Channel()
      let copy = channel
      Self.produce(["via copy"], into: copy)

      let received = try await Self.collectTexts(channel)

      #expect(received == ["via copy"])
    }

    @Test
    func iteratorsCompeteForEvents() async throws {
      let channel = Channel()
      Self.produce(["a", "b"], into: channel, finish: false)
      var first = channel.makeAsyncIterator()
      var second = channel.makeAsyncIterator()

      let fromFirst = Self.appendedText(try await first.next())
      let fromSecond = Self.appendedText(try await second.next())

      #expect(fromFirst == "a")
      #expect(fromSecond == "b")
    }

    @Test
    func concurrentProducersKeepTheirOwnOrder() async throws {
      let channel = Channel()
      let producerCount = 8
      let eventsPerProducer = 100
      Task {
        await withTaskGroup(of: Void.self) { group in
          for producer in 0..<producerCount {
            group.addTask {
              for index in 0..<eventsPerProducer {
                await channel.send(Self.text("\(producer):\(index)"))
              }
            }
          }
        }
        channel.finish()
      }

      let texts = try await Self.collectTexts(channel)

      #expect(texts.count == producerCount * eventsPerProducer)
      for producer in 0..<producerCount {
        let indices = texts.filter { $0.hasPrefix("\(producer):") }
          .compactMap { Int($0.split(separator: ":")[1]) }
        #expect(indices == Array(0..<eventsPerProducer))
      }
    }

    @Test
    @MainActor
    func iterationWorksOnAnActor() async throws {
      let channel = Channel()
      Self.produce(["main"], into: channel)
      var texts: [String] = []

      for try await event in channel {
        MainActor.assertIsolated()
        texts.append(Self.appendedText(event) ?? "")
      }

      #expect(texts == ["main"])
    }

    // MARK: - Finishing

    @Test
    func finishEndsIteration() async throws {
      let channel = Channel()
      channel.finish()
      var iterator = channel.makeAsyncIterator()

      let first = try await iterator.next()
      let second = try await iterator.next()

      #expect(first == nil)
      #expect(second == nil)
    }

    @Test
    func finishResumesASuspendedConsumerWithNil() async throws {
      let channel = Channel()
      let consumer = Task {
        var iterator = channel.makeAsyncIterator()
        return try await iterator.next() == nil
      }
      try await Self.waitUntil { channel.pendingNextCount == 1 }

      channel.finish()

      #expect(try await consumer.value)
    }

    @Test
    func finishResumesASuspendedSenderAndDropsItsEvent() async throws {
      let channel = Channel()
      let sender = Self.produce(["dropped"], into: channel, finish: false)
      try await Self.waitUntil { channel.pendingSendCount == 1 }

      channel.finish()
      await sender.value

      #expect(try await Self.collectTexts(channel).isEmpty)
    }

    @Test
    func sendAfterFinishReturnsImmediately() async throws {
      let channel = Channel()
      channel.finish()

      await channel.send(Self.text("dropped"))

      #expect(channel.pendingSendCount == 0)
      #expect(try await Self.collectTexts(channel).isEmpty)
    }

    @Test
    func finishThrowingThrowsOnceThenEnds() async throws {
      let channel = Channel()
      channel.finish(throwing: ChannelTestError(message: "boom"))
      var iterator = channel.makeAsyncIterator()

      let thrown: (any Error)?
      do {
        _ = try await iterator.next()
        thrown = nil
      } catch {
        thrown = error
      }
      let afterError = try await iterator.next()

      #expect(thrown as? ChannelTestError == ChannelTestError(message: "boom"))
      #expect(afterError == nil)
    }

    @Test
    func finishThrowingResumesASuspendedConsumerWithTheError() async throws {
      let channel = Channel()
      let consumer = Task {
        var iterator = channel.makeAsyncIterator()
        return try await iterator.next()
      }
      try await Self.waitUntil { channel.pendingNextCount == 1 }

      channel.finish(throwing: ChannelTestError(message: "boom"))

      await #expect(throws: ChannelTestError(message: "boom")) {
        try await consumer.value
      }
    }

    // MARK: - Cancellation

    @Test
    func cancelResumesSuspendedConsumersWithNil() async throws {
      let channel = Channel()
      let consumers = (0..<3).map { _ in
        Task {
          var iterator = channel.makeAsyncIterator()
          return try await iterator.next() == nil
        }
      }
      try await Self.waitUntil { channel.pendingNextCount == 3 }

      channel.cancel()
      await channel.send(Self.text("dropped"))

      for consumer in consumers {
        #expect(try await consumer.value)
      }
      #expect(channel.isTerminated)
    }

    @Test
    func cancellingAConsumerTaskReturnsNilAndKeepsTheChannelOpen() async throws {
      let channel = Channel()
      let consumer = Task {
        var iterator = channel.makeAsyncIterator()
        return try await iterator.next() == nil
      }
      try await Self.waitUntil { channel.pendingNextCount == 1 }

      consumer.cancel()

      #expect(try await consumer.value)
      #expect(channel.termination == nil)
      Self.produce(["after cancel"], into: channel, finish: false)
      var iterator = channel.makeAsyncIterator()
      #expect(Self.appendedText(try await iterator.next()) == "after cancel")
    }

    @Test
    func cancellingASuspendedSenderDropsItsEvent() async throws {
      let channel = Channel()
      let sender = Self.produce(["dropped"], into: channel, finish: false)
      try await Self.waitUntil { channel.pendingSendCount == 1 }

      sender.cancel()
      await sender.value
      Self.produce(["kept"], into: channel)

      #expect(try await Self.collectTexts(channel) == ["kept"])
    }

    @Test
    func nextFromACancelledTaskReceivesFromASuspendedSender() async throws {
      let channel = Channel()
      Self.produce(["pending"], into: channel, finish: false)
      try await Self.waitUntil { channel.pendingSendCount == 1 }

      let received = await Task {
        unsafe withUnsafeCurrentTask { unsafe $0?.cancel() }
        var iterator = channel.makeAsyncIterator()
        return Self.appendedText(try? await iterator.next())
      }.value

      #expect(received == "pending")
      #expect(channel.termination == nil)
    }

    // MARK: - Termination observation

    @Test
    func terminationReportsHowTheChannelEnded() {
      let finished = Channel()
      let failed = Channel()
      let cancelled = Channel()
      let open = Channel()

      finished.finish()
      failed.finish(throwing: ChannelTestError(message: "x"))
      cancelled.cancel()

      #expect(finished.termination?.description == "finished")
      #expect(failed.termination?.description == "failed(ChannelTestError(message: \"x\"))")
      #expect(cancelled.termination?.description == "cancelled")
      #expect(open.termination == nil)
      #expect(!open.isTerminated)
      #expect(finished.isTerminated)
    }

    @Test
    func onlyTheFirstTerminationTakesEffect() async throws {
      let channel = Channel()

      channel.finish()
      channel.cancel()
      channel.finish(throwing: ChannelTestError(message: "ignored"))

      #expect(channel.termination?.description == "finished")
      #expect(try await Self.collectTexts(channel).isEmpty)
    }

    @Test
    func onTerminationRunsOnceWhenTheChannelTerminates() {
      let channel = Channel()
      let calls = Mutex<[String]>([])
      channel.onTermination { termination in
        calls.withLock { $0.append("first: \(termination)") }
      }
      channel.onTermination { _ in
        calls.withLock { $0.append("second") }
      }

      channel.cancel()
      channel.finish()

      #expect(calls.withLock { $0 } == ["first: cancelled", "second"])
    }

    @Test
    func onTerminationAfterTerminationRunsImmediately() {
      let channel = Channel()
      channel.finish()
      let calls = Mutex<[String]>([])

      channel.onTermination { termination in
        calls.withLock { $0.append("\(termination)") }
      }

      #expect(calls.withLock { $0 } == ["finished"])
    }

    // MARK: - Event inspection

    @Test
    func responseActionsExposeTheirPayloads() throws {
      let segment = Transcript.AttachmentSegment(
        id: "img-1",
        content: .image(Transcript.ImageAttachment(imageURL: URL(fileURLWithPath: "/tmp/a.png"))),
        label: "diagram"
      )

      let events: [Channel.Event] = [
        .response(entryID: "r", action: .appendText("hi", segmentID: "s1", tokenCount: 2)),
        .response(action: .replaceTextSegment("bye", tokenCount: 3)),
        .response(action: .addAttachmentSegment(segment)),
        .response(action: .removeAttachmentSegment(id: "img-1")),
        .response(action: .updateMetadata(["model": "m"])),
        .response(
          action: .updateUsage(
            input: .init(totalTokenCount: 10, cachedTokenCount: 4),
            output: .init(totalTokenCount: 5, reasoningTokenCount: 1),
            metadata: ["k": 1]
          )
        ),
      ]

      let actions = try events.map { event -> Channel.Response.Action.Kind in
        guard case .response(let response) = event.kind else {
          throw ChannelTestError(message: "not a response event")
        }
        return response.action.kind
      }
      #expect(events.map(\.entryID) == ["r", nil, nil, nil, nil, nil])
      guard case .appendText(let fragment) = actions[0] else {
        Issue.record("Expected appendText")
        return
      }
      #expect(fragment.content == "hi")
      #expect(fragment.segmentID == "s1")
      #expect(fragment.tokenCount == 2)
      guard case .replaceTextSegment(let replacement) = actions[1] else {
        Issue.record("Expected replaceTextSegment")
        return
      }
      #expect(replacement.content == "bye")
      #expect(replacement.segmentID == nil)
      #expect(replacement.tokenCount == 3)
      guard case .addAttachmentSegment(let added) = actions[2] else {
        Issue.record("Expected addAttachmentSegment")
        return
      }
      #expect(added == segment)
      guard case .removeAttachmentSegment(let removedID) = actions[3] else {
        Issue.record("Expected removeAttachmentSegment")
        return
      }
      #expect(removedID == "img-1")
      guard case .updateMetadata(let metadata) = actions[4] else {
        Issue.record("Expected updateMetadata")
        return
      }
      #expect(Array(metadata.values.keys) == ["model"])
      guard case .updateUsage(let usage) = actions[5] else {
        Issue.record("Expected updateUsage")
        return
      }
      #expect(usage.input.totalTokenCount == 10)
      #expect(usage.input.cachedTokenCount == 4)
      #expect(usage.output.totalTokenCount == 5)
      #expect(usage.output.reasoningTokenCount == 1)
      #expect(Array(usage.metadata.keys) == ["k"])
    }

    @Test
    func reasoningActionsExposeTheirPayloads() throws {
      let events: [Channel.Event] = [
        .reasoning(entryID: "e", action: .appendText("think", segmentID: "rs", tokenCount: 4)),
        .reasoning(action: .replaceTextSegment("rethink", segmentID: "rs2", tokenCount: 5)),
        .reasoning(action: .updateSignature(Data([1, 2, 3]), tokenCount: 6)),
        .reasoning(action: .updateMetadata(["a": true])),
        .reasoning(
          action: .updateUsage(
            input: .init(totalTokenCount: 1, cachedTokenCount: 0),
            output: .init(totalTokenCount: 2, reasoningTokenCount: 2)
          )
        ),
      ]

      let actions = try events.map { event -> Channel.Reasoning.Action.Kind in
        guard case .reasoning(let reasoning) = event.kind else {
          throw ChannelTestError(message: "not a reasoning event")
        }
        return reasoning.action.kind
      }
      #expect(events.map(\.entryID) == ["e", nil, nil, nil, nil])
      guard case .appendText(let fragment) = actions[0] else {
        Issue.record("Expected appendText")
        return
      }
      #expect(fragment.content == "think")
      #expect(fragment.segmentID == "rs")
      #expect(fragment.tokenCount == 4)
      guard case .replaceTextSegment(let replacement) = actions[1] else {
        Issue.record("Expected replaceTextSegment")
        return
      }
      #expect(replacement.content == "rethink")
      #expect(replacement.segmentID == "rs2")
      #expect(replacement.tokenCount == 5)
      guard case .updateSignature(let signature) = actions[2] else {
        Issue.record("Expected updateSignature")
        return
      }
      #expect(signature.signature == Data([1, 2, 3]))
      #expect(signature.tokenCount == 6)
      guard case .updateMetadata(let metadata) = actions[3] else {
        Issue.record("Expected updateMetadata")
        return
      }
      #expect(Array(metadata.values.keys) == ["a"])
      guard case .updateUsage(let usage) = actions[4] else {
        Issue.record("Expected updateUsage")
        return
      }
      #expect(usage.output.reasoningTokenCount == 2)
      #expect(usage.metadata.isEmpty)
    }

    @Test
    func toolCallsActionsExposeTheirPayloads() throws {
      let events: [Channel.Event] = [
        .toolCalls(
          entryID: "tc",
          action: .toolCall(
            id: "call-1",
            name: "getWeather",
            action: .appendArguments("{\"city\":", tokenCount: 3)
          )
        ),
        .toolCalls(
          action: .toolCall(id: "call-1", name: "getWeather", action: .updateMetadata(["m": 1]))
        ),
        .toolCalls(action: .removeToolCall(id: "call-1")),
        .toolCalls(action: .updateMetadata(["dropped": "yes"])),
        .toolCalls(
          action: .updateUsage(
            input: .init(totalTokenCount: 7, cachedTokenCount: 1),
            output: .init(totalTokenCount: 3, reasoningTokenCount: 0)
          )
        ),
      ]

      let actions = try events.map { event -> Channel.ToolCalls.Action.Kind in
        guard case .toolCalls(let toolCalls) = event.kind else {
          throw ChannelTestError(message: "not a toolCalls event")
        }
        return toolCalls.action.kind
      }
      #expect(events.map(\.entryID) == ["tc", nil, nil, nil, nil])
      guard case .toolCall(let call) = actions[0],
        case .appendArguments(let fragment) = call.action.kind
      else {
        Issue.record("Expected toolCall/appendArguments")
        return
      }
      #expect(call.id == "call-1")
      #expect(call.name == "getWeather")
      #expect(fragment.content == "{\"city\":")
      #expect(fragment.tokenCount == 3)
      guard case .toolCall(let metadataCall) = actions[1],
        case .updateMetadata(let callMetadata) = metadataCall.action.kind
      else {
        Issue.record("Expected toolCall/updateMetadata")
        return
      }
      #expect(Array(callMetadata.values.keys) == ["m"])
      guard case .removeToolCall(let removedID) = actions[2] else {
        Issue.record("Expected removeToolCall")
        return
      }
      #expect(removedID == "call-1")
      guard case .updateMetadata(let metadata) = actions[3] else {
        Issue.record("Expected updateMetadata")
        return
      }
      #expect(Array(metadata.values.keys) == ["dropped"])
      guard case .updateUsage(let usage) = actions[4] else {
        Issue.record("Expected updateUsage")
        return
      }
      #expect(usage.input.totalTokenCount == 7)
      #expect(usage.input.cachedTokenCount == 1)
    }

    @Test
    func publicPayloadStructsAreMutable() {
      var usage = Channel.Usage(
        input: .init(totalTokenCount: 1, cachedTokenCount: 0),
        output: .init(totalTokenCount: 2, reasoningTokenCount: 0)
      )

      usage.input.totalTokenCount = 9
      usage.output.reasoningTokenCount = 1

      #expect(usage.input.totalTokenCount == 9)
      #expect(usage.output.reasoningTokenCount == 1)
      #expect(usage.metadata.isEmpty)
    }
  }

  extension LanguageModelExecutorGenerationChannel.Termination: CustomStringConvertible {
    /// A short name for the termination reason, for test messages.
    var description: String {
      switch self {
      case .finished: "finished"
      case .failed(let error): "failed(\(error))"
      case .cancelled: "cancelled"
      }
    }
  }
#endif  // compiler(>=6.4)
