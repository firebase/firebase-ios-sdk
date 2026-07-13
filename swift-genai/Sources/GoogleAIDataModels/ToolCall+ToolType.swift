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

extension GoogleAI.ToolCall {
  /// Required. The type of tool that was called.
  package enum ToolType: Codable, Sendable, Equatable, Hashable {
    /// Google search tool, maps to Tool.google_search.search_types.web_search.
    case googleSearchWeb
    
    /// Image search tool, maps to Tool.google_search.search_types.image_search.
    case googleSearchImage
    
    /// URL context tool, maps to Tool.url_context.
    case urlContext
    
    /// Google maps tool, maps to Tool.google_maps.
    case googleMaps
    
    /// File search tool, maps to Tool.file_search.
    case fileSearch
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleAI.ToolCall.ToolType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .googleSearchWeb: "GOOGLE_SEARCH_WEB"
    case .googleSearchImage: "GOOGLE_SEARCH_IMAGE"
    case .urlContext: "URL_CONTEXT"
    case .googleMaps: "GOOGLE_MAPS"
    case .fileSearch: "FILE_SEARCH"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "GOOGLE_SEARCH_WEB": self = .googleSearchWeb
    case "GOOGLE_SEARCH_IMAGE": self = .googleSearchImage
    case "URL_CONTEXT": self = .urlContext
    case "GOOGLE_MAPS": self = .googleMaps
    case "FILE_SEARCH": self = .fileSearch
    default: self = .unrecognized(rawValue)
    }
  }
}