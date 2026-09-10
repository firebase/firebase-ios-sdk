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

/// A single domain allowlist rule with optional header injection.
package struct AllowlistEntry: Codable, Sendable, Equatable, Hashable {

  /// Domain to allow outbound requests to. Supports wildcards (e.g. '*.googleapis.com'). Use '*' to allow all domains.
  package let domain: String?

  /// Headers to inject on all outbound requests matching this domain. Accepts a single dict or a list of dicts. The egress proxy injects these automatically.
  package let transform: JSONValue?

  /// Creates a new `AllowlistEntry`.
  ///
  /// - Parameters:
  ///   - domain: Domain to allow outbound requests to. Supports wildcards (e.g. '*.googleapis.com'). Use '*' to allow all domains.
  ///   - transform: Headers to inject on all outbound requests matching this domain. Accepts a single dict or a list of dicts. The egress proxy injects these automatically.
  package init(
    domain: String?,
    transform: JSONValue? = nil
  ) {
    self.domain = domain
    self.transform = transform
  }
  enum CodingKeys: String, CodingKey {
    case domain = "domain"
    case transform = "transform"
  }
}
