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

package import Foundation

#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

/// An HTTP client that streams bytes and lines of text using `URLSession`.
///
/// Supports Apple platforms and Linux with full Swift 6 strict concurrency compliance.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package struct HTTPStreamingClient: Sendable {
  private let session: URLSession

  /// Initializes a new HTTP streaming client with the specified configuration.
  ///
  /// - Parameter configuration: The `URLSessionConfiguration` to use. Defaults to `.default`.
  package init(configuration: URLSessionConfiguration = .ephemeral) {
    self.session = URLSession(configuration: configuration)
  }

  /// Sends a request and delivers an asynchronous sequence of lines of text and the HTTP response metadata.
  ///
  /// - Parameter request: The `URLRequest` to execute.
  /// - Returns: A tuple containing the `HTTPAsyncLineSequence` stream and `HTTPURLResponse` metadata.
  /// - Throws: An error if the request fails to connect or if the response is not an HTTP response.
  package func lines(
    for request: URLRequest
  ) async throws -> (lines: HTTPAsyncLineSequence, response: HTTPURLResponse) {
    let (dataStream, dataContinuation) = AsyncThrowingStream<Data, any Error>.makeStream()

    let dataTask = session.dataTask(with: request)
    dataContinuation.onTermination = { @Sendable _ in
      dataTask.cancel()
    }

    let taskDelegate = TaskDelegate(dataContinuation: dataContinuation)
    dataTask.delegate = taskDelegate

    let response: HTTPURLResponse = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        taskDelegate.setResponseContinuation(continuation)
        dataTask.resume()
      }
    } onCancel: {
      dataTask.cancel()
    }

    let asyncLines = HTTPAsyncLineSequence(dataStream: dataStream, task: dataTask)
    return (lines: asyncLines, response: response)
  }

  /// Invalidates the session, allowing any outstanding tasks to finish.
  package func finishTasksAndInvalidate() {
    session.finishTasksAndInvalidate()
  }

  /// Invalidates the session and cancels all active tasks.
  package func invalidateAndCancel() {
    session.invalidateAndCancel()
  }
}

// MARK: - HTTP Async Line Sequence

/// An asynchronous sequence of lines of text parsed from an HTTP byte stream.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
/// Safety: `URLSessionTask` is inherently thread-safe in Foundation.
package struct HTTPAsyncLineSequence: AsyncSequence, Sendable {
  private let dataStream: AsyncThrowingStream<Data, any Error>

  /// The underlying `URLSessionTask` performing the data transfer.
  package let task: URLSessionTask?

  init(
    dataStream: AsyncThrowingStream<Data, any Error>,
    task: URLSessionDataTask? = nil
  ) {
    self.dataStream = dataStream
    self.task = task
  }

  /// Creates an asynchronous iterator over the line sequence.
  ///
  /// - Returns: An `AsyncIterator` instance.
  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(streamIterator: dataStream.makeAsyncIterator())
  }

  /// An asynchronous iterator over lines of text decoded from an HTTP response.
  package struct AsyncIterator: AsyncIteratorProtocol {
    private var streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator
    private var decoder = HTTPLineDecoder()
    private var pendingLines: [String] = []
    private var pendingIndex: Int = 0
    private var isFinished = false

    init(streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator) {
      self.streamIterator = streamIterator
    }

    /// Asynchronously advances to and returns the next line of text.
    ///
    /// - Returns: The next decoded line of text, or `nil` if the stream has finished.
    /// - Throws: An error if reading from the stream fails.
    package mutating func next() async throws -> String? {
      while pendingIndex >= pendingLines.count {
        if isFinished {
          return nil
        }

        guard let chunk = try await streamIterator.next() else {
          isFinished = true
          if let remainder = decoder.flush() {
            return remainder
          }
          return nil
        }

        let lines = decoder.feed(chunk)
        if !lines.isEmpty {
          pendingLines = lines
          pendingIndex = 0
          let firstLine = pendingLines[pendingIndex]
          pendingIndex += 1
          return firstLine
        }
      }

      let line = pendingLines[pendingIndex]
      pendingIndex += 1
      return line
    }
  }
}

// MARK: - Lock Protected Container

/// A thread-safe container for mutable state.
///
/// Safety: This class uses an `NSLock` to serialize all access to the underlying `state`.
/// It is marked `@unchecked Sendable` because the compiler cannot verify `NSLock` isolation,
/// but data-race safety is manually guaranteed.
private final class LockProtected<State>: @unchecked Sendable {
  private let lock = NSLock()
  private var state: State

  init(_ initialState: State) {
    self.state = initialState
  }

  func withLock<Result>(_ body: (inout State) throws -> Result) rethrows -> Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&state)
  }
}

// MARK: - Internal Task Delegate

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
/// Safety: Protected by `LockProtected` for all mutable state.
private final class TaskDelegate: NSObject, URLSessionDataDelegate, Sendable {
  let responseContinuation = LockProtected<CheckedContinuation<HTTPURLResponse, any Error>?>(nil)
  let dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation

  init(dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation) {
    self.dataContinuation = dataContinuation
  }

  func takeResponseContinuation() -> CheckedContinuation<HTTPURLResponse, any Error>? {
    responseContinuation.withLock { state in
      let value = state
      state = nil
      return value
    }
  }

  func setResponseContinuation(_ continuation: CheckedContinuation<HTTPURLResponse, any Error>) {
    responseContinuation.withLock { $0 = continuation }
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    guard let continuation = takeResponseContinuation() else {
      completionHandler(.cancel)
      return
    }

    if let httpResponse = response as? HTTPURLResponse {
      continuation.resume(returning: httpResponse)
      completionHandler(.allow)
    } else {
      continuation.resume(throwing: URLError(.badServerResponse))
      completionHandler(.cancel)
    }
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    dataContinuation.yield(data)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    if let error {
      takeResponseContinuation()?.resume(throwing: error)
      dataContinuation.finish(throwing: error)
    } else {
      if let continuation = takeResponseContinuation() {
        continuation.resume(throwing: URLError(.badServerResponse))
      }
      dataContinuation.finish()
    }
  }
}
