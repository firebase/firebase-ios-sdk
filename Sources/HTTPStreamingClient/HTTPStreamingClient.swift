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
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
package struct HTTPStreamingClient: Sendable {
  private let session: URLSession
  private let delegate: SessionDelegate

  /// Initializes a new HTTP streaming client with the specified configuration.
  ///
  /// - Parameter configuration: The `URLSessionConfiguration` to use. Defaults to `.default`.
  package init(configuration: URLSessionConfiguration = .default) {
    let delegate = SessionDelegate()
    self.delegate = delegate
    self.session = URLSession(
      configuration: configuration,
      delegate: delegate,
      delegateQueue: nil
    )
  }

  /// Sends a request and delivers an asynchronous sequence of bytes and the HTTP response metadata.
  ///
  /// - Parameter request: The `URLRequest` to execute.
  /// - Returns: A tuple containing the `HTTPAsyncBytes` stream and `HTTPURLResponse` metadata.
  /// - Throws: An error if the request fails to connect or if the response is not an HTTP response.
  package func bytes(
    for request: URLRequest
  ) async throws -> (bytes: HTTPAsyncBytes, response: HTTPURLResponse) {
    let (dataStream, dataContinuation) = AsyncThrowingStream<Data, any Error>.makeStream()

    let task = session.dataTask(with: request)
    dataContinuation.onTermination = { @Sendable _ in
      task.cancel()
    }

    let response: HTTPURLResponse = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        delegate.register(
          task: task,
          responseContinuation: continuation,
          dataContinuation: dataContinuation
        )
        task.resume()
      }
    } onCancel: {
      task.cancel()
    }

    let asyncBytes = HTTPAsyncBytes(dataStream: dataStream, task: task)
    return (bytes: asyncBytes, response: response)
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

// MARK: - HTTP Async Bytes

/// An asynchronous sequence of bytes delivered from an HTTP request.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
package struct HTTPAsyncBytes: AsyncSequence, Sendable {
  /// The type of element produced by this asynchronous byte stream.
  package typealias Element = UInt8

  private let dataStream: AsyncThrowingStream<Data, any Error>

  /// The underlying `URLSessionTask` performing the data transfer.
  package let task: URLSessionTask?

  init(
    dataStream: AsyncThrowingStream<Data, any Error>,
    task: URLSessionTask? = nil
  ) {
    self.dataStream = dataStream
    self.task = task
  }

  /// An asynchronous sequence of lines of text extracted from this byte stream.
  package var lines: HTTPAsyncLineSequence {
    HTTPAsyncLineSequence(dataStream: dataStream)
  }

  /// Collects all bytes from the stream into a single `Data` instance.
  ///
  /// - Returns: The complete response body as `Data`.
  /// - Throws: An error if the stream encounters a network failure.
  package func collect() async throws -> Data {
    var accumulated = Data()
    for try await chunk in dataStream {
      accumulated.append(chunk)
    }
    return accumulated
  }

  /// Creates an asynchronous iterator over the byte sequence.
  ///
  /// - Returns: An `AsyncIterator` instance.
  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(streamIterator: dataStream.makeAsyncIterator())
  }

  /// An asynchronous iterator over the bytes of an HTTP response body.
  package struct AsyncIterator: AsyncIteratorProtocol {
    private var streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator
    private var currentChunk: Data = Data()
    private var currentIndex: Data.Index = 0

    init(streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator) {
      self.streamIterator = streamIterator
    }

    /// Asynchronously advances to and returns the next byte in the stream.
    ///
    /// - Returns: The next byte, or `nil` if the stream has finished.
    /// - Throws: An error if reading from the stream fails.
    package mutating func next() async throws -> UInt8? {
      while currentIndex >= currentChunk.endIndex {
        guard let nextChunk = try await streamIterator.next() else {
          return nil
        }
        currentChunk = nextChunk
        currentIndex = currentChunk.startIndex
      }

      let byte = currentChunk[currentIndex]
      currentIndex = currentChunk.index(after: currentIndex)
      return byte
    }
  }
}

// MARK: - HTTP Async Line Sequence

