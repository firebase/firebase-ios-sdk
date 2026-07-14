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

extension AgentPlatform.AuthConfigApiKeyConfig {
  /// Optional. The location of the API key.
  public enum HttpElementLocation: Codable, Sendable, Equatable, Hashable {
    /// Element is in the HTTP request query.
    case query
    
    /// Element is in the HTTP request header.
    case header
    
    /// Element is in the HTTP request path.
    case path
    
    /// Element is in the HTTP request body.
    case body
    
    /// Element is in the HTTP request cookie.
    case cookie
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.AuthConfigApiKeyConfig.HttpElementLocation: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .query: "HTTP_IN_QUERY"
    case .header: "HTTP_IN_HEADER"
    case .path: "HTTP_IN_PATH"
    case .body: "HTTP_IN_BODY"
    case .cookie: "HTTP_IN_COOKIE"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "HTTP_IN_QUERY": self = .query
    case "HTTP_IN_HEADER": self = .header
    case "HTTP_IN_PATH": self = .path
    case "HTTP_IN_BODY": self = .body
    case "HTTP_IN_COOKIE": self = .cookie
    default: self = .unrecognized(rawValue)
    }
  }
}