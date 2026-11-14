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

/// Sends the requests of a `FirebaseHTTPClient`. Tests can provide their own implementation.
public protocol HTTPTransport: Sendable {
  /// Sends `request` and returns the response body and the response, whatever the status code.
  ///
  /// - Throws: The transport error, usually a `URLError`, or `CancellationError` if the calling
  ///   task is cancelled.
  func data(for request: URLRequest,
            policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse)

  /// Sends `request` like `data(for:policy:)`, and calls `progress` as the response body
  /// arrives.
  func data(for request: URLRequest,
            policy: HTTPRequestPolicy,
            progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (Data, HTTPURLResponse)

  /// Downloads the response body to a new temporary file, whatever the status code, and calls
  /// `progress` as it arrives. The caller owns the file and must move or delete it.
  ///
  /// - Throws: The transport error, usually a `URLError`, or `HTTPDownloadCancellation` if the
  ///   calling task is cancelled.
  func download(_ source: HTTPDownloadSource,
                policy: HTTPRequestPolicy,
                progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (URL, HTTPURLResponse)
}

/// Sends requests on one ephemeral `URLSession` that requires TLS 1.2 or later.
///
/// Redirects follow `RedirectPolicy`, using the `HTTPRequestPolicy` of each request.
public final class URLSessionTransport: HTTPTransport {
  /// The session. Internal for tests.
  let session: URLSession

  private let tasks: SessionTasks

  /// The number of registrations that the session delegate holds for tasks in flight. Internal
  /// for tests.
  var trackedTaskCount: Int {
    tasks.count
  }

  /// Creates a transport with its own session.
  ///
  /// - Parameter configure: Adjusts the ephemeral session configuration before the session is
  ///   created. Tests use it to install a `URLProtocol`.
  public init(configure: (URLSessionConfiguration) -> Void = { _ in }) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
    configure(configuration)
    let tasks = SessionTasks()
    let delegateQueue = OperationQueue()
    delegateQueue.name = "com.google.firebase.URLSessionTransport"
    delegateQueue.maxConcurrentOperationCount = 1
    self.tasks = tasks
    session = URLSession(configuration: configuration, delegate: tasks,
                         delegateQueue: delegateQueue)
  }

  deinit {
    // The session keeps its delegate until it's invalidated. Requests in flight keep the
    // transport alive, so none can be using the session at this point.
    session.finishTasksAndInvalidate()
  }

  public func data(for request: URLRequest,
                   policy: HTTPRequestPolicy) async throws -> (Data, HTTPURLResponse) {
    try Task.checkCancellation()
    let cancellation = TaskCancellation()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let tasks = self.tasks
        let task = session.dataTask(with: request) { data, response, error in
          if let taskIdentifier = cancellation.taskIdentifier {
            tasks.unregister(taskIdentifier)
          }
          if let error {
            continuation.resume(throwing: cancellation.isCancelled ? CancellationError() : error)
          } else if let response = response as? HTTPURLResponse {
            continuation.resume(returning: (data ?? Data(), response))
          } else {
            continuation.resume(throwing: URLError(.badServerResponse))
          }
        }
        tasks.register(task, request: request, policy: policy)
        cancellation.start(task)
      }
    } onCancel: {
      cancellation.cancel()
    }
  }

  /// Sends `request` and returns as soon as the response headers arrive, whatever the status
  /// code. The response body streams through the returned bytes.
  ///
  /// - Throws: The transport error, usually a `URLError`, or `CancellationError` if the calling
  ///   task is cancelled before the response arrives.
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public func bytes(for request: URLRequest,
                    policy: HTTPRequestPolicy) async throws
    -> (URLSession.AsyncBytes, HTTPURLResponse) {
    // `URLSession` creates this task itself, so its redirects go through a task delegate.
    let redirects = TaskRedirects(request: request, policy: policy)
    let bytes: URLSession.AsyncBytes
    let response: URLResponse
    do {
      (bytes, response) = try await session.bytes(for: request, delegate: redirects)
    } catch let error as URLError where error.code == .cancelled && Task.isCancelled {
      throw CancellationError()
    }
    guard let response = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }
    return (bytes, response)
  }

  public func data(for request: URLRequest,
                   policy: HTTPRequestPolicy,
                   progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (Data, HTTPURLResponse) {
    let transfer = TaskTransfer(kind: .data, progress: progress)
    let (body, response) = try await run(transfer, request: request, policy: policy) { session in
      session.dataTask(with: request)
    }
    guard case let .data(data) = body else {
      throw URLError(.badServerResponse)
    }
    return (data, response)
  }

  public func download(_ source: HTTPDownloadSource,
                       policy: HTTPRequestPolicy,
                       progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (URL, HTTPURLResponse) {
    var request: URLRequest?
    var resumeData: Data?
    switch source {
    case let .request(sourceRequest):
      request = sourceRequest
    case let .resumeData(sourceResumeData):
      resumeData = sourceResumeData
    }
    let transfer = TaskTransfer(kind: .download(resumeData: resumeData), progress: progress)
    let (body, response) = try await run(transfer, request: request, policy: policy) { session in
      switch source {
      case let .request(request):
        return session.downloadTask(with: request)
      case let .resumeData(resumeData):
        return session.downloadTask(withResumeData: resumeData)
      }
    }
    guard case let .file(fileURL) = body else {
      throw URLError(.badServerResponse)
    }
    return (fileURL, response)
  }

  /// Runs the task that `makeTask` creates, routing its delegate callbacks to `transfer`.
  ///
  /// - Parameter request: The request the task sends, or `nil` to take it from the task, as for
  ///   a resumed download.
  private func run(_ transfer: TaskTransfer,
                   request: URLRequest?,
                   policy: HTTPRequestPolicy,
                   makeTask: (URLSession) -> URLSessionTask) async throws
    -> (TaskTransfer.Body, HTTPURLResponse) {
    if Task.isCancelled {
      throw transfer.cancellationError
    }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        transfer.setContinuation(continuation)
        let task = makeTask(session)
        if let redirectedRequest = request ?? task.currentRequest ?? task.originalRequest {
          tasks.register(task, request: redirectedRequest, policy: policy)
        }
        tasks.register(task, transfer: transfer)
        transfer.start(task)
      }
    } onCancel: {
      transfer.cancel()
    }
  }
}

