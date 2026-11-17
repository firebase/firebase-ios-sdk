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

import Foundation

@_spi(FirebaseNetworking) internal import FirebaseCoreInternal

/// Uploads data or a file to Firebase Storage with the resumable upload protocol.
///
/// The `start` request carries the object's metadata and opens an upload session. Chunk requests
/// then send the bytes to the session's URL. They carry no Firebase credentials, because the
/// session URL authorizes them. After a failure that is likely to be temporary, the upload waits,
/// asks the server how many bytes it has received, and continues from there.
struct StorageResumableUpload {
  /// The bytes to upload.
  enum Source: Sendable {
    case data(Data)
    /// A file, which must stay in place until the upload finishes.
    case file(URL)
  }

  /// An open upload session. A paused upload keeps its session, so it can continue where it
  /// stopped.
  struct Session: Equatable, Sendable {
    /// The URL that chunk, query, and cancel requests go to.
    let url: URL

    /// The size, in bytes, that the server requires chunks and offsets to be multiples of, or 0
    /// if it requires none.
    var granularity: Int64
  }

  /// The User-Agent of every request of an upload session: the standard one followed by
  /// `(GTMSUF/1)`, as Storage uploads have always sent it, so the upload server's logs see no
  /// change.
  static let userAgent = "\(FirebaseUserAgent.standard) (GTMSUF/1)"

  /// The largest chunk that is read into memory, unless the server's granularity is larger. An
  /// upload of a whole file at once is sent from the file instead.
  #if os(macOS)
    static let maxChunkBufferSize: Int64 = 100 * 1024 * 1024
  #else
    static let maxChunkBufferSize: Int64 = 10 * 1024 * 1024
  #endif

  /// A chunk is the last one if fewer bytes than this would remain after it, so that the rest
  /// doesn't need a request of its own.
  static let minimumFinalChunkRemainder: Int64 = 2500

  /// The request that opens the session. It has the object's metadata as its body, and none of
  /// the headers of the resumable upload protocol.
  let startRequest: URLRequest

  let source: Source

  /// The number of bytes to upload.
  let length: Int64

  /// The MIME type of the uploaded bytes.
  let contentType: String

  /// The largest chunk to send, before rounding to the server's granularity.
  let chunkSize: Int64

  let storage: Storage

  /// Whether the chunks of a file upload run on a background `URLSession`, which the system
  /// continues while the app is suspended.
  let usesBackgroundSession: Bool

