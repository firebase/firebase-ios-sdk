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

/// The rules that `FirebaseHTTPClient` applies to a request.
public struct HTTPRequestPolicy: Sendable {
  /// The hosts that keep receiving credentials after a redirect unless a policy says otherwise:
  /// `googleapis.com`, `google.com`, and their subdomains.
  public static let defaultTrustedRedirectHosts: Set<String> = ["googleapis.com", "google.com"]

  /// Whether `http` requests to any host are allowed, for example to reach an emulator.
  public var allowsInsecureHTTP: Bool

  /// Whether non-`https` requests to `localhost`, `127.0.0.1`, and `::1` are allowed.
  public var allowsLoopbackHTTP: Bool

  /// Whether the request asks the system for time to finish if the app moves to the background.
  /// It applies on iOS, tvOS, and Mac Catalyst, and never in app extensions.
  public var holdsBackgroundTask: Bool

  /// The hosts, including their subdomains, that keep receiving credential headers after a
  /// redirect to a different origin. Credential headers are removed for every other origin.
  public var trustedRedirectHosts: Set<String>

  public init(allowsInsecureHTTP: Bool = false,
              allowsLoopbackHTTP: Bool = false,
              holdsBackgroundTask: Bool = true,
              trustedRedirectHosts: Set<String> = HTTPRequestPolicy.defaultTrustedRedirectHosts) {
    self.allowsInsecureHTTP = allowsInsecureHTTP
    self.allowsLoopbackHTTP = allowsLoopbackHTTP
    self.holdsBackgroundTask = holdsBackgroundTask
    self.trustedRedirectHosts = trustedRedirectHosts
  }
}
