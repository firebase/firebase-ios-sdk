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

/// The arguments to pass to the Google Maps tool.
package struct GoogleMapsCallArguments: Codable, Sendable, Equatable, Hashable {

  /// The queries to be executed.
  package let queries: [String]?

  /// Creates a new `GoogleMapsCallArguments`.
  ///
  /// - Parameters:
  ///   - queries: The queries to be executed.
  package init(
    queries: [String]? = nil
  ) {
    self.queries = queries
  }
  enum CodingKeys: String, CodingKey {
    case queries = "queries"
  }
}
