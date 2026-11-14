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

internal import FirebaseCoreInternal

/// Sends the Storage requests other than uploads and downloads: getting and updating metadata,
/// listing, deleting, and getting download URLs.
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

  private var client = FirebaseHTTPClient.shared
  private var initialRetryInterval: TimeInterval?

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

  private func configuration()
    -> (client: FirebaseHTTPClient, initialRetryInterval: TimeInterval?) {
    (client, initialRetryInterval)
  }

  /// Sends `request` for `storage` and returns the response body.
  ///
  /// - Parameters:
  ///   - request: The request, without the headers that `StorageTokenAuthorizer` adds.
  ///   - storage: The `Storage` instance that the request is for.
  ///   - maxRetryTime: The time, in seconds, after the first attempt when the last retry may
  ///     start.
  /// - Throws: The error of the last attempt: an `HTTPStatusError` for a status code of 300 or
  ///   more, the transport error, or the error of `StorageTokenAuthorizer`. If the request was
  ///   retried, the error's `userInfo` also holds the number of retries and the time they took.
  nonisolated func data(for request: URLRequest, storage: Storage,
                        maxRetryTime: TimeInterval) async throws -> Data {
    let configuration = await configuration()
    let authorizer = StorageTokenAuthorizer(storage: storage)
    // Storage has always allowed HTTP requests to loopback addresses, and to any host when it uses
    // the emulator.
    let policy = HTTPRequestPolicy(allowsInsecureHTTP: storage.usesEmulator,
                                   allowsLoopbackHTTP: true)
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
        let (body, response) = try await configuration.client.data(for: authorizedRequest,
                                                                   policy: policy)
        guard let statusError = HTTPStatusError.error(for: response, body: body) else {
          return body
        }
        failure = statusError
        if response.statusCode == 503 {
          retryAfter = RetryBackoff.retryAfterDelay(of: response)
        }
      } catch let error as CancellationError {
        throw error
      } catch {
        failure = error as NSError
      }
      guard Self.isRetryable(failure),
            let delay = backoff.nextDelay(suggestedDelay: retryAfter) else {
        throw Self.error(failure, after: backoff)
      }
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
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
  private static func error(_ error: NSError, after backoff: RetryBackoff) -> NSError {
    guard backoff.retryCount > 0 else {
      return error
    }
    var userInfo = error.userInfo
    userInfo[elapsedTimeKey] = backoff.elapsedTime
    userInfo[numberOfRetriesKey] = backoff.retryCount
    return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
  }
}
