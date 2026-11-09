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
  // MARK: - Internal API (for the session)
  //
  // `LanguageModelExecutorGenerationChannel` is a rendezvous channel of generation events,
  // backed by AsyncAlgorithms' `AsyncThrowingChannel`. Its public surface
  // matches Apple's: `init()`, `AsyncSequence` conformance, `AsyncIterator.next(isolation:)`,
  // and `send(_:)`. Everything else is internal and exists for `LanguageModelSession`.
  //
  // Semantics:
  //
  // - `send(_:)` suspends until a consumer takes the event (or the channel terminates). There
  //   is no buffer: a channel sent to before anyone iterates holds the sender suspended until
  //   `next()` is called. The session must therefore drain the channel itself for as long as
  //   the executor runs, whether or not a stream consumer keeps iterating.
  // - Cancelling a suspended sender makes `send(_:)` return without delivering the event.
  //   A sender in an already-cancelled task still delivers to a waiting consumer.
  // - Events from one sender are delivered in send order. Each event goes to exactly one
  //   `next()` call: iterators made from the same channel (or a copy of it) compete for events.
  // - Cancelling the task suspended in `next()` makes that call return `nil`. The channel stays
  //   open: a later `next()` receives later events.
  // - `next()` from an already-cancelled task still receives an event from a suspended sender.
  // - `send(_:)` after the channel terminated returns immediately; the event is dropped.
  //
  // Termination (`Termination`):
  //
  // - `finish()` ends the channel normally: suspended senders resume (their events are
  //   dropped), and `next()` returns `nil` from then on. The session calls this after the
  //   executor's `respond(to:model:streamingInto:)` returns, when no send is pending.
  // - `finish(throwing:)` ends the channel with an error: the next `next()` throws it, and
  //   later calls return `nil`.
  // - `cancel()` ends the channel like `finish()` but records `.cancelled`. The session calls
  //   this when the request is cancelled, so an uncooperative executor's later events are
  //   ignored.
  // - Only the first termination takes effect; later `finish`/`cancel` calls are ignored.
  //
  // Observing termination and activity:
  //
  // - `termination` returns the `Termination` (`.finished`, `.failed(_:)`, or `.cancelled`),
  //   or `nil` while the channel is open. `isTerminated` is `termination != nil`.
  // - `onTermination(_:)` registers a handler that runs once, synchronously, when the
  //   channel terminates (immediately if it already has). Handlers run outside the lock on
  //   the terminating thread.
  // - `pendingSendCount` and `pendingNextCount` are the number of `send(_:)` and `next()`
  //   calls in progress (suspended, or about to suspend).
  //
  // Inspecting events (every payload is reachable without public API):
  //
  // - `Event.kind`: `.response(Response)`, `.reasoning(Reasoning)`, `.toolCalls(ToolCalls)`, and
  //   (Swift 6.4.2 or later) `.data(DataEntry)`.
  //   `Event.entryID` is the entry ID of whichever kind it is.
  // - `Response.action.kind` (`Response.Action.Kind`): `.appendText(TextFragment)`,
  //   `.replaceTextSegment(TextSegmentReplacement)`,
  //   `.addAttachmentSegment(Transcript.AttachmentSegment)`, `.removeAttachmentSegment(id:)`,
  //   `.updateMetadata(Metadata)`, `.updateUsage(Usage)`.
  // - `Reasoning.action.kind` (`Reasoning.Action.Kind`): `.appendText(TextFragment)`,
  //   `.replaceTextSegment(TextSegmentReplacement)`, `.updateSignature(ReasoningSignature)`,
  //   `.updateMetadata(Metadata)`, `.updateUsage(Usage)`.
  // - `ToolCalls.action.kind` (`ToolCalls.Action.Kind`): `.toolCall(ToolCall)`,
  //   `.removeToolCall(id:)`, `.updateMetadata(Metadata)`, `.updateUsage(Usage)`.
  // - `ToolCall.action.kind` (`ToolCalls.ToolCall.Action.Kind`):
  //   `.appendArguments(ArgumentsFragment)`, `.updateMetadata(Metadata)`.
  // - `DataEntry.action.kind` (`DataEntry.Action.Kind`, Swift 6.4.2 or later): `.update(Update)`.
  // - Payload structs (`Metadata`, `TextFragment`, `TextSegmentReplacement`,
  //   `ReasoningSignature`, `ToolCall`, `ArgumentsFragment`) expose their stored properties
  //   publicly, as in Apple's module, and have internal memberwise initializers.

  import AsyncAlgorithms
  import Synchronization

  #if canImport(FoundationEssentials)
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  #if canImport(UniformTypeIdentifiers)
    #if compiler(>=6.4.2)
      public import UniformTypeIdentifiers
    #else
      import UniformTypeIdentifiers
    #endif
  #endif

  /// An asynchronous sequence of generation events produced by a language model executor.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModelExecutorGenerationChannel`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct LanguageModelExecutorGenerationChannel: AsyncSequence, Sendable {
    /// The shared rendezvous channel and termination state; every copy of the channel and every
    /// iterator made from it refer to the same storage.
    internal let storage: Storage

    /// Creates an empty generation channel.
    public init() {
      self.storage = Storage()
    }

    /// The type of element produced by the generation channel.
    public typealias Element = LanguageModelExecutorGenerationChannel.Event
  }

  extension LanguageModelExecutorGenerationChannel {
    /// An asynchronous iterator over the events in a generation channel.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.AsyncIterator`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/asynciterator)
    public struct AsyncIterator: AsyncIteratorProtocol {
      /// The type of element produced by the iterator.
      public typealias Element = LanguageModelExecutorGenerationChannel.Event

      /// The storage of the channel this iterator reads from.
      internal let storage: Storage
    }
  }

  extension LanguageModelExecutorGenerationChannel.AsyncIterator {
    /// Asynchronously advances to the next event in the sequence.
    ///
    /// - Parameter actor: The actor isolation context for the operation.
    /// - Returns: The next event, or `nil` if the channel has terminated.
    /// - Throws: An error if the channel terminated with an error.
    public mutating func next(
      isolation actor: isolated (any Actor)?
    ) async throws -> LanguageModelExecutorGenerationChannel.Event? {
      try await storage.next()
    }
  }

  extension LanguageModelExecutorGenerationChannel {
    /// Creates an asynchronous iterator over the events in the channel.
    ///
    /// - Returns: An iterator over the generation channel.
    public func makeAsyncIterator() -> LanguageModelExecutorGenerationChannel.AsyncIterator {
      AsyncIterator(storage: storage)
    }

    /// Sends an event into the channel, suspending until consumed or terminated.
    ///
    /// - Parameter event: The generation event to send.
    nonisolated(nonsending) public func send(
      _ event: LanguageModelExecutorGenerationChannel.Event
    ) async {
      await storage.send(event)
    }
  }

  // MARK: - Internal termination API

  extension LanguageModelExecutorGenerationChannel {
    /// How a channel terminated.
    internal enum Termination: Sendable {
      /// The producer finished normally.
      case finished

      /// The producer finished with an error, which the next `next()` call throws.
      case failed(any Error)

      /// The channel was cancelled.
      case cancelled
    }

    /// Ends the channel normally.
    ///
    /// Suspended senders resume without delivering their events, and `next()` returns `nil`
    /// from then on. Has no effect if the channel already terminated.
    internal func finish() {
      storage.terminate(.finished)
    }

    /// Ends the channel with an error.
    ///
    /// The next `next()` call throws `error`; later calls return `nil`. Has no effect if the
    /// channel already terminated.
    ///
    /// - Parameter error: The error to throw from `next()`.
    internal func finish(throwing error: any Error) {
      storage.terminate(.failed(error))
    }

    /// Cancels the channel.
    ///
    /// Behaves like ``finish()`` but records `.cancelled`. Has no effect if the channel already
    /// terminated.
    internal func cancel() {
      storage.terminate(.cancelled)
    }

    /// How the channel terminated, or `nil` while it's open.
    internal var termination: Termination? {
      storage.termination
    }

    /// Whether the channel has terminated (finished, failed, or cancelled).
    internal var isTerminated: Bool {
      storage.termination != nil
    }

    /// The number of `send(_:)` calls in progress (suspended, or about to suspend).
    internal var pendingSendCount: Int {
      storage.pendingSendCount
    }

    /// The number of `next()` calls in progress (suspended, or about to suspend).
    internal var pendingNextCount: Int {
      storage.pendingNextCount
    }

    /// Registers a handler that runs once when the channel terminates.
    ///
    /// If the channel already terminated, `handler` runs immediately on the calling thread.
    /// Otherwise it runs synchronously on the thread that terminates the channel, outside the
    /// channel's lock.
    ///
    /// - Parameter handler: The closure to call with the termination reason.
    internal func onTermination(_ handler: @escaping @Sendable (Termination) -> Void) {
      storage.onTermination(handler)
    }
  }

  // MARK: - Storage

  extension LanguageModelExecutorGenerationChannel {
    /// The rendezvous channel behind a generation channel, plus termination bookkeeping.
    internal final class Storage: Sendable {
      /// The bookkeeping guarded by the lock.
      private struct State {
        /// How the channel terminated, or `nil` while it's open.
        var termination: Termination?

        /// Handlers to call when the channel terminates.
        var terminationHandlers: [@Sendable (Termination) -> Void] = []

        /// The number of `send(_:)` calls in progress.
        var pendingSendCount = 0

        /// The number of `next()` calls in progress.
        var pendingNextCount = 0
      }

      /// The rendezvous channel that carries the events.
      private let channel = AsyncThrowingChannel<Event, any Error>()

      /// The guarded bookkeeping.
      private let state = Mutex(State())

      /// Creates open storage.
      init() {}

      /// Sends an event, suspending until a consumer takes it, the channel terminates, or the
      /// calling task is cancelled.
      ///
      /// - Parameter event: The event to deliver.
      nonisolated(nonsending) func send(_ event: Event) async {
        state.withLock { $0.pendingSendCount += 1 }
        defer { state.withLock { $0.pendingSendCount -= 1 } }
        await channel.send(event)
      }

      /// Returns the next event, suspending until one is sent or the channel terminates.
      ///
      /// Cancelling the calling task makes a suspended call return `nil` without terminating
      /// the channel. Runs on the caller's isolation.
      ///
      /// - Returns: The next event, or `nil` at the end of the sequence or on cancellation.
      /// - Throws: The error passed to `finish(throwing:)`, once.
      nonisolated(nonsending) func next() async throws -> Event? {
        state.withLock { $0.pendingNextCount += 1 }
        defer { state.withLock { $0.pendingNextCount -= 1 } }
        // `AsyncThrowingChannel.Iterator` holds no state besides the channel's storage, so a
        // fresh iterator per call behaves like one long-lived iterator.
        var iterator = channel.makeAsyncIterator()
        return try await iterator.next()
      }

      /// Terminates the channel, resuming suspended senders and consumers and running
      /// termination handlers.
      ///
      /// - Parameter termination: How the channel terminates.
      func terminate(_ termination: Termination) {
        let handlers = state.withLock { state -> [@Sendable (Termination) -> Void]? in
          guard state.termination == nil else { return nil }
          state.termination = termination
          defer { state.terminationHandlers.removeAll() }
          return state.terminationHandlers
        }
        guard let handlers else { return }
        switch termination {
        case .finished, .cancelled:
          channel.finish()
        case .failed(let error):
          channel.fail(error)
        }
        for handler in handlers {
          handler(termination)
        }
      }

      /// How the channel terminated, or `nil` while it's open.
      var termination: Termination? {
        state.withLock { $0.termination }
      }

      /// The number of `send(_:)` calls in progress.
      var pendingSendCount: Int {
        state.withLock { $0.pendingSendCount }
      }

      /// The number of `next()` calls in progress.
      var pendingNextCount: Int {
        state.withLock { $0.pendingNextCount }
      }

      /// Registers a termination handler, or calls it immediately if already terminated.
      ///
      /// - Parameter handler: The closure to call with the termination reason.
      func onTermination(_ handler: @escaping @Sendable (Termination) -> Void) {
        let termination = state.withLock { state -> Termination? in
          if let termination = state.termination {
            return termination
          }
          state.terminationHandlers.append(handler)
          return nil
        }
        if let termination {
          handler(termination)
        }
      }
    }
  }

  // MARK: - Events

  extension LanguageModelExecutorGenerationChannel {
    /// An event emitted into a generation channel.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Event`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/event)
    public struct Event: Sendable {
      /// The kind of entry an event targets, with its payload.
      internal enum Kind: Sendable {
        /// An event for a response entry.
        case response(LanguageModelExecutorGenerationChannel.Response)

        /// An event for a reasoning entry.
        case reasoning(LanguageModelExecutorGenerationChannel.Reasoning)

        /// An event for a tool-calls entry.
        case toolCalls(LanguageModelExecutorGenerationChannel.ToolCalls)

        #if compiler(>=6.4.2)
          /// An event for a data entry.
          case data(LanguageModelExecutorGenerationChannel.DataEntry)
        #endif  // compiler(>=6.4.2)
      }

      /// The kind of entry this event targets, with its payload.
      internal let kind: Kind

      /// The entry ID the event targets, whatever its kind; `nil` asks the session to
      /// coalesce or mint one.
      internal var entryID: String? {
        switch kind {
        case .response(let response): response.entryID
        case .reasoning(let reasoning): reasoning.entryID
        case .toolCalls(let toolCalls): toolCalls.entryID
        #if compiler(>=6.4.2)
          case .data(let dataEntry): dataEntry.entryID
        #endif  // compiler(>=6.4.2)
        }
      }
    }
  }

  extension LanguageModelExecutorGenerationChannel.Event {
    /// Creates a generation event targeting a model response entry.
    ///
    /// - Parameters:
    ///   - entryID: The identifier of the response entry, or `nil` to let the session assign one.
    ///   - action: The action to perform on the response entry.
    /// - Returns: A response generation event.
    public static func response(
      entryID: String? = nil,
      action: LanguageModelExecutorGenerationChannel.Response.Action
    ) -> LanguageModelExecutorGenerationChannel.Event {
      Self(kind: .response(.init(entryID: entryID, action: action)))
    }

    /// Creates a generation event targeting a reasoning entry.
    ///
    /// - Parameters:
    ///   - entryID: The identifier of the reasoning entry, or `nil` to let the session assign one.
    ///   - action: The action to perform on the reasoning entry.
    /// - Returns: A reasoning generation event.
    public static func reasoning(
      entryID: String? = nil,
      action: LanguageModelExecutorGenerationChannel.Reasoning.Action
    ) -> LanguageModelExecutorGenerationChannel.Event {
      Self(kind: .reasoning(.init(entryID: entryID, action: action)))
    }

    /// Creates a generation event targeting a tool-calls entry.
    ///
    /// - Parameters:
    ///   - entryID: The identifier of the tool-calls entry, or `nil` to let the session assign one.
    ///   - action: The action to perform on the tool-calls entry.
    /// - Returns: A tool-calls generation event.
    public static func toolCalls(
      entryID: String? = nil,
      action: LanguageModelExecutorGenerationChannel.ToolCalls.Action
    ) -> LanguageModelExecutorGenerationChannel.Event {
      Self(kind: .toolCalls(.init(entryID: entryID, action: action)))
    }

    #if compiler(>=6.4.2)
      /// Creates a generation event targeting a data entry.
      ///
      /// - Parameters:
      ///   - entryID: The identifier of the data entry, or `nil` to let the session assign one.
      ///   - action: The action to perform on the data entry.
      /// - Returns: A data generation event.
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      public static func data(
        entryID: String? = nil,
        action: LanguageModelExecutorGenerationChannel.DataEntry.Action
      ) -> LanguageModelExecutorGenerationChannel.Event {
        Self(kind: .data(.init(entryID: entryID, action: action)))
      }
    #endif  // compiler(>=6.4.2)
  }

  // MARK: - Payloads

  extension LanguageModelExecutorGenerationChannel {
    /// Metadata associated with a transcript entry or generation payload.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Metadata`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/metadata)
    public struct Metadata: Sendable {
      /// The metadata key-value mappings.
      public var values: [String: GeneratedContent]
    }

    /// Token usage metrics for a generation turn.
    public struct Usage: Sendable {
      /// The input token usage metrics.
      public var input: LanguageModelExecutorGenerationChannel.Usage.Input

      /// The output token usage metrics.
      public var output: LanguageModelExecutorGenerationChannel.Usage.Output

      /// Additional metadata describing token usage.
      public var metadata: [String: GeneratedContent]

      /// Creates a usage payload with the given input and output counts and optional metadata.
      ///
      /// - Parameters:
      ///   - input: The input token usage counts.
      ///   - output: The output token usage counts.
      ///   - metadata: Additional metadata associated with token usage.
      public init(
        input: LanguageModelExecutorGenerationChannel.Usage.Input,
        output: LanguageModelExecutorGenerationChannel.Usage.Output,
        metadata: [String: any ConvertibleToGeneratedContent] = [:]
      ) {
        self.input = input
        self.output = output
        self.metadata = metadata.mapValues(\.generatedContent)
      }
    }

    /// A fragment of text appended during streaming generation.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.TextFragment`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/textfragment)
    public struct TextFragment: Sendable {
      /// The text content of the fragment.
      public var content: String

      /// The identifier of the segment being appended to, or `nil` for default placement.
      public var segmentID: String?

      /// The number of tokens in this text fragment.
      public var tokenCount: Int
    }

    /// Replacement text for an existing text segment.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.TextSegmentReplacement`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/textsegmentreplacement)
    public struct TextSegmentReplacement: Sendable {
      /// The replacement text content.
      public var content: String

      /// The identifier of the segment being replaced, or `nil` for default placement.
      public var segmentID: String?

      /// The number of tokens in the replacement text.
      public var tokenCount: Int
    }

    /// A generation payload targeting a model response entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Response`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/response)
    public struct Response: Sendable {
      /// The identifier of the response entry, or `nil` to let the session assign one.
      public var entryID: String?

      /// The action to perform on the response entry.
      public var action: LanguageModelExecutorGenerationChannel.Response.Action
    }

    /// A generation payload targeting a reasoning entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Reasoning`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/reasoning)
    public struct Reasoning: Sendable {
      /// The identifier of the reasoning entry, or `nil` to let the session assign one.
      public var entryID: String?

      /// The action to perform on the reasoning entry.
      public var action: LanguageModelExecutorGenerationChannel.Reasoning.Action
    }

    /// A cryptographic or opaque signature representing a model's reasoning trace.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.ReasoningSignature`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/reasoningsignature)
    public struct ReasoningSignature: Sendable {
      /// The signature byte data.
      public var signature: Data

      /// The number of tokens consumed by the reasoning signature.
      public var tokenCount: Int
    }

    /// A generation payload targeting a tool-calls entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.ToolCalls`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/toolcalls)
    public struct ToolCalls: Sendable {
      /// The identifier of the tool-calls entry, or `nil` to let the session assign one.
      public var entryID: String?

      /// The action to perform on the tool-calls entry.
      public var action: LanguageModelExecutorGenerationChannel.ToolCalls.Action
    }

    #if compiler(>=6.4.2)
      /// A generation payload targeting a binary data entry.
      ///
      /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.DataEntry`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/dataentry)
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      public struct DataEntry: Sendable {
        /// The identifier of the data entry, or `nil` to let the session assign one.
        public var entryID: String?

        /// The action to perform on the data entry.
        public var action: LanguageModelExecutorGenerationChannel.DataEntry.Action
      }
    #endif  // compiler(>=6.4.2)
  }

  extension LanguageModelExecutorGenerationChannel.Usage {
    /// Input token usage metrics.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Usage.Input`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/usage/input)
    public struct Input: Sendable {
      /// The total number of input tokens processed.
      public var totalTokenCount: Int

      /// The number of input tokens served from cache.
      public var cachedTokenCount: Int

      /// Creates an input token usage record.
      ///
      /// - Parameters:
      ///   - totalTokenCount: The total number of input tokens.
      ///   - cachedTokenCount: The number of cached input tokens.
      public init(totalTokenCount: Int, cachedTokenCount: Int) {
        self.totalTokenCount = totalTokenCount
        self.cachedTokenCount = cachedTokenCount
      }
    }

    /// Output token usage metrics.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Usage.Output`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/usage/output)
    public struct Output: Sendable {
      /// The total number of output tokens produced.
      public var totalTokenCount: Int

      /// The number of output tokens generated for reasoning.
      public var reasoningTokenCount: Int

      /// Creates an output token usage record.
      ///
      /// - Parameters:
      ///   - totalTokenCount: The total number of output tokens.
      ///   - reasoningTokenCount: The number of reasoning tokens generated.
      public init(totalTokenCount: Int, reasoningTokenCount: Int) {
        self.totalTokenCount = totalTokenCount
        self.reasoningTokenCount = reasoningTokenCount
      }
    }
  }

  // MARK: - Actions

  extension LanguageModelExecutorGenerationChannel.Response {
    /// An action to perform on a response entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Response.Action`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/response/action)
    public struct Action: Sendable {
      /// The operation, with its payload.
      internal enum Kind: Sendable {
        /// Appends text to a text segment.
        case appendText(LanguageModelExecutorGenerationChannel.TextFragment)

        /// Replaces the content of a text segment.
        case replaceTextSegment(LanguageModelExecutorGenerationChannel.TextSegmentReplacement)

        /// Appends an attachment segment.
        case addAttachmentSegment(Transcript.AttachmentSegment)

        /// Removes every attachment segment with the given ID.
        case removeAttachmentSegment(id: String)

        /// Replaces the entry's metadata.
        case updateMetadata(LanguageModelExecutorGenerationChannel.Metadata)

        /// Replaces the turn's usage totals.
        case updateUsage(LanguageModelExecutorGenerationChannel.Usage)
      }

      /// The operation, with its payload.
      internal let kind: Kind
    }
  }

  extension LanguageModelExecutorGenerationChannel.Reasoning {
    /// An action to perform on a reasoning entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.Reasoning.Action`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/reasoning/action)
    public struct Action: Sendable {
      /// The operation, with its payload.
      internal enum Kind: Sendable {
        /// Appends text to the reasoning text segment.
        case appendText(LanguageModelExecutorGenerationChannel.TextFragment)

        /// Replaces the reasoning text segment.
        case replaceTextSegment(LanguageModelExecutorGenerationChannel.TextSegmentReplacement)

        /// Replaces the entry's signature.
        case updateSignature(LanguageModelExecutorGenerationChannel.ReasoningSignature)

        /// Replaces the entry's metadata.
        case updateMetadata(LanguageModelExecutorGenerationChannel.Metadata)

        /// Replaces the turn's usage totals.
        case updateUsage(LanguageModelExecutorGenerationChannel.Usage)
      }

      /// The operation, with its payload.
      internal let kind: Kind
    }
  }

  extension LanguageModelExecutorGenerationChannel.ToolCalls {
    /// An action to perform on a tool-calls entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.ToolCalls.Action`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/toolcalls/action)
    public struct Action: Sendable {
      /// The operation, with its payload.
      internal enum Kind: Sendable {
        /// Performs an operation on one tool call in the entry.
        case toolCall(LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall)

        /// Removes the tool call with the given ID.
        case removeToolCall(id: String)

        /// Replaces the entry's metadata. The session drops this, because `Transcript.ToolCalls`
        /// has no metadata.
        case updateMetadata(LanguageModelExecutorGenerationChannel.Metadata)

        /// Replaces the turn's usage totals.
        case updateUsage(LanguageModelExecutorGenerationChannel.Usage)
      }

      /// The operation, with its payload.
      internal let kind: Kind
    }

    /// An individual tool call within a tool-calls entry.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/toolcalls/toolcall)
    public struct ToolCall: Sendable {
      /// The unique identifier of the tool call.
      public var id: String

      /// The name of the tool being called.
      public var name: String

      /// The action to perform on this tool call.
      public var action: LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action
    }
  }

  extension LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall {
    /// An action to perform on an individual tool call.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/toolcalls/toolcall/action)
    public struct Action: Sendable {
      /// The operation, with its payload.
      internal enum Kind: Sendable {
        /// Appends argument text, creating the call on first use.
        case appendArguments(ArgumentsFragment)

        /// Replaces the tool call's metadata.
        case updateMetadata(LanguageModelExecutorGenerationChannel.Metadata)
      }

      /// The operation, with its payload.
      internal let kind: Kind
    }

    /// A fragment of serialized tool call arguments to append.
    ///
    /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.ArgumentsFragment`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/toolcalls/toolcall/argumentsfragment)
    public struct ArgumentsFragment: Sendable {
      /// The argument string fragment.
      public var content: String

      /// The number of tokens in this arguments fragment.
      public var tokenCount: Int
    }
  }

  #if compiler(>=6.4.2)
    extension LanguageModelExecutorGenerationChannel.DataEntry {
      /// An action to perform on a data entry.
      ///
      /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.DataEntry.Action`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/dataentry/action)
      public struct Action: Sendable {
        /// The operation, with its payload.
        internal enum Kind: Sendable {
          /// Creates or replaces a data entry's content type, binary content, and metadata.
          case update(Update)
        }

        /// The operation, with its payload.
        internal let kind: Kind
      }

      /// A payload containing updated content and metadata for a data entry.
      ///
      /// - SeeAlso: [`LanguageModelExecutorGenerationChannel.DataEntry.Update`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationchannel/dataentry/update)
      public struct Update: Sendable {
        /// The uniform type identifier describing the data content.
        public var contentType: UTType

        /// The raw binary content of the data entry.
        public var content: Data

        /// Structured metadata associated with the data entry.
        public var metadata: GeneratedContent

        /// Creates a data entry update payload.
        ///
        /// - Parameters:
        ///   - contentType: The uniform type identifier describing `content`.
        ///   - content: The raw binary payload.
        ///   - metadata: Structured metadata associated with the data entry.
        internal init(
          contentType: UTType,
          content: Data,
          metadata: GeneratedContent = GeneratedContent(properties: [:])
        ) {
          self.contentType = contentType
          self.content = content
          self.metadata = metadata
        }
      }
    }
  #endif  // compiler(>=6.4.2)
#endif  // compiler(>=6.4)
