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

/// Message for configuring webhook events for a request.
package struct WebhookConfig: Codable, Sendable, Equatable, Hashable {

  /// Optional. If set, these webhook URIs will be used for webhook events instead of the
  /// registered webhooks.
  package let uris: [String]?

  /// Optional. The user metadata that will be returned on each event emission to the
  /// webhooks.
  package let userMetadata: [String: JSONValue]?

  /// Creates a new `WebhookConfig`.
  ///
  /// - Parameters:
  ///   - uris: Optional. If set, these webhook URIs will be used for webhook events instead of the
  ///   - userMetadata: Optional. The user metadata that will be returned on each event emission to the
  package init(
    uris: [String]? = nil,
    userMetadata: [String: JSONValue]? = nil
  ) {
    self.uris = uris
    self.userMetadata = userMetadata
  }
  enum CodingKeys: String, CodingKey {
    case uris = "uris"
    case userMetadata = "user_metadata"
  }
}
