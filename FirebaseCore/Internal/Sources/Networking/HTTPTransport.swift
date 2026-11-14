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
}

/// Sends requests on one ephemeral `URLSession` that requires TLS 1.2 or later.
///
/// Redirects follow `RedirectPolicy`, using the `HTTPRequestPolicy` of each request.
public final class URLSessionTransport: HTTPTransport {
  /// The session. Internal for tests.
  let session: URLSession

  private let tasks: SessionTasks

  /// The number of data tasks whose redirects the session delegate tracks. Internal for tests.
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
}

/// The session delegate. It applies the redirect policy of each data task.
private final class SessionTasks: NSObject, URLSessionTaskDelegate, Sendable {
  private let redirects = UnfairLock<[Int: TaskRedirects]>([:])

  func register(_ task: URLSessionTask, request: URLRequest, policy: HTTPRequestPolicy) {
    let taskIdentifier = task.taskIdentifier
    let taskRedirects = TaskRedirects(request: request, policy: policy)
    redirects.withLock { $0[taskIdentifier] = taskRedirects }
  }

  func unregister(_ taskIdentifier: Int) {
    redirects.withLock { $0[taskIdentifier] = nil }
  }

  /// The number of registered tasks.
  var count: Int {
    redirects.withLock { $0.count }
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