/// The session delegate. It applies the redirect policy of each task, and passes the progress
/// and results of transfers to their `TaskTransfer`.
private final class SessionTasks: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate,
  URLSessionDownloadDelegate, Sendable {
  private let redirects = UnfairLock<[Int: TaskRedirects]>([:])
  private let transfers = UnfairLock<[Int: TaskTransfer]>([:])

  func register(_ task: URLSessionTask, request: URLRequest, policy: HTTPRequestPolicy) {
    let taskIdentifier = task.taskIdentifier
    let taskRedirects = TaskRedirects(request: request, policy: policy)
    redirects.withLock { $0[taskIdentifier] = taskRedirects }
  }

  func register(_ task: URLSessionTask, transfer: TaskTransfer) {
    let taskIdentifier = task.taskIdentifier
    transfers.withLock { $0[taskIdentifier] = transfer }
  }

  func unregister(_ taskIdentifier: Int) {
    redirects.withLock { $0[taskIdentifier] = nil }
    transfers.withLock { $0[taskIdentifier] = nil }
  }

  /// The number of registrations for redirects and transfers.
  var count: Int {
    redirects.withLock { $0.count } + transfers.withLock { $0.count }
  }

  private func transfer(for task: URLSessionTask) -> TaskTransfer? {
    let taskIdentifier = task.taskIdentifier
    return transfers.withLock { $0[taskIdentifier] }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    let taskIdentifier = task.taskIdentifier
    if let taskRedirects = redirects.withLock({ $0[taskIdentifier] }) {
      completionHandler(taskRedirects.redirect(to: request))
    } else if let current = task.currentRequest ?? task.originalRequest {
      completionHandler(RedirectPolicy.request(redirecting: current, to: request,
                                               policy: HTTPRequestPolicy()))
    } else {
      completionHandler(request)
    }
  }

  // Only transfers get the callbacks below. Tasks with completion handlers don't.

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    transfer(for: dataTask)?.didReceive(data, task: dataTask)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    transfer(for: downloadTask)?.didWrite(totalBytesWritten: totalBytesWritten,
                                          totalBytesExpectedToWrite: totalBytesExpectedToWrite)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    transfer(for: downloadTask)?.didFinishDownloading(to: location)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  didCompleteWithError error: (any Error)?) {
    let taskIdentifier = task.taskIdentifier
    guard let transfer = transfers.withLock({ $0.removeValue(forKey: taskIdentifier) }) else {
      return
    }
    redirects.withLock { $0[taskIdentifier] = nil }
    transfer.didComplete(response: task.response, error: error)
  }
}

