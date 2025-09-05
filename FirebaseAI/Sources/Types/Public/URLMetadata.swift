// Copyright 2025 Google LLC
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

/// Context of a single URL retrieval.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct URLMetadata: Sendable, Hashable {
  /// Status of the URL retrieval.
  public struct URLRetrievalStatus: DecodableProtoEnum, Hashable {
    enum Kind: String {
      case unspecified = "URL_RETRIEVAL_STATUS_UNSPECIFIED"
      case success = "URL_RETRIEVAL_STATUS_SUCCESS"
      case error = "URL_RETRIEVAL_STATUS_ERROR"
      case paywall = "URL_RETRIEVAL_STATUS_PAYWALL"
      case unsafe = "URL_RETRIEVAL_STATUS_UNSAFE"
    }

    /// Internal only - default value.
    static let unspecified = URLRetrievalStatus(kind: .unspecified)

    /// URL retrieval succeeded.
    public static let success = URLRetrievalStatus(kind: .success)

    /// URL retrieval failed due to an error.
    public static let error = URLRetrievalStatus(kind: .error)

    // URL retrieval failed failed because the content is behind paywall.
    public static let paywall = URLRetrievalStatus(kind: .paywall)

    // URL retrieval failed because the content is unsafe.
    public static let unsafe = URLRetrievalStatus(kind: .unsafe)

    /// Returns the raw string representation of the `URLRetrievalStatus` value.
    public let rawValue: String

    static let unrecognizedValueMessageCode =
      AILog.MessageCode.urlMetadataUnrecognizedURLRetrievalStatus
  }

  /// The URL retrieved by the ``URLContext`` tool.
  public let retrievedURL: URL?

  /// The status of the URL retrieval.
  public let retrievalStatus: URLRetrievalStatus
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension URLMetadata: Decodable {
  enum CodingKeys: String, CodingKey {
    case retrievedURL = "retrievedUrl"
    case retrievalStatus = "urlRetrievalStatus"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let retrievedURLString = try container.decodeIfPresent(String.self, forKey: .retrievedURL),
       let retrievedURL = URL(string: retrievedURLString) {
      self.retrievedURL = retrievedURL
    } else {
      retrievedURL = nil
    }
    let retrievalStatus = try container.decodeIfPresent(
      URLMetadata.URLRetrievalStatus.self, forKey: .retrievalStatus
    )

    self.retrievalStatus = AILog.safeUnwrap(
      retrievalStatus, fallback: URLMetadata.URLRetrievalStatus(kind: .unspecified)
    )
  }
}