/// An asynchronous sequence of lines of text parsed from an HTTP byte stream.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
package struct HTTPAsyncLineSequence: AsyncSequence, Sendable {
  /// The type of element produced by this line sequence.
  package typealias Element = String

  private let dataStream: AsyncThrowingStream<Data, any Error>

  init(dataStream: AsyncThrowingStream<Data, any Error>) {
    self.dataStream = dataStream
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

// MARK: - Internal Session Delegate

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
private final class SessionDelegate: NSObject, URLSessionDataDelegate, Sendable {
  private struct TaskState {
    var responseContinuation: CheckedContinuation<HTTPURLResponse, any Error>?
    let dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation
  }

  private let tasks = LockProtected<[URLSessionTask: TaskState]>([:])

  func register(
    task: URLSessionTask,
    responseContinuation: CheckedContinuation<HTTPURLResponse, any Error>,
    dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation
  ) {
    tasks.withLock {
      $0[task] = TaskState(
        responseContinuation: responseContinuation,
        dataContinuation: dataContinuation
      )
    }
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    let outcome = tasks.withLock {
      (state: inout [URLSessionTask: TaskState]) -> (
        CheckedContinuation<HTTPURLResponse, any Error>?, Bool
      )? in
      guard let taskState = state[dataTask] else { return nil }
      if response is HTTPURLResponse {
        state[dataTask]?.responseContinuation = nil
        return (taskState.responseContinuation, true)
      } else {
        state.removeValue(forKey: dataTask)
        return (taskState.responseContinuation, false)
      }
    }

    guard let (continuation, isHTTP) = outcome else {
      completionHandler(.cancel)
      return
    }

    if isHTTP, let httpResponse = response as? HTTPURLResponse {
      continuation?.resume(returning: httpResponse)
      completionHandler(.allow)
    } else {
      continuation?.resume(throwing: URLError(.badServerResponse))
      completionHandler(.cancel)
    }
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    let continuation = tasks.withLock { $0[dataTask]?.dataContinuation }
    continuation?.yield(data)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    let state = tasks.withLock { $0.removeValue(forKey: task) }
    guard let state else { return }

    if let error {
      state.responseContinuation?.resume(throwing: error)
      state.dataContinuation.finish(throwing: error)
    } else {
      if let responseContinuation = state.responseContinuation {
        responseContinuation.resume(throwing: URLError(.badServerResponse))
      }
      state.dataContinuation.finish()
    }
  }
}

// MARK: - Incremental Line Decoder

/// An incremental decoder that extracts UTF-8 lines of text from streaming byte chunks.
package struct HTTPLineDecoder: Sendable {
  private var buffer = Data()
  private var pendingCR = false

  /// Initializes a new line decoder with an empty buffer.
  package init() {}

  /// Feeds a new chunk of data and returns all complete lines found.
  ///
  /// - Parameter data: The incoming data chunk.
  /// - Returns: An array of decoded lines with trailing line delimiters stripped.
  package mutating func feed(_ data: Data) -> [String] {
    guard !data.isEmpty else { return [] }

    var lines: [String] = []
    lines.reserveCapacity(data.count / 32)
    var searchStartIndex = data.startIndex

    if pendingCR {
      pendingCR = false
      if data[searchStartIndex] == 0x0A {
        searchStartIndex = data.index(after: searchStartIndex)
      }
    }

    while searchStartIndex < data.endIndex {
      guard
        let nextNewlineIndex = data[searchStartIndex...].firstIndex(where: {
          $0 == 0x0A || $0 == 0x0D
        })
      else {
        buffer.append(data[searchStartIndex...])
        pendingCR = false
        break
      }

      let byte = data[nextNewlineIndex]

      if pendingCR {
        pendingCR = false
        if byte == 0x0A && nextNewlineIndex == searchStartIndex {
          searchStartIndex = data.index(after: nextNewlineIndex)
          continue
        }
      }

      if nextNewlineIndex > searchStartIndex {
        buffer.append(data[searchStartIndex..<nextNewlineIndex])
      }

      let line = String(decoding: buffer, as: UTF8.self)
      lines.append(line)
      buffer.removeAll(keepingCapacity: true)

      if byte == 0x0D {
        pendingCR = true
      } else {
        pendingCR = false
      }

      searchStartIndex = data.index(after: nextNewlineIndex)
    }

    return lines
  }

  /// Flushes any remaining bytes in the buffer as the final line.
  ///
  /// - Returns: The final line if the buffer is non-empty, or `nil`.
  package mutating func flush() -> String? {
    pendingCR = false
    guard !buffer.isEmpty else { return nil }
    let line = String(decoding: buffer, as: UTF8.self)
    buffer.removeAll(keepingCapacity: false)
    return line
  }
}
