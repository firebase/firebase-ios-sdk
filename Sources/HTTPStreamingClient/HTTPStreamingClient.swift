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

#if canImport(FoundationEssentials) && canImport(FoundationNetworking)
  import FoundationEssentials
  package import FoundationNetworking
  import Foundation
#else
  package import Foundation
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
        Task {
          await delegate.register(
            task: task,
            responseContinuation: continuation,
            dataContinuation: dataContinuation
          )
          task.resume()
        }
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

  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(streamIterator: dataStream.makeAsyncIterator())
  }

  package struct AsyncIterator: AsyncIteratorProtocol {
    private var streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator
    private var currentChunk: Data = Data()
    private var currentIndex: Data.Index = 0

    init(streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator) {
      self.streamIterator = streamIterator
    }

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
  package typealias Element = String

  private let dataStream: AsyncThrowingStream<Data, any Error>

  init(dataStream: AsyncThrowingStream<Data, any Error>) {
    self.dataStream = dataStream
  }

  package func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(streamIterator: dataStream.makeAsyncIterator())
  }

  package struct AsyncIterator: AsyncIteratorProtocol {
    private var streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator
    private var decoder = HTTPLineDecoder()
    private var pendingLines: [String] = []
    private var pendingIndex: Int = 0
    private var isFinished = false

    init(streamIterator: AsyncThrowingStream<Data, any Error>.AsyncIterator) {
      self.streamIterator = streamIterator
    }

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

// MARK: - Internal Task Coordinator

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
private actor TaskCoordinator {
  private struct TaskState {
    var responseContinuation: CheckedContinuation<HTTPURLResponse, any Error>?
    let dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation
  }

  private var tasks: [URLSessionTask: TaskState] = [:]

  func register(
    task: URLSessionTask,
    responseContinuation: CheckedContinuation<HTTPURLResponse, any Error>,
    dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation
  ) {
    tasks[task] = TaskState(
      responseContinuation: responseContinuation,
      dataContinuation: dataContinuation
    )
  }

  func didReceiveResponse(
    _ response: URLResponse,
    for task: URLSessionTask
  ) -> URLSession.ResponseDisposition {
    guard let state = tasks[task] else { return .cancel }

    if let httpResponse = response as? HTTPURLResponse {
      state.responseContinuation?.resume(returning: httpResponse)
      tasks[task]?.responseContinuation = nil
      return .allow
    } else {
      state.responseContinuation?.resume(throwing: URLError(.badServerResponse))
      state.dataContinuation.finish(throwing: URLError(.badServerResponse))
      tasks.removeValue(forKey: task)
      return .cancel
    }
  }

  func didReceiveData(_ data: Data, for task: URLSessionTask) {
    tasks[task]?.dataContinuation.yield(data)
  }

  func didCompleteWithError(_ error: (any Error)?, for task: URLSessionTask) {
    guard let state = tasks.removeValue(forKey: task) else { return }

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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
private final class SessionDelegate: NSObject, URLSessionDataDelegate, Sendable {
  private let coordinator = TaskCoordinator()

  func register(
    task: URLSessionTask,
    responseContinuation: CheckedContinuation<HTTPURLResponse, any Error>,
    dataContinuation: AsyncThrowingStream<Data, any Error>.Continuation
  ) async {
    await coordinator.register(
      task: task,
      responseContinuation: responseContinuation,
      dataContinuation: dataContinuation
    )
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    Task {
      let disposition = await coordinator.didReceiveResponse(response, for: dataTask)
      completionHandler(disposition)
    }
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    Task {
      await coordinator.didReceiveData(data, for: dataTask)
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    Task {
      await coordinator.didCompleteWithError(error, for: task)
    }
  }
}

// MARK: - Incremental Line Decoder

/// An incremental decoder that extracts UTF-8 lines of text from streaming byte chunks.
package struct HTTPLineDecoder: Sendable {
  private var buffer = Data()
  private var pendingCR = false

  package init() {}

  /// Feeds a new chunk of data and returns all complete lines found.
  ///
  /// - Parameter data: The incoming data chunk.
  /// - Returns: An array of decoded lines with trailing line delimiters stripped.
  package mutating func feed(_ data: Data) -> [String] {
    var lines: [String] = []
    lines.reserveCapacity(data.count / 32)

    for byte in data {
      if pendingCR {
        pendingCR = false
        if byte == 0x0A {
          // Consumed the LF in a CRLF pair; line was already emitted on CR.
          continue
        }
        // Standalone CR previously emitted; process this byte normally below.
      }

      switch byte {
      case 0x0A:  // LF (\n)
        let line = String(decoding: buffer, as: UTF8.self)
        lines.append(line)
        buffer.removeAll(keepingCapacity: true)

      case 0x0D:  // CR (\r)
        let line = String(decoding: buffer, as: UTF8.self)
        lines.append(line)
        buffer.removeAll(keepingCapacity: true)
        pendingCR = true

      default:
        buffer.append(byte)
      }
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