/// Applies `RedirectPolicy` to the redirects of one task.
///
/// `SessionTasks` keeps one for each data task. Streaming tasks, which `URLSession` creates
/// itself, use one as their task delegate.
private final class TaskRedirects: NSObject, URLSessionTaskDelegate, Sendable {
  private let policy: HTTPRequestPolicy

  /// The request that the task is currently sending.
  private let currentRequest: UnfairLock<URLRequest>

  init(request: URLRequest, policy: HTTPRequestPolicy) {
    self.policy = policy
    currentRequest = UnfairLock(request)
  }

  /// Returns the request to send to the redirect target, or `nil` to not follow the redirect.
  func redirect(to proposed: URLRequest) -> URLRequest? {
    let policy = self.policy
    return currentRequest.withLock { current -> URLRequest? in
      let redirect = RedirectPolicy.request(redirecting: current, to: proposed, policy: policy)
      if let redirect {
        current = redirect
      }
      return redirect
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    completionHandler(redirect(to: request))
  }
}

/// Connects the cancellation of a Swift task to a `URLSessionTask` that may not exist yet.
private final class TaskCancellation: Sendable {
  private struct State {
    /// Weak, because the task's completion handler holds this object. `URLSession` keeps the
    /// task alive until it completes.
    weak var task: URLSessionTask?
    var taskIdentifier: Int?
    var isCancelled = false
  }

  private let state = UnfairLock(State())

  var isCancelled: Bool {
    state.withLock { $0.isCancelled }
  }

  /// The identifier of the task, once it's started.
  var taskIdentifier: Int? {
    state.withLock { $0.taskIdentifier }
  }

  /// Resumes `task`, or cancels it if the Swift task was already cancelled. Either way, the task
  /// calls its completion handler.
  func start(_ task: URLSessionTask) {
    let isCancelled = state.withLock { state -> Bool in
      state.task = task
      state.taskIdentifier = task.taskIdentifier
      return state.isCancelled
    }
    if isCancelled {
      task.cancel()
    } else {
      task.resume()
    }
  }

  func cancel() {
    let task = state.withLock { state -> URLSessionTask? in
      state.isCancelled = true
      return state.task
    }
    task?.cancel()
  }
}

/// Collects the body of one data or download task, reports its progress, and completes the
/// caller's continuation.
///
/// Internal so tests can replay orders of `URLSession` callbacks that a `URLProtocol` can't
/// produce.
final class TaskTransfer: Sendable {
  enum Kind {
    case data
    /// A download, and the resume data it continues from, if any.
    case download(resumeData: Data?)
  }

  enum Body {
    case data(Data)
    case file(URL)
  }

  private struct State {
    /// Weak, because the session delegate holds this object while the task runs.
    weak var task: URLSessionTask?
    var isCancelled = false
    /// Whether a cancelled download waits for its resume data to complete the continuation.
    var awaitsResumeData = false
    var continuation: CheckedContinuation<(Body, HTTPURLResponse), any Error>?
    var data = Data()
    var fileURL: URL?
    var fileError: (any Error)?
  }

  let kind: Kind
  private let progress: @Sendable (HTTPTransferProgress) -> Void
  private let state = UnfairLock(State())

  init(kind: Kind, progress: @escaping @Sendable (HTTPTransferProgress) -> Void) {
    self.kind = kind
    self.progress = progress
  }

  /// The error to throw when the calling task is cancelled before the transfer starts. A
  /// download hands back the resume data it was given, which is still valid.
  var cancellationError: any Error {
    switch kind {
    case .data: return CancellationError()
    case let .download(resumeData): return HTTPDownloadCancellation(resumeData: resumeData)
    }
  }

  func setContinuation(_ continuation: CheckedContinuation<(Body, HTTPURLResponse), any Error>) {
    state.withLock { $0.continuation = continuation }
  }

