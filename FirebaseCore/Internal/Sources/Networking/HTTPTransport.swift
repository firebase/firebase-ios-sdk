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
}

/// The session delegate. It applies the redirect policy of each task.
private final class SessionTasks: NSObject, URLSessionTaskDelegate, Sendable {
  private struct Entry {
    /// The request that the task is currently sending.
    var request: URLRequest
    let policy: HTTPRequestPolicy
  }

  private let entries = UnfairLock<[Int: Entry]>([:])

  func register(_ task: URLSessionTask, request: URLRequest, policy: HTTPRequestPolicy) {
    let taskIdentifier = task.taskIdentifier
    entries.withLock { $0[taskIdentifier] = Entry(request: request, policy: policy) }
  }

  func unregister(_ taskIdentifier: Int) {
    entries.withLock { $0[taskIdentifier] = nil }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    let taskIdentifier = task.taskIdentifier
    let fallbackRequest = task.currentRequest ?? task.originalRequest
    let redirect = entries.withLock { entries -> URLRequest? in
      guard let current = entries[taskIdentifier]?.request ?? fallbackRequest else {
        return request
      }
      let policy = entries[taskIdentifier]?.policy ?? HTTPRequestPolicy()
      let redirect = RedirectPolicy.request(redirecting: current, to: request, policy: policy)
      if let redirect {
        entries[taskIdentifier]?.request = redirect
      }
      return redirect
    }
    completionHandler(redirect)
  }
}

/// Connects the cancellation of a Swift task to a `URLSessionTask` that may not exist yet.
private final class TaskCancellation: Sendable {
  private struct State {
    var task: URLSessionTask?
    var isCancelled = false
  }

  private let state = UnfairLock(State())

  var isCancelled: Bool {
    state.withLock { $0.isCancelled }
  }

  var taskIdentifier: Int? {
    state.withLock { $0.task?.taskIdentifier }
  }

  /// Resumes `task`, or cancels it if the Swift task was already cancelled. Either way, the task
  /// calls its completion handler.
  func start(_ task: URLSessionTask) {
    let isCancelled = state.withLock { state -> Bool in
      state.task = task
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
