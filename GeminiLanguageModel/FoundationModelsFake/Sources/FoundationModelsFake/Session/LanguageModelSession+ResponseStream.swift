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

  extension LanguageModelSession {
    /// An asynchronous sequence of partial response snapshots produced during model generation.
    ///
    /// - SeeAlso: [`LanguageModelSession.ResponseStream`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/responsestream)
    public struct ResponseStream<Content> where Content: Generable {
      /// The backing storage for this response stream.
      internal let controller: StreamController<Content>

      /// The token whose release, once every copy of this stream and its iterators is gone, cancels
      /// generation that is still running (see `StreamConsumerToken`).
      internal let consumerToken: StreamConsumerToken<Content>

      /// Creates a response stream backed by a live stream controller.
      ///
      /// - Parameter controller: The stream controller driving generation.
      internal init(controller: StreamController<Content>) {
        self.controller = controller
        self.consumerToken = StreamConsumerToken(controller: controller)
      }

      /// Creates a pre-resolved response stream that yields a single snapshot and returns `response`
      /// from `collect()`.
      ///
      /// - Parameters:
      ///   - response: The resolved response.
      ///   - snapshotContent: The partial content for the single snapshot.
      internal init(
        resolved response: LanguageModelSession.Response<Content>,
        snapshotContent: Content.PartiallyGenerated
      ) {
        let controller = StreamController<Content>()
        let snapshot = Snapshot(
          content: snapshotContent,
          rawContent: response.rawContent,
          transcriptEntries: response.transcriptEntries,
          usage: response.usage
        )
        controller.complete(finalSnapshot: snapshot, result: .success(response))
        self.controller = controller
        self.consumerToken = StreamConsumerToken(controller: controller)
      }

      /// Creates a response stream that fails immediately with `error`.
      ///
      /// - Parameter error: The error to throw on iteration and `collect()`.
      internal init(throwing error: any Swift.Error) {
        let controller = StreamController<Content>()
        controller.fail(with: error)
        self.controller = controller
        self.consumerToken = StreamConsumerToken(controller: controller)
      }
    }
  }

  extension LanguageModelSession.ResponseStream {
    /// An intermediate snapshot of content and metadata emitted by a response stream.
    ///
    /// - SeeAlso: [`LanguageModelSession.ResponseStream.Snapshot`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/responsestream/snapshot)
    public struct Snapshot {
      /// The partially generated content received up to this snapshot.
      public var content: Content.PartiallyGenerated

      /// The raw generated content received up to this snapshot.
      public var rawContent: GeneratedContent

      /// The slice of transcript entries recorded during this response stream.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var transcriptEntries: ArraySlice<Transcript.Entry>

      /// The token usage accumulated up to this snapshot.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var usage: LanguageModelSession.Usage
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelSession.ResponseStream: AsyncSequence {
    /// The type of snapshot yielded by the response stream.
    public typealias Element = LanguageModelSession.ResponseStream<Content>.Snapshot

    /// Creates an asynchronous iterator over the response snapshots.
    ///
    /// - Returns: An iterator that yields successive snapshots as they arrive.
    public func makeAsyncIterator() -> LanguageModelSession.ResponseStream<Content>.AsyncIterator {
      AsyncIterator(controller: controller, consumerToken: consumerToken)
    }

    /// Awaits the completion of the stream and returns the final response.
    ///
    /// - Returns: The fully formed response.
    /// - Throws: An error if generation failed or was cancelled.
    nonisolated(nonsending) public func collect() async throws
      -> sending LanguageModelSession.Response<Content>
    {
      try await controller.collect()
    }
  }

  extension LanguageModelSession.ResponseStream {
    /// An asynchronous iterator that yields partial snapshots from a response stream.
    ///
    /// - SeeAlso: [`LanguageModelSession.ResponseStream.AsyncIterator`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/responsestream/asynciterator)
    public struct AsyncIterator: AsyncIteratorProtocol {
      /// The type of snapshot yielded by the iterator.
      public typealias Element = LanguageModelSession.ResponseStream<Content>.Snapshot

      /// The stream controller driving this iterator.
      internal let controller: LanguageModelSession.StreamController<Content>

      /// The underlying snapshot stream iterator.
      internal var iterator: AsyncThrowingStream<Element, any Swift.Error>.AsyncIterator

      /// The stream's consumer token, which keeps generation running while this iterator exists.
      internal let consumerToken: LanguageModelSession.StreamConsumerToken<Content>

      /// Creates an iterator backed by `controller`.
      ///
      /// - Parameters:
      ///   - controller: The stream controller.
      ///   - consumerToken: The stream's consumer token.
      internal init(
        controller: LanguageModelSession.StreamController<Content>,
        consumerToken: LanguageModelSession.StreamConsumerToken<Content>
      ) {
        self.controller = controller
        self.consumerToken = consumerToken
        self.iterator = controller.stream.makeAsyncIterator()
      }
    }
  }

  extension LanguageModelSession.ResponseStream.AsyncIterator {
    /// Asynchronously advances to and returns the next snapshot in the stream.
    ///
    /// - Parameter actor: The actor boundary to isolate execution to.
    /// - Returns: The next snapshot, or `nil` if the stream finished or was cancelled.
    /// - Throws: An error if streaming failed.
    public mutating func next(
      isolation actor: isolated (any Actor)? = #isolation
    ) async throws -> LanguageModelSession.ResponseStream<Content>.Snapshot? {
      if Task.isCancelled {
        controller.cancelFromConsumer()
        await controller.waitUntilTerminated()
        return nil
      }
      let controller = self.controller
      return try await withTaskCancellationHandler {
        do {
          let nextSnapshot = try await iterator.next(isolation: actor)
          if Task.isCancelled || (nextSnapshot == nil && controller.wasCancelledByConsumer) {
            controller.cancelFromConsumer()
            await controller.waitUntilTerminated()
            return nil
          }
          return nextSnapshot
        } catch {
          if Task.isCancelled || controller.wasCancelledByConsumer {
            await controller.waitUntilTerminated()
            return nil
          }
          throw error
        }
      } onCancel: {
        controller.cancelFromConsumer()
      }
    }
  }

  // MARK: - Internal stream controller

  extension LanguageModelSession {
    /// The consumer side's hold on a stream: every copy of a `ResponseStream` and every iterator made
    /// from it share one token, and the driver task never references it.
    ///
    /// When the last copy is released while generation is still running, the token's `deinit`
    /// cancels generation, as Apple's session does: the session cancels the executor, applies the
    /// error-handling policy, and adds no turn usage. Releasing the stream after the final turn's
    /// executor has returned doesn't cancel; the response is committed. Retaining the stream (for
    /// example after breaking out of a loop over it) lets generation finish and commit.
    internal final class StreamConsumerToken<Content: Generable>: Sendable {
      /// The controller to notify on release.
      private let controller: StreamController<Content>

      /// Creates a token for `controller`.
      ///
      /// - Parameter controller: The stream controller.
      init(controller: StreamController<Content>) {
        self.controller = controller
      }

      /// Cancels generation that is still running.
      deinit {
        controller.consumerReleased()
      }
    }

    /// Thread-safe coordinator between a background streaming task, snapshot iterators, and
    /// `collect()`.
    ///
    /// `@unchecked Sendable` is required because `Content: Generable` is not constrained to
    /// `Sendable` in the public API, so `ResponseStream<Content>.Snapshot` and `Response<Content>`
    /// are not unconditionally `Sendable`. All mutable state is synchronized by `mutex` and
    /// transferred across `sending` boundaries.
    internal final class StreamController<Content: Generable>: @unchecked Sendable {
      /// Mutable state guarded by `mutex`.
      ///
      /// `@unchecked Sendable` is required because `Response<Content>` only conforms to `Sendable`
      /// when `Content: Sendable`, whereas `Mutex` requires its `Value` type to be `Sendable`.
      private struct State: @unchecked Sendable {
        /// Whether the stream has been cancelled by a consumer task.
        var cancelledByConsumer = false

        /// Whether the snapshot stream has already finished normally.
        var streamFinished = false

        /// Whether the driver has fully terminated (transcript policy applied and `isResponding`
        /// cleared).
        var terminated = false

        /// The completed response or error, once the driver finishes.
        var finalResult: Result<Response<Content>, any Swift.Error>?

        /// Continuations waiting in `collect()`.
        var collectWaiters: [CheckedContinuation<Response<Content>, any Swift.Error>] = []

        /// Continuations waiting for driver termination on consumer cancellation.
        var terminationWaiters: [CheckedContinuation<Void, Never>] = []

        /// Cancellation handler registered by the driver task.
        var onConsumerCancel: (@Sendable () -> Void)?

        /// Whether the final turn's executor has returned, after which releasing the stream no
        /// longer cancels.
        var isFinishing = false
      }

      /// The unbounded stream of snapshots.
      let stream: AsyncThrowingStream<ResponseStream<Content>.Snapshot, any Swift.Error>

      /// The continuation feeding `stream`.
      private let continuation:
        AsyncThrowingStream<ResponseStream<Content>.Snapshot, any Swift.Error>.Continuation

      /// Mutex guarding `State`.
      private let mutex = Mutex(State())

      /// Creates an open stream controller.
      init() {
        var captured:
          AsyncThrowingStream<ResponseStream<Content>.Snapshot, any Swift.Error>.Continuation?
        self.stream = AsyncThrowingStream { continuation in
          captured = continuation
        }
        guard let captured else {
          preconditionFailure("AsyncThrowingStream did not initialize continuation synchronously.")
        }
        self.continuation = captured
      }

      /// Whether a consumer task cancelled iteration.
      var wasCancelledByConsumer: Bool {
        mutex.withLock { $0.cancelledByConsumer }
      }

      /// Registers a callback invoked if a consumer task cancels iteration or `collect()`.
      ///
      /// - Parameter handler: Closure to run on cancellation.
      func setCancellationHandler(_ handler: @escaping @Sendable () -> Void) {
        let shouldInvokeImmediately = mutex.withLock { state -> Bool in
          if state.cancelledByConsumer {
            return true
          }
          state.onConsumerCancel = handler
          return false
        }
        if shouldInvokeImmediately {
          handler()
        }
      }

      /// Yields a snapshot to any active iterator.
      ///
      /// - Parameter snapshot: The snapshot to yield.
      func yield(_ snapshot: ResponseStream<Content>.Snapshot) {
        let isCancelled = mutex.withLock { $0.cancelledByConsumer }
        guard !isCancelled else { return }
        continuation.yield(unsafeTransfer(snapshot))
      }

      /// Yields the final snapshot, finishes the snapshot stream normally, and resolves `collect()`
      /// with `result` (either returning the final response or throwing a final-conversion error).
      ///
      /// - Parameters:
      ///   - finalSnapshot: The completed snapshot to yield before closing the snapshot stream.
      ///   - result: The final response or conversion error for `collect()`.
      func complete(
        finalSnapshot: ResponseStream<Content>.Snapshot,
        result: Result<Response<Content>, any Swift.Error>
      ) {
        let transferred = mutex.withLock {
          state -> UnsafeSendableTransfer<
            (
              Bool,
              [CheckedContinuation<Response<Content>, any Swift.Error>],
              [CheckedContinuation<Void, Never>]
            )
          > in
          guard state.finalResult == nil else {
            return UnsafeSendableTransfer(value: (true, [], []))
          }
          let isCancelled = state.cancelledByConsumer
          state.streamFinished = true
          state.terminated = true
          state.finalResult = result
          let waiters = state.collectWaiters
          state.collectWaiters.removeAll()
          let terminationWaiters = state.terminationWaiters
          state.terminationWaiters.removeAll()
          return UnsafeSendableTransfer(value: (isCancelled, waiters, terminationWaiters))
        }
        let (isCancelled, waiters, terminationWaiters) = transferred.value
        if !isCancelled {
          continuation.yield(unsafeTransfer(finalSnapshot))
        }
        continuation.finish()
        for waiter in terminationWaiters {
          waiter.resume()
        }
        for waiter in waiters {
          switch result {
          case .success(let response):
            waiter.resume(returning: unsafeTransfer(response))
          case .failure(let error):
            waiter.resume(throwing: error)
          }
        }
      }

      /// Completes the stream with `error`.
      ///
      /// - Parameter error: The terminal error.
      func fail(with error: any Swift.Error) {
        let transferred = mutex.withLock {
          state -> UnsafeSendableTransfer<
            (
              Bool,
              [CheckedContinuation<Response<Content>, any Swift.Error>],
              [CheckedContinuation<Void, Never>]
            )
          > in
          guard state.finalResult == nil else {
            return UnsafeSendableTransfer(
              value: (state.cancelledByConsumer || state.streamFinished, [], [])
            )
          }
          state.terminated = true
          state.finalResult = .failure(error)
          let waiters = state.collectWaiters
          state.collectWaiters.removeAll()
          let terminationWaiters = state.terminationWaiters
          state.terminationWaiters.removeAll()
          return UnsafeSendableTransfer(
            value: (state.cancelledByConsumer || state.streamFinished, waiters, terminationWaiters)
          )
        }
        let (skipThrowingContinuation, waiters, terminationWaiters) = transferred.value
        if skipThrowingContinuation {
          continuation.finish()
        } else {
          continuation.finish(throwing: error)
        }
        for waiter in terminationWaiters {
          waiter.resume()
        }
        for waiter in waiters {
          waiter.resume(throwing: error)
        }
      }

      /// Suspends until the background driver has applied its transcript policy and cleared
      /// `isResponding` (`complete` or `fail`).
      nonisolated(nonsending) func waitUntilTerminated() async {
        await withCheckedContinuation { continuation in
          let alreadyTerminated = mutex.withLock { state -> Bool in
            if state.terminated {
              return true
            }
            state.terminationWaiters.append(continuation)
            return false
          }
          if alreadyTerminated {
            continuation.resume()
          }
        }
      }

      /// Marks that the final turn's executor has returned, so releasing the stream no longer
      /// cancels.
      func markFinishing() {
        mutex.withLock { $0.isFinishing = true }
      }

      /// Cancels generation because the consumer released every copy of the stream, unless the final
      /// turn's executor has already returned or the stream has ended.
      func consumerReleased() {
        let shouldCancel = mutex.withLock { state in
          !state.isFinishing && state.finalResult == nil
        }
        if shouldCancel {
          cancelFromConsumer()
        }
      }

      /// Cancels generation from the consumer side (`AsyncIterator.next` or `collect()`).
      func cancelFromConsumer() {
        let handler = mutex.withLock { state -> (@Sendable () -> Void)? in
          guard !state.cancelledByConsumer else { return nil }
          state.cancelledByConsumer = true
          let handler = state.onConsumerCancel
          state.onConsumerCancel = nil
          return handler
        }
        continuation.finish()
        handler?()
      }

      /// Waits for and returns the final response, or throws the terminal error.
      ///
      /// - Returns: The completed response.
      /// - Throws: The error that ended the stream, or `CancellationError`.
      nonisolated(nonsending) func collect() async throws -> sending Response<Content> {
        try await withTaskCancellationHandler {
          let response: Response<Content> = try await withCheckedThrowingContinuation {
            continuation in
            let immediateResult = mutex.withLock {
              state -> UnsafeSendableTransfer<Result<Response<Content>, any Swift.Error>?> in
              if let result = state.finalResult {
                return UnsafeSendableTransfer(value: result)
              }
              state.collectWaiters.append(continuation)
              return UnsafeSendableTransfer(value: nil)
            }
            if let result = immediateResult.value {
              switch result {
              case .success(let value):
                continuation.resume(returning: unsafeTransfer(value))
              case .failure(let error):
                continuation.resume(throwing: error)
              }
            }
          }
          return unsafeTransfer(response)
        } onCancel: {
          self.cancelFromConsumer()
        }
      }
    }
  }

  /// Wrapper used to transfer a `Response<Content>` or `Snapshot` across `Mutex.withLock` and
  /// continuation boundaries into a `sending` return value when `Content: Generable` is not
  /// constrained to `Sendable`.
  private struct UnsafeSendableTransfer<Value>: @unchecked Sendable {
    /// The transferred value.
    let value: Value
  }

  /// Transfers `value` across a `sending` return boundary.
  private func unsafeTransfer<Value>(_ value: Value) -> sending Value {
    let box = UnsafeSendableTransfer(value: value)
    return box.value
  }
#endif  // compiler(>=6.4)
