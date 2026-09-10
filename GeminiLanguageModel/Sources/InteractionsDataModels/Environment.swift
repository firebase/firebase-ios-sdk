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

package import GeminiSharedDataModels

/// Configuration for a custom environment.
package struct Environment: Codable, Sendable, Equatable, Hashable {

  /// Optional. The environment ID for the interaction. If specified, the request will
  /// update the existing environment instead of creating a new one.
  package let environmentId: String?

  /// Network configuration for the environment.
  package let network: JSONValue?

  package let sources: [Source]?

  package let type: String?

  /// Creates a new `Environment`.
  ///
  /// - Parameters:
  ///   - environmentId: Optional. The environment ID for the interaction. If specified, the request will
  ///   - network: Network configuration for the environment.
  ///   - sources: For more details, see ``sources``.
  package init(
    environmentId: String? = nil,
    network: JSONValue? = nil,
    sources: [Source]? = nil
  ) {
    self.environmentId = environmentId
    self.network = network
    self.sources = sources
    self.type = "remote"
  }
  enum CodingKeys: String, CodingKey {
    case environmentId = "environment_id"
    case network = "network"
    case sources = "sources"
    case type = "type"
  }
}
