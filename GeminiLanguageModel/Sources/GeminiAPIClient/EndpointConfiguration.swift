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

/// Defines the network endpoint configuration for Gemini API requests.
package struct EndpointConfiguration: Sendable, Hashable, Equatable {
  /// The URI scheme (e.g., `"https"` or `"http"`).
  let scheme: String

  /// The host name of the endpoint (e.g., `"generativelanguage.googleapis.com"`).
  let host: String

  /// An optional port number (e.g., for local emulators or custom proxies).
  let port: Int?

  /// The API version path component (e.g., `"v1beta"` or `"v1beta1"`).
  let apiVersion: String

  /// Initializes a new endpoint configuration.
  ///
  /// - Parameters:
  ///   - scheme: The URI scheme. Defaults to `"https"`.
  ///   - host: The host name of the target service.
  ///   - port: An optional port number. Defaults to `nil`.
  ///   - apiVersion: The target API version path component.
  package init(
    scheme: String = "https",
    host: String,
    port: Int? = nil,
    apiVersion: String
  ) {
    self.scheme = scheme
    self.host = host
    self.port = port
    self.apiVersion = apiVersion
  }
}
