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

import Synchronization

#if canImport(Darwin)
  package import Foundation
#else
  import Foundation
  package import FoundationNetworking
#endif

/// An HTTP client that streams bytes and lines of text using `URLSession`.
///
/// Supports Apple platforms and Linux with full Swift 6 strict concurrency compliance.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package final class HTTPStreamingClient: Sendable {
  private let session: URLSession
  private let sessionDelegate: SessionDelegate

  /// Initializes a new HTTP streaming client with the specified configuration.
  ///
  /// - Parameter configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
  package init(configuration: URLSessionConfiguration = .ephemeral) {
    let delegate = SessionDelegate()
    self.sessionDelegate = delegate
    self.session = URLSession(
      configuration: configuration,
      delegate: delegate,
      delegateQueue: nil
    )
  }

  deinit {
    session.invalidateAndCancel()
  }

  /// Sends a request and delivers an asynchronous sequence of lines of text and the HTTP response.
  ///
  /// - Parameter request: The `URLRequest` to execute.
  /// - Returns: A tuple of the `HTTPAsyncLineSequence` stream and `HTTPURLResponse` metadata.
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
    sessionDelegate.addTaskDelegate(taskDelegate, for: dataTask.taskIdentifier)

    let response: HTTPURLResponse = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        taskDelegate.setResponseContinuation(continuation)
        dataTask.resume()
      }
    } onCancel: {
      dataTask.cancel()
    }

    let asyncLines = HTTPAsyncLineSequence(dataStream: dataStream, task: dataTask, client: self)
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
package struct HTTPAsyncLineSequence: AsyncSequence, Sendable {
  private let dataStream: AsyncThrowingStream<Data, any Error>

  /// The underlying `URLSessionTask` performing the data transfer.
  package let task: URLSessionTask
  private let client: HTTPStreamingClient

  /// Initializes a new async line sequence from a data stream.
  ///
  /// - Parameters:
  ///   - dataStream: The underlying byte stream.
  ///   - task: The URL session data task.
  ///   - client: The HTTP client that created this sequence.
  init(
    dataStream: AsyncThrowingStream<Data, any Error>,
    task: URLSessionDataTask,
    client: HTTPStreamingClient
  ) {
    self.dataStream = dataStream
    self.task = task
    self.client = client
  }

  /// Creates an asynchronous iterator over the line sequence.
  ///
  /// - Returns: An `AsyncIterator` instance.
  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(streamIterator: dataStream.makeAsyncIterator(), client: client)
  }

  /// An asynchronous iterator over lines of text decoded from an HTTP response.
  package struct AsyncIterator: AsyncIteratorProtocol {
    private var streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator
    private var decoder = HTTPLineDecoder()
    private var pendingLines: ArraySlice<String> = []
    private let client: HTTPStreamingClient

    /// Initializes a new async iterator.
    ///
    /// - Parameters:
    ///   - streamIterator: The underlying byte stream iterator.
    ///   - client: The HTTP client that created this sequence.
    init(
      streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator,
      client: HTTPStreamingClient
    ) {
      self.streamIterator = streamIterator
      self.client = client
    }

    /// Asynchronously advances to and returns the next line of text.
    ///
    /// - Returns: The next decoded line of text, or `nil` if the stream has finished.
    /// - Throws: An error if reading from the stream fails.
    package mutating func next() async throws -> String? {
      while pendingLines.isEmpty {
        guard let chunk = try await streamIterator.next() else {
          // Once the stream ends, flush any remaining bytes as a final line.
          // Subsequent calls to next() will safely fall through and return nil.
          return decoder.flush()
        }

        // Convert the returned Array into an ArraySlice
        pendingLines = decoder.feed(chunk)[...]
      }

      return pendingLines.popFirst()
    }
  }
}

// MARK: - Internal Session Delegate Dispatcher

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
private final class SessionDelegate: NSObject, URLSessionDataDelegate, Sendable {
  private let taskDelegates = Mutex<[Int: TaskDelegate]>([:])

  func addTaskDelegate(_ delegate: TaskDelegate, for taskIdentifier: Int) {
    taskDelegates.withLock { $0[taskIdentifier] = delegate }
  }

  private func taskDelegate(for taskIdentifier: Int) -> TaskDelegate? {
    taskDelegates.withLock { $0[taskIdentifier] }
  }

  private func removeTaskDelegate(for taskIdentifier: Int) -> TaskDelegate? {
    taskDelegates.withLock { $0.removeValue(forKey: taskIdentifier) }
  }

  // MARK: - URLSessionDataDelegate

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    guard let delegate = taskDelegate(for: dataTask.taskIdentifier) else {
      completionHandler(.allow)
      return
    }
    delegate.urlSession(
      session,
      dataTask: dataTask,
      didReceive: response,
      completionHandler: completionHandler
    )
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard let delegate = taskDelegate(for: dataTask.taskIdentifier) else { return }
    delegate.urlSession(session, dataTask: dataTask, didReceive: data)
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    let delegate = removeTaskDelegate(for: task.taskIdentifier)
    delegate?.urlSession(session, task: task, didCompleteWithError: error)
  }
}

// MARK: - Internal Task Delegate

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
private final class TaskDelegate: NSObject, URLSessionDataDelegate, Sendable {
  private enum ResponseState: Sendable {
    case pending
    case waiting(CheckedContinuation<HTTPURLResponse, any Error>)
    case completed(Result<HTTPURLResponse, any Error>)
  }

  private let responseState = Mutex<ResponseState>(.pending)
  private let dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation

  init(dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation) {
    self.dataContinuation = dataContinuation
  }

  func setResponseContinuation(_ continuation: CheckedContinuation<HTTPURLResponse, any Error>) {
    let resultToResume: Result<HTTPURLResponse, any Error>? = responseState.withLock { state in
      switch state {
      case .pending:
        state = .waiting(continuation)
        return nil
      case .waiting:
        fatalError("Response continuation set multiple times")
      case .completed(let result):
        return result
      }
    }
    if let resultToResume {
      continuation.resume(with: resultToResume)
    }
  }

  /// Atomically transitions the state to completed and resumes any waiting continuation.
  private func resumeResponse(with result: Result<HTTPURLResponse, any Error>) {
    let continuationToResume: CheckedContinuation<HTTPURLResponse, any Error>? =
      responseState
      .withLock { state in
        switch state {
        case .pending:
          state = .completed(result)
          return nil
        case .waiting(let continuation):
          state = .completed(result)
          return continuation
        case .completed:
          return nil
        }
      }
    continuationToResume?.resume(with: result)
  }

  // MARK: - URLSessionDataDelegate

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    // 1. Dedicated hook for the response header
    if let httpResponse = response as? HTTPURLResponse {
      if (100...199).contains(httpResponse.statusCode) {
        completionHandler(.allow)
        return
      }
      resumeResponse(with: .success(httpResponse))
      completionHandler(.allow)
    } else {
      resumeResponse(with: .failure(URLError(.badServerResponse)))
      completionHandler(.cancel)
    }
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    // 2. Pure data passthrough
    dataContinuation.yield(data)
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    // 3. Clean up stream and catch any pre-response failures
    if let error {
      resumeResponse(with: .failure(error))
      dataContinuation.finish(throwing: error)
    } else {
      // Fallback in case the task completes successfully but somehow never sent a response
      resumeResponse(with: .failure(URLError(.badServerResponse)))
      dataContinuation.finish()
    }
  }
}