  /// Resumes `task`, or cancels it if the calling task was already cancelled.
  func start(_ task: URLSessionTask) {
    let isCancelled = state.withLock { state -> Bool in
      state.task = task
      return state.isCancelled
    }
    if isCancelled {
      cancel(task)
    } else {
      task.resume()
    }
  }

  func cancel() {
    let task = state.withLock { state -> URLSessionTask? in
      state.isCancelled = true
      return state.task
    }
    if let task {
      cancel(task)
    }
  }

  private func cancel(_ task: URLSessionTask) {
    guard let downloadTask = task as? URLSessionDownloadTask else {
      task.cancel()
      return
    }
    state.withLock { $0.awaitsResumeData = true }
    downloadTask.cancel(byProducingResumeData: { resumeData in
      self.finish(.failure(HTTPDownloadCancellation(resumeData: resumeData)))
    })
  }

  func didReceive(_ data: Data, task: URLSessionDataTask) {
    let receivedBytes = state.withLock { state -> Int64 in
      state.data.append(data)
      return Int64(state.data.count)
    }
    progress(HTTPTransferProgress(completedBytes: receivedBytes,
                                  expectedBytes: task.countOfBytesExpectedToReceive))
  }

  func didWrite(totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    progress(HTTPTransferProgress(completedBytes: totalBytesWritten,
                                  expectedBytes: totalBytesExpectedToWrite))
  }

  /// Moves the downloaded file out of the way, because `URLSession` deletes it once this
  /// callback returns.
  func didFinishDownloading(to location: URL) {
    let fileURL = HTTPDownloadFiles.makeTemporaryFileURL()
    do {
      try FileManager.default.moveItem(at: location, to: fileURL)
      state.withLock { $0.fileURL = fileURL }
    } catch {
      state.withLock { $0.fileError = error }
    }
  }

  /// The file that `didFinishDownloading(to:)` moved the download to. Internal for tests.
  var downloadedFileURL: URL? {
    state.withLock { $0.fileURL }
  }

  /// Completes the transfer with the task's outcome. `URLSession` calls this last for every task.
  func didComplete(response: URLResponse?, error: (any Error)?) {
    let (isCancelled, awaitsResumeData, data, fileURL, fileError) = state.withLock {
      ($0.isCancelled, $0.awaitsResumeData, $0.data, $0.fileURL, $0.fileError)
    }
    var result: Result<(Body, HTTPURLResponse), any Error>?
    if let error {
      if !isCancelled {
        result = .failure(error)
      } else if !awaitsResumeData {
        // A cancelled data task, or a download that ended before it was asked for resume data.
        result = .failure(cancellation(endingWith: error))
      }
      // Otherwise the cancelled download completes when its resume data arrives.
    } else if let response = response as? HTTPURLResponse {
      switch kind {
      case .data:
        result = .success((.data(data), response))
      case .download:
        result = fileURL.map { .success((.file($0), response)) }
          ?? .failure(fileError ?? URLError(.cannotCreateFile))
      }
    } else {
      result = .failure(URLError(.badServerResponse))
    }
    // Only a successful result hands the downloaded file to the caller. Otherwise no one can
    // receive it, for example when the download was cancelled after its body arrived.
    var deliversFile = false
    if case .success((.file(_), _))? = result {
      deliversFile = true
    }
    if let fileURL, !deliversFile {
      try? FileManager.default.removeItem(at: fileURL)
    }
    if let result {
      finish(result)
    }
  }

  /// Returns the error for a task that ended with `error` after the calling task was cancelled,
  /// before a download was asked for resume data.
  private func cancellation(endingWith error: any Error) -> any Error {
    switch kind {
    case .data:
      return CancellationError()
    case .download:
      return HTTPDownloadCancellation(resumeData: (error as? URLError)?.downloadTaskResumeData)
    }
  }

  /// Completes the continuation the first time it's called. Later results are dropped, and a
  /// downloaded file that no one will receive is deleted.
  private func finish(_ result: Result<(Body, HTTPURLResponse), any Error>) {
    let continuation = state.withLock { state in
      defer { state.continuation = nil }
      return state.continuation
    }
    if let continuation {
      continuation.resume(with: result)
    } else if case let .success((.file(fileURL), _)) = result {
      try? FileManager.default.removeItem(at: fileURL)
    }
  }
}
