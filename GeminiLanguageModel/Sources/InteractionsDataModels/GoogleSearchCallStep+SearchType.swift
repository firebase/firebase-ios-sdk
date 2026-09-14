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

extension GoogleSearchCallStep {
  /// The type of search grounding enabled.
  package enum SearchType: Codable, Sendable, Equatable, Hashable {

    /// Setting this field enables web search. Only text results are returned.
    case webSearch

    /// Setting this field enables image search. Image bytes are returned.
    case imageSearch

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GoogleSearchCallStep.SearchType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .webSearch: "web_search"
    case .imageSearch: "image_search"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "web_search": self = .webSearch
    case "image_search": self = .imageSearch
    default: self = .unrecognized(rawValue)
    }
  }
}
