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

/// Sends the authorized Storage requests: getting and updating metadata, listing, deleting,
/// getting download URLs, downloads, and the request that opens a resumable upload session.
/// `StorageResumableUpload` sends the rest of an upload's requests, which carry no credentials.
///
/// Every attempt of a request gets fresh tokens from `StorageTokenAuthorizer`. Failures that are
/// likely to be temporary are retried with exponential backoff until the retry time limit has
/// passed.
actor StorageHTTPService {
  static let shared = StorageHTTPService()

  /// The `userInfo` keys for the number of retries and the seconds since the first attempt. Storage
  /// errors have always had them when a request was retried.
  static let numberOfRetriesKey = "kGTMSessionFetcherNumberOfRetriesDoneKey"
  static let elapsedTimeKey = "kGTMSessionFetcherElapsedIntervalWithRetriesKey"

  /// The largest error body that is read from a download's file into the error.
  static let maxDownloadErrorBodyLength = 20000

  private var client = FirebaseHTTPClient.shared
  private var initialRetryInterval: TimeInterval?
  private var setupWaiter: (@Sendable () async -> Void)?

  /// Sends requests through `transport` instead of the network, or through the network again when
  /// `transport` is `nil`. For unit tests.
  ///
  /// `transport` gets each request after `StorageTokenAuthorizer` has added its headers.
  func updateTestTransport(_ transport: (any HTTPTransport)?) {
    client = transport.map { FirebaseHTTPClient(transport: $0) } ?? .shared
  }

  /// Replaces the random 1 to 2 second wait before the first retry, or restores it when
  /// `interval` is `nil`. For unit tests.
  func updateInitialRetryIntervalForTesting(_ interval: TimeInterval?) {
    initialRetryInterval = interval
  }

  /// Makes `waitForSetup()` call `waiter`, so tests can hold a download's setup. For unit tests.
  func updateSetupWaiterForTesting(_ waiter: (@Sendable () async -> Void)?) {
    setupWaiter = waiter
  }

  /// Returns after the waiter that tests installed, if any, returns.
  func waitForSetup() async {
    await setupWaiter?()
  }

  /// The client that sends requests, and the wait before the first retry that tests set, if any.
  func configuration() -> (client: FirebaseHTTPClient, initialRetryInterval: TimeInterval?) {
    (client, initialRetryInterval)
  }

  /// Returns the policy for the requests of `storage`. Storage has always allowed HTTP requests
  /// to loopback addresses, and to any host when it uses the emulator.
  static func policy(for storage: Storage,
                     usesBackgroundSession: Bool = false) -> HTTPRequestPolicy {
    HTTPRequestPolicy(allowsInsecureHTTP: storage.usesEmulator, allowsLoopbackHTTP: true,
                      usesBackgroundSession: usesBackgroundSession)
  }

  /// Sends `request` for `storage` and returns the response body.
  ///
  /// - Parameters:
  ///   - request: The request, without the headers that `StorageTokenAuthorizer` adds.
  ///   - storage: The `Storage` instance that the request is for.
  ///   - maxRetryTime: The time, in seconds, after the first attempt when the last retry may
  ///     start.
  ///   - progress: Called as the response body arrives. A retry starts over from zero.
  /// - Throws: The error of the last attempt: an `HTTPStatusError` for a status code of 300 or
  ///   more, the transport error, or the error of `StorageTokenAuthorizer`. If the request was
  ///   retried, the error's `userInfo` also holds the number of retries and the time they took.
  ///   Throws `CancellationError` if the calling task is cancelled.
  nonisolated func data(for request: URLRequest, storage: Storage,
                        maxRetryTime: TimeInterval,
                        progress: (@Sendable (HTTPTransferProgress) -> Void)? = nil) async throws
    -> Data {
    try await send(request, storage: storage, maxRetryTime: maxRetryTime) {
      authorizedRequest, client, policy in
      let body: Data
      let response: HTTPURLResponse
      if let progress {
        (body, response) = try await client.data(for: authorizedRequest, policy: policy,
                                                 progress: progress)
      } else {
        (body, response) = try await client.data(for: authorizedRequest, policy: policy)
      }
      try Self.checkStatus(of: response, body: body)
      return body
    }
  }

  /// Sends `request` like `data(for:storage:maxRetryTime:progress:)`, and also returns the
  /// response, for its headers.
  nonisolated func dataAndResponse(for request: URLRequest, storage: Storage,
                                   maxRetryTime: TimeInterval) async throws
    -> (Data, HTTPURLResponse) {
    try await send(request, storage: storage, maxRetryTime: maxRetryTime) {
      authorizedRequest, client, policy in
      let (body, response) = try await client.data(for: authorizedRequest, policy: policy)
      try Self.checkStatus(of: response, body: body)
      return (body, response)
    }
  }

  /// Downloads the response body of `request` for `storage` to a new temporary file, and returns
  /// the file. The caller owns the file and must move or delete it.
  ///
  /// - Parameters:
  ///   - request: The request, without the headers that `StorageTokenAuthorizer` adds.
  ///   - resumeData: Data for resuming a paused download. The first attempt resumes the download
  ///     with the request and headers saved in it. If the server rejects those credentials with
  ///     HTTP 401 or 403, the download starts over with fresh tokens. Retries start over too.
  ///   - storage: The `Storage` instance that the request is for.
  ///   - maxRetryTime: The time, in seconds, after the first attempt when the last retry may
  ///     start.
  ///   - progress: Called as the response body arrives.
  /// - Throws: The errors of `data(for:storage:maxRetryTime:progress:)`, with the start of an
  ///   error body in the `HTTPStatusError`. Throws `HTTPDownloadCancellation`, with resume data
  ///   when the download can be resumed, if the calling task is cancelled.
  nonisolated func download(for request: URLRequest, resumeData: Data?, storage: Storage,
                            maxRetryTime: TimeInterval,
                            progress: @escaping @Sendable (HTTPTransferProgress) -> Void)
    async throws -> URL {
    // Only the first attempt resumes the download.
    var pendingResumeData = resumeData
    return try await send(request, storage: storage, maxRetryTime: maxRetryTime) {
      authorizedRequest, client, policy in
      let resumeData = pendingResumeData
      pendingResumeData = nil
      var (fileURL, response) = try await client.download(
        resumeData.map { .resumeData($0) } ?? .request(authorizedRequest),
        policy: policy, progress: progress
      )
      if resumeData != nil, [401, 403].contains(response.statusCode) {
        // The credentials saved with the paused download were rejected, for example because
        // they expired. Start over with fresh ones.
        try? FileManager.default.removeItem(at: fileURL)
        (fileURL, response) = try await client.download(.request(authorizedRequest),
                                                        policy: policy, progress: progress)
      }
      if response.statusCode >= 300 {
        let body = Self.errorBody(ofDownloadAt: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        try Self.checkStatus(of: response, body: body)
      }
      return fileURL
    }
  }

  /// Sends `request` with `attempt` until an attempt succeeds, fails in a way that isn't retried,
  /// or the retry time limit passes.
  ///
  /// - Parameter attempt: Sends the authorized request. It throws `StatusFailure` for HTTP
  ///   errors.
  private nonisolated func send<Value>(_ request: URLRequest, storage: Storage,
                                       maxRetryTime: TimeInterval,
                                       attempt: (URLRequest, FirebaseHTTPClient,
                                                 HTTPRequestPolicy) async throws -> Value)
    async throws -> Value {
    let configuration = await configuration()
    let authorizer = StorageTokenAuthorizer(storage: storage)
    let policy = Self.policy(for: storage)
    var backoff = RetryBackoff(
      maxRetryTime: maxRetryTime,
      maxInterval: Storage.computeRetryInterval(fromRetryTime: maxRetryTime),
      initialInterval: configuration.initialRetryInterval ?? RetryBackoff.randomInitialInterval()
    )
    while true {
      // Tokens can expire while a request is retried, so authorize every attempt again.
      let authorizedRequest = try await authorizer.authorize(request)
      let failure: NSError
      var retryAfter: TimeInterval?
      do {
        return try await attempt(authorizedRequest, configuration.client, policy)
      } catch let error as CancellationError {
        throw error
      } catch let error as HTTPDownloadCancellation {
        throw error
      } catch let error as StatusFailure {
        failure = error.error
        retryAfter = error.retryAfter
      } catch {
        failure = error as NSError
      }
      guard Self.isRetryable(failure),
            let delay = backoff.nextDelay(suggestedDelay: retryAfter) else {
        throw Self.error(failure, after: backoff)
      }
      try await RetryBackoff.sleep(for: delay)
    }
  }

  /// An HTTP error, and the wait that the response asked for before a retry.
  private struct StatusFailure: Error {
    let error: NSError
    let retryAfter: TimeInterval?
  }

  /// Throws a `StatusFailure` if `response` has a status code of 300 or more.
  private static func checkStatus(of response: HTTPURLResponse, body: Data) throws {
    guard let statusError = HTTPStatusError.error(for: response, body: body) else {
      return
    }
    let retryAfter = response.statusCode == 503 ? RetryBackoff.retryAfterDelay(of: response) : nil
    throw StatusFailure(error: statusError, retryAfter: retryAfter)
  }

  /// Returns the error body that a download wrote to `fileURL`, or empty data if the body is
  /// empty or larger than `maxDownloadErrorBodyLength`.
  private static func errorBody(ofDownloadAt fileURL: URL) -> Data {
    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    guard size > 0, size <= maxDownloadErrorBodyLength else {
      return Data()
    }
    return (try? Data(contentsOf: fileURL)) ?? Data()
  }

  /// Whether Storage retries a request that failed with `error`.
  ///
  /// Storage retries the HTTP status codes 408, 502, 503, and 504, timeouts, lost connections,
  /// and requests that failed because the device is offline.
  static func isRetryable(_ error: NSError) -> Bool {
    switch error.domain {
    case HTTPStatusError.domain:
      return [408, 502, 503, 504].contains(error.code)
    case NSURLErrorDomain
      where [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(error.code):
      return true
    default:
      // Storage has always recognized being offline by the error code alone.
      return error.code == NSURLErrorNotConnectedToInternet
    }
  }

  /// Returns `error` with the number of retries and the time they took in its `userInfo`, if
  /// `backoff` allowed any retries.
  static func error(_ error: NSError, after backoff: RetryBackoff) -> NSError {
    guard backoff.retryCount > 0 else {
      return error
    }
    var userInfo = error.userInfo
    userInfo[elapsedTimeKey] = backoff.elapsedTime
    userInfo[numberOfRetriesKey] = backoff.retryCount
    return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
  }
}