  /// Uploads the bytes, and returns the body of the final response: the object's metadata.
  ///
  /// - Parameters:
  ///   - resumedSession: The session of an upload to continue, or `nil` to open a new session.
  ///   - didOpenSession: Called with the new session when one opens.
  ///   - progress: Called as bytes are sent. The counts include the metadata that the `start`
  ///     request sends, so they start above zero and end at the metadata's size plus `length`. A
  ///     retry continues from the bytes that the server reports it has received.
  /// - Throws: The error of the last attempt: an `HTTPStatusError` error, a transport error, a
  ///   file error, or an error of `StorageTokenAuthorizer`. When the server's responses don't
  ///   follow the protocol, an `HTTPStatusError` error with code 501. If the upload was retried,
  ///   the error's `userInfo` also holds the number of retries and the time they took. Throws
  ///   `CancellationError` if the calling task is cancelled.
  func run(resuming resumedSession: Session?,
           didOpenSession: (Session) -> Void,
           progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws -> Data {
    let startBodyLength = Int64(startRequest.httpBody?.count ?? 0)
    let totalLength = startBodyLength + length
    let report: @Sendable (Int64) -> Void = { sentBytes in
      progress(HTTPTransferProgress(completedBytes: startBodyLength + sentBytes,
                                    expectedBytes: totalLength))
    }

    var session: Session
    var step: Step
    if let resumedSession {
      session = resumedSession
      step = .query
    } else {
      session = try await start()
      didOpenSession(session)
      report(0)
      step = .upload(offset: 0)
    }

    let configuration = await StorageHTTPService.shared.configuration()
    let client = configuration.client
    // The backoff of the current series of failures. It starts at the first failure, so the
    // retry time limit doesn't include the time spent sending before it. The server confirming
    // more bytes ends the series.
    var backoff: RetryBackoff?
    var confirmedBytes: Int64 = 0
    while true {
      do {
        switch step {
        case .query:
          switch try await query(session, client: client) {
          case let .finished(body):
            return body
          case let .active(receivedBytes, granularity):
            session.granularity = granularity
            if receivedBytes > confirmedBytes {
              confirmedBytes = receivedBytes
              backoff = nil
            }
            step = .upload(offset: receivedBytes)
          }
        case let .upload(offset):
          let chunk = try makeChunk(at: offset, granularity: session.granularity)
          defer { chunk.removeTemporaryFile() }
          switch try await send(chunk, to: session, client: client, report: report) {
          case let .finished(body):
            return body
          case let .active(receivedBytes, _):
            if receivedBytes > confirmedBytes {
              confirmedBytes = receivedBytes
              backoff = nil
            }
            step = .upload(offset: receivedBytes)
          }
        }
      } catch let failure as RetryableFailure {
        var failureBackoff = backoff ?? RetryBackoff(
          maxRetryTime: storage.maxUploadRetryTime,
          maxInterval: Storage.computeRetryInterval(fromRetryTime: storage.maxUploadRetryTime),
          initialInterval: configuration.initialRetryInterval ?? RetryBackoff
            .randomInitialInterval()
        )
        guard let delay = failureBackoff.nextDelay(suggestedDelay: failure.retryAfter) else {
          throw StorageHTTPService.error(failure.error, after: failureBackoff)
        }
        backoff = failureBackoff
        try await RetryBackoff.sleep(for: delay)
        // The server may have received some of the bytes that failed. Ask it where to continue.
        step = .query
      }
    }
  }

  /// Sends the `cancel` command for `session`, and ignores the outcome.
  static func cancel(_ session: Session, storage: Storage) async {
    let configuration = await StorageHTTPService.shared.configuration()
    var request = sessionRequest(to: session, command: "cancel",
                                 timeout: storage.maxUploadRetryTime)
    request.httpBody = Data()
    _ = try? await configuration.client.data(
      for: request, policy: StorageHTTPService.policy(for: storage)
    )
  }

  // MARK: - Requests

  /// The next request of the upload.
  private enum Step {
    /// Ask the server how many bytes it has received.
    case query
    /// Send the chunk for an upload whose first `offset` bytes the server has received.
    case upload(offset: Int64)
  }

  /// The outcome of a chunk or query request that succeeded.
  private enum Outcome {
    /// The upload is finished. The body of the final response is the object's metadata.
    case finished(Data)
    /// The server has received the first `receivedBytes` bytes and expects more. Chunks must be
    /// multiples of `granularity` bytes, if it isn't 0.
    case active(receivedBytes: Int64, granularity: Int64)
  }

  /// A failure that is likely to be temporary, and the wait that the response asked for before
  /// a retry.
  private struct RetryableFailure: Error {
    let error: NSError
    var retryAfter: TimeInterval?
  }

  /// Opens the upload session.
  private func start() async throws -> Session {
    var request = startRequest
    request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
    request.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
    request.setValue(contentType, forHTTPHeaderField: "X-Goog-Upload-Content-Type")
    request.setValue("\(length)", forHTTPHeaderField: "X-Goog-Upload-Content-Length")
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    let (body, response) = try await StorageHTTPService.shared.dataAndResponse(
      for: request, storage: storage, maxRetryTime: storage.maxUploadRetryTime
    )
    let status = Self.uploadStatus(of: response)
    guard status != "final", status != "cancelled",
          let urlString = response.value(forHTTPHeaderField: "X-Goog-Upload-URL"),
          !urlString.isEmpty, let url = URL(string: urlString) else {
      throw Self.prematureFailure(body: body)
    }
    return Session(url: url, granularity: Self.granularity(of: response))
  }

  /// Asks the server how many bytes of the upload it has received.
  private func query(_ session: Session, client: FirebaseHTTPClient) async throws -> Outcome {
    var request = sessionRequest(to: session, command: "query")
    request.httpBody = Data()
    let (body, response) = try await Self.classifyingFailures {
      try await client.data(for: request, policy: StorageHTTPService.policy(for: storage))
    }
    if let statusError = HTTPStatusError.error(for: response, body: body) {
      throw Self.failure(for: statusError, response: response)
    }
    let status = Self.uploadStatus(of: response)
    if status == "final" {
      return .finished(body)
    }
    guard status != "cancelled",
          let receivedBytes = Self.receivedBytes(of: response),
          (0 ... length).contains(receivedBytes) else {
      throw Self.prematureFailure(body: body)
    }
    // When the server has received every byte, the next chunk is an empty `finalize` request.
    return .active(receivedBytes: receivedBytes, granularity: Self.granularity(of: response))
  }

  /// Sends `chunk` to `session`.
  private func send(_ chunk: Chunk, to session: Session, client: FirebaseHTTPClient,
                    report: @escaping @Sendable (Int64) -> Void) async throws -> Outcome {
    var request = sessionRequest(to: session, command: chunk.command)
    request.setValue("\(chunk.offset)", forHTTPHeaderField: "X-Goog-Upload-Offset")
    request.setValue("\(chunk.length)", forHTTPHeaderField: "Content-Length")
    if case .file = source {
      request.setValue("\(length)", forHTTPHeaderField: "X-Goog-Upload-Content-Length")
    }
    let policy = StorageHTTPService.policy(for: storage,
                                           usesBackgroundSession: usesBackgroundSession)
    let offset = chunk.offset
    let (body, response) = try await Self.classifyingFailures {
      try await client.upload(request, from: chunk.body, policy: policy) { progress in
        report(offset + progress.completedBytes)
      }
    }
    if let statusError = HTTPStatusError.error(for: response, body: body) {
      // In the resumable upload protocol, a 4xx response with an active upload status means
      // that the server expected a different offset. A 404 means that the session is gone.
      if (400 ..< 500).contains(response.statusCode), response.statusCode != 404,
         Self.uploadStatus(of: response) == "active", chunk.length > 0 {
        throw RetryableFailure(error: statusError)
      }
      throw Self.failure(for: statusError, response: response)
    }
    switch Self.uploadStatus(of: response) {
    case "final":
      return .finished(body)
    case "cancelled":
      throw Self.prematureFailure(body: body)
    default:
      let receivedBytes = Self.receivedBytes(of: response) ?? chunk.offset + chunk.length
      guard receivedBytes <= length else {
        throw Self.prematureFailure(body: body)
      }
      guard receivedBytes > chunk.previouslyReceivedBytes else {
        // The server took none of the chunk's new bytes. Ask it where to continue, as after a
        // failure, so that the upload ends when the retry time limit passes.
        throw RetryableFailure(error: Self.prematureFailure(body: body))
      }
      return .active(receivedBytes: receivedBytes, granularity: session.granularity)
    }
  }

  /// Returns a request to `session` with `command`, and the headers and settings that every
  /// request of the session shares with the `start` request.
  private func sessionRequest(to session: Session, command: String) -> URLRequest {
    var request = Self.sessionRequest(to: session, command: command,
                                      timeout: startRequest.timeoutInterval)
    request.allowsCellularAccess = startRequest.allowsCellularAccess
    return request
  }

  /// Returns a request to `session` with `command`, and the headers that every request of a
  /// session has.
  private static func sessionRequest(to session: Session, command: String,
                                     timeout: TimeInterval) -> URLRequest {
    var request = URLRequest(url: session.url)
    request.httpMethod = "PUT"
    request.timeoutInterval = timeout
    request.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
    request.setValue(command, forHTTPHeaderField: "X-Goog-Upload-Command")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    return request
  }

  /// Runs `send`, and turns the transport failures that Storage retries into
  /// `RetryableFailure`s.
  private static func classifyingFailures<Value>(_ send: () async throws -> Value) async throws
    -> Value {
    do {
      return try await send()
    } catch let error as CancellationError {
      throw error
    } catch {
      let error = error as NSError
      guard StorageHTTPService.isRetryable(error) else {
        throw error
      }
      throw RetryableFailure(error: error)
    }
  }

  /// Returns a `RetryableFailure` for an HTTP error that Storage retries, and otherwise
  /// `statusError` itself.
  private static func failure(for statusError: NSError, response: HTTPURLResponse) -> any Error {
    guard StorageHTTPService.isRetryable(statusError) else {
      return statusError
    }
    let retryAfter = response.statusCode == 503 ? RetryBackoff.retryAfterDelay(of: response) : nil
    return RetryableFailure(error: statusError, retryAfter: retryAfter)
  }

  // MARK: - Chunks

  /// A chunk of the upload, and the values of its request headers.
  struct Chunk {
    /// The offset of the chunk's first byte. It's a multiple of the server's granularity, so it
    /// can be below `previouslyReceivedBytes`.
    let offset: Int64

    /// The number of bytes that the server had received when the chunk was made. The response
    /// to the chunk must report more.
    let previouslyReceivedBytes: Int64

    let length: Int64

    /// The value of `X-Goog-Upload-Command`.
    let command: String

    let body: HTTPUploadBody

    /// A file that holds the chunk for a background session, which only uploads files.
    let temporaryFile: URL?

    func removeTemporaryFile() {
      if let temporaryFile {
        try? FileManager.default.removeItem(at: temporaryFile)
      }
    }
  }

  /// Returns the offset, length, and command of the chunk to send after the server has received
  /// the first `offset` bytes. Internal for tests.
  func chunkLayout(at offset: Int64, granularity: Int64)
    -> (offset: Int64, length: Int64, command: String) {
    var size = chunkSize
    let isWholeFile: Bool
    if case .file = source, offset == 0, size >= length {
      isWholeFile = true
    } else {
      isWholeFile = false
    }
    if !isWholeFile {
      // The chunk is read into memory.
      size = min(size, Self.maxChunkBufferSize)
    }
    var offset = offset
    if granularity > 0 {
      size = size < granularity ? granularity : size - size % granularity
      if offset < length {
        offset -= offset % granularity
      }
    }
    // Chunks without bytes would never finish the upload.
    size = max(size, 1)
    let remaining = length - offset
    guard size >= remaining || remaining - Self.minimumFinalChunkRemainder < size else {
      return (offset, size, "upload")
    }
    return (offset, remaining, remaining > 0 ? "upload, finalize" : "finalize")
  }

  /// Returns the chunk to send after the server has received the first `offset` bytes.
  private func makeChunk(at offset: Int64, granularity: Int64) throws -> Chunk {
    let layout = chunkLayout(at: offset, granularity: granularity)
    func chunk(_ body: HTTPUploadBody, temporaryFile: URL? = nil) -> Chunk {
      Chunk(offset: layout.offset, previouslyReceivedBytes: offset, length: layout.length,
            command: layout.command, body: body, temporaryFile: temporaryFile)
    }
    switch source {
    case let .data(data):
      if layout.offset == 0, layout.length == Int64(data.count) {
        return chunk(.data(data))
      }
      let start = data.startIndex + Int(layout.offset)
      return chunk(.data(data.subdata(in: start ..< start + Int(layout.length))))
    case let .file(fileURL):
      if layout.offset == 0, layout.length == length {
        return chunk(.file(fileURL))
      }
      let data = try Self.read(layout.length, bytesAt: layout.offset, of: fileURL)
      guard usesBackgroundSession else {
        return chunk(.data(data))
      }
      let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("FirebaseStorageUpload-\(UUID().uuidString)")
      try data.write(to: temporaryFile, options: .atomic)
      return chunk(.file(temporaryFile), temporaryFile: temporaryFile)
    }
  }

  /// Reads `count` bytes at `offset` of the file at `fileURL`.
  ///
  /// - Throws: The file error, or `CocoaError.fileReadCorruptFile` if the file has become
  ///   shorter since the upload started.
  private static func read(_ count: Int64, bytesAt offset: Int64, of fileURL: URL) throws -> Data {
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }
    try handle.seek(toOffset: UInt64(offset))
    let data = try handle.read(upToCount: Int(count)) ?? Data()
    guard data.count == count else {
      throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: fileURL])
    }
    return data
  }

  // MARK: - Responses

  /// Returns the value of the response's `X-Goog-Upload-Status` header.
  private static func uploadStatus(of response: HTTPURLResponse) -> String? {
    response.value(forHTTPHeaderField: "X-Goog-Upload-Status")
  }

  /// Returns the number of bytes that the server reports it has received, or `nil` if the
  /// response doesn't say.
  private static func receivedBytes(of response: HTTPURLResponse) -> Int64? {
    response.value(forHTTPHeaderField: "X-Goog-Upload-Size-Received")
      .flatMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
  }

  /// Returns the server's chunk granularity, or 0 if the response has none or it isn't a
  /// positive number.
  static func granularity(of response: HTTPURLResponse) -> Int64 {
    guard let value = response.value(forHTTPHeaderField: "X-Goog-Upload-Chunk-Granularity"),
          let granularity = Int64(value.trimmingCharacters(in: .whitespaces)),
          granularity > 0 else {
      return 0
    }
    return granularity
  }

  /// Returns the error for responses that don't follow the resumable upload protocol, so that
  /// the upload can't continue. Its domain is `HTTPStatusError.domain`, with code 501.
  static func prematureFailure(body: Data) -> NSError {
    NSError(domain: HTTPStatusError.domain, code: 501,
            userInfo: body.isEmpty ? nil : [HTTPStatusError.dataKey: body])
  }
}
