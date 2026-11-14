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

/// Builds the request that follows an HTTP redirect.
enum RedirectPolicy {
  /// Headers that carry credentials. Header names are compared case-insensitively.
  static let credentialHeaders: Set<String> = [
    "authorization",
    "cookie",
    "cookie2",
    "firebase-instance-id-token",
    "proxy-authorization",
    "sec-provided-token-binding-id",
    "sec-referred-token-binding-id",
    "sec-token-binding",
    "x-firebase-appcheck",
  ]

  /// Suffixes of header names that carry credentials, such as `X-Goog-Api-Key`.
  static let credentialHeaderSuffixes = ["-authuser", "-key", "-token"]

  /// Returns the request to send to the redirect target, or `nil` to not follow the redirect.
  ///
  /// - The request keeps the method, body, and headers of `request`, so a `POST` stays a `POST`.
  ///   `URLSession` drops the body from the redirect request that it proposes.
  /// - Headers in `proposed` replace headers with the same name.
  /// - An `https` request is never redirected to `http`. Its scheme stays `https`.
  /// - If the target has a different origin, credential headers are removed unless the target's
  ///   host is one of `policy.trustedRedirectHosts`.
  ///
  /// - Parameters:
  ///   - request: The request that received the redirect response.
  ///   - proposed: The redirect request that `URLSession` proposes.
  ///   - policy: The policy of the original request.
  static func request(redirecting request: URLRequest, to proposed: URLRequest,
                      policy: HTTPRequestPolicy) -> URLRequest? {
    guard let originalURL = request.url, let proposedURL = proposed.url else {
      return proposed
    }
    guard let targetURL = redirectURL(from: originalURL, to: proposedURL) else {
      return nil
    }
    var redirect = request
    redirect.url = targetURL
    for (name, value) in proposed.allHTTPHeaderFields ?? [:] {
      redirect.setValue(value, forHTTPHeaderField: name)
    }
    if !isSameOrigin(originalURL, targetURL),
       !isTrusted(host: targetURL.host, trustedHosts: policy.trustedRedirectHosts) {
      for name in (redirect.allHTTPHeaderFields ?? [:]).keys where isCredentialHeader(name) {
        redirect.setValue(nil, forHTTPHeaderField: name)
      }
    }
    return redirect
  }

  /// Returns `proposed`, except that an `https` URL is never downgraded: a redirect from `https`
  /// to another scheme keeps `https`. Returns `nil` if that URL can't be built.
  static func redirectURL(from original: URL, to proposed: URL) -> URL? {
    let originalScheme = original.scheme ?? "https"
    let proposedScheme = proposed.scheme ?? ""
    let isUpgrade = originalScheme.caseInsensitiveCompare("http") == .orderedSame &&
      proposedScheme.caseInsensitiveCompare("https") == .orderedSame
    if originalScheme.caseInsensitiveCompare(proposedScheme) == .orderedSame || isUpgrade {
      return proposed
    }
    guard var components = URLComponents(url: proposed, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.scheme = originalScheme
    return components.url
  }

  /// Whether two URLs have the same scheme, host, and port.
  static func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
    guard let scheme = lhs.scheme?.lowercased(), scheme == rhs.scheme?.lowercased(),
          let host = lhs.host?.lowercased(), host == rhs.host?.lowercased() else {
      return false
    }
    return effectivePort(of: lhs) == effectivePort(of: rhs)
  }

  /// Whether `host` is one of `trustedHosts` or a subdomain of one.
  static func isTrusted(host: String?, trustedHosts: Set<String>) -> Bool {
    guard let host = host?.lowercased(), !host.isEmpty else {
      return false
    }
    return trustedHosts.contains { trustedHost in
      let domain = trustedHost.lowercased().drop { $0 == "." }
      return !domain.isEmpty && (host == domain || host.hasSuffix("." + domain))
    }
  }

  /// Whether the header named `name` carries credentials.
  static func isCredentialHeader(_ name: String) -> Bool {
    let name = name.lowercased()
    return credentialHeaders.contains(name) ||
      credentialHeaderSuffixes.contains { name.hasSuffix($0) }
  }

  private static func effectivePort(of url: URL) -> Int? {
    if let port = url.port {
      return port
    }
    switch url.scheme?.lowercased() {
    case "https": return 443
    case "http": return 80
    default: return nil
    }
  }
}
