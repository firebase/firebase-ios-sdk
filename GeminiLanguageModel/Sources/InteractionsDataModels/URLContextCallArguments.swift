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

/// The arguments to pass to the URL context.
package struct URLContextCallArguments: Codable, Sendable, Equatable, Hashable {

  /// The URLs to fetch.
  package let urls: [String]?

  /// Creates a new `URLContextCallArguments`.
  ///
  /// - Parameters:
  ///   - urls: The URLs to fetch.
  package init(
    urls: [String]? = nil
  ) {
    self.urls = urls
  }
  enum CodingKeys: String, CodingKey {
    case urls = "urls"
  }
}
