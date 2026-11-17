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
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// How much of a response body has arrived.
@_spi(FirebaseNetworking) public struct HTTPTransferProgress: Sendable, Equatable {
  /// The number of body bytes received so far.
  public var completedBytes: Int64

  /// The number of body bytes the response announced, or `NSURLSessionTransferSizeUnknown` (-1)
  /// if it didn't announce a length.
  public var expectedBytes: Int64

  public init(completedBytes: Int64, expectedBytes: Int64) {
    self.completedBytes = completedBytes
    self.expectedBytes = expectedBytes
  }
}

/// Where a download starts.
@_spi(FirebaseNetworking) public enum HTTPDownloadSource: Sendable {
  /// A new download of the response to a request.
  case request(URLRequest)

  /// The continuation of a cancelled download, from the resume data that its cancellation
  /// produced. The download sends the same request, headers included, as the original download.
  case resumeData(Data)
}

/// The error that a download throws when the calling task is cancelled.
@_spi(FirebaseNetworking) public struct HTTPDownloadCancellation: Error, Sendable {
  /// Data for resuming the download from where it stopped, or `nil` if it can't be resumed, for
  /// example because the server doesn't support it.
  public let resumeData: Data?

  public init(resumeData: Data?) {
    self.resumeData = resumeData
  }
}

/// The body of an upload.
@_spi(FirebaseNetworking) public enum HTTPUploadBody: Sendable {
  /// Bytes in memory.
  case data(Data)

  /// The contents of a file, which must stay in place until the upload finishes.
  case file(URL)
}

/// The transfers that a transport without its own implementation provides. They wait for the
/// whole response, so progress is reported once, when it arrives.
@_spi(FirebaseNetworking) public extension HTTPTransport {
  func data(for request: URLRequest,
            policy: HTTPRequestPolicy,
            progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (Data, HTTPURLResponse) {
    let (data, response) = try await data(for: request, policy: policy)
    progress(HTTPTransferProgress(completedBytes: Int64(data.count),
                                  expectedBytes: response.expectedContentLength))
    return (data, response)
  }

  func download(_ source: HTTPDownloadSource,
                policy: HTTPRequestPolicy,
                progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (URL, HTTPURLResponse) {
    guard case let .request(request) = source else {
      // Only `URLSessionTransport` can resume downloads.
      throw URLError(.unsupportedURL)
    }
    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await self.data(for: request, policy: policy, progress: progress)
    } catch is CancellationError {
      throw HTTPDownloadCancellation(resumeData: nil)
    }
    let fileURL = HTTPDownloadFiles.makeTemporaryFileURL()
    try data.write(to: fileURL)
    return (fileURL, response)
  }

  /// Sends `body` as the request's `httpBody`, and reports progress once the response arrives.
  func upload(_ request: URLRequest,
              from body: HTTPUploadBody,
              policy: HTTPRequestPolicy,
              progress: @escaping @Sendable (HTTPTransferProgress) -> Void) async throws
    -> (Data, HTTPURLResponse) {
    var request = request
    switch body {
    case let .data(data):
      request.httpBody = data
    case let .file(fileURL):
      request.httpBody = try Data(contentsOf: fileURL)
    }
    let bodyLength = Int64(request.httpBody?.count ?? 0)
    let result = try await data(for: request, policy: policy)
    progress(HTTPTransferProgress(completedBytes: bodyLength, expectedBytes: bodyLength))
    return result
  }
}

enum HTTPDownloadFiles {
  /// Returns a new, unused file URL in the temporary directory.
  static func makeTemporaryFileURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("FirebaseHTTPClient-download-\(UUID().uuidString)")
  }
}
