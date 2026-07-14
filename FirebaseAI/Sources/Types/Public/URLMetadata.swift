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

/// Metadata for a single URL retrieved by the ``Tool/urlContext()`` tool.
public struct URLMetadata: Sendable, Hashable {
  /// Status of the URL retrieval.
  public struct URLRetrievalStatus: ProtoEnum, Hashable {
    enum Kind: String {
      case unspecified = "URL_RETRIEVAL_STATUS_UNSPECIFIED"
      case success = "URL_RETRIEVAL_STATUS_SUCCESS"
      case error = "URL_RETRIEVAL_STATUS_ERROR"
      case paywall = "URL_RETRIEVAL_STATUS_PAYWALL"
      case unsafe = "URL_RETRIEVAL_STATUS_UNSAFE"
    }

    /// Internal only - Unspecified retrieval status.
    static let unspecified = URLRetrievalStatus(kind: .unspecified)

    /// The URL retrieval was successful.
    public static let success = URLRetrievalStatus(kind: .success)

    /// The URL retrieval failed.
    public static let error = URLRetrievalStatus(kind: .error)

    /// The URL retrieval failed because the content is behind a paywall.
    public static let paywall = URLRetrievalStatus(kind: .paywall)

    /// The URL retrieval failed because the content is unsafe.
    public static let unsafe = URLRetrievalStatus(kind: .unsafe)

    /// Returns the raw string representation of the `URLRetrievalStatus` value.
    public let rawValue: String

    static let unrecognizedValueMessageCode =
      AILog.MessageCode.urlMetadataUnrecognizedURLRetrievalStatus
  }

  /// The retrieved URL.
  public let retrievedURL: URL?

  /// The status of the URL retrieval.
  public let retrievalStatus: URLRetrievalStatus
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension URLMetadata.URLRetrievalStatus {
  func toGoogleAI() -> GoogleAI.UrlMetadata.UrlRetrievalStatus {
    GoogleAI.UrlMetadata.UrlRetrievalStatus(rawValue: rawValue) ?? .unspecified
  }

  func toAgentPlatform() -> AgentPlatform.UrlMetadata.UrlRetrievalStatus {
    AgentPlatform.UrlMetadata.UrlRetrievalStatus(rawValue: rawValue) ?? .unspecified
  }

  init(fromGoogleAI status: GoogleAI.UrlMetadata.UrlRetrievalStatus) {
    self.rawValue = status.rawValue
  }

  init(fromAgentPlatform status: AgentPlatform.UrlMetadata.UrlRetrievalStatus) {
    self.rawValue = status.rawValue
  }
}

extension URLMetadata {
  package func toGoogleAI() -> GoogleAI.UrlMetadata {
    GoogleAI.UrlMetadata(
      retrievedUrl: retrievedURL?.absoluteString,
      urlRetrievalStatus: retrievalStatus.toGoogleAI()
    )
  }

  package func toAgentPlatform() -> AgentPlatform.UrlMetadata {
    AgentPlatform.UrlMetadata(
      retrievedUrl: retrievedURL?.absoluteString,
      urlRetrievalStatus: retrievalStatus.toAgentPlatform()
    )
  }

  package init(fromGoogleAI metadata: GoogleAI.UrlMetadata) {
    self.retrievedURL = metadata.retrievedUrl.flatMap { URL(string: $0) }
    self.retrievalStatus = metadata.urlRetrievalStatus.map { URLRetrievalStatus(fromGoogleAI: $0) } ?? .unspecified
  }

  package init(fromAgentPlatform metadata: AgentPlatform.UrlMetadata) {
    self.retrievedURL = metadata.retrievedUrl.flatMap { URL(string: $0) }
    self.retrievalStatus = metadata.urlRetrievalStatus.map { URLRetrievalStatus(fromAgentPlatform: $0) } ?? .unspecified
  }
}
