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

/// Metadata related to the ``Tool/urlContext()`` tool.
///
/// > Warning: URL context is a **Public Preview** feature, which means that it is not subject to
/// > any SLA or deprecation policy and could change in backwards-incompatible ways.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct URLContextMetadata: Sendable, Hashable {
  /// List of URL metadata used to provide context to the Gemini model.
  public let urlMetadata: [URLMetadata]
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension URLContextMetadata: Decodable {
  enum CodingKeys: CodingKey {
    case urlMetadata
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    urlMetadata = try container.decodeIfPresent([URLMetadata].self, forKey: .urlMetadata) ?? []
  }
}
