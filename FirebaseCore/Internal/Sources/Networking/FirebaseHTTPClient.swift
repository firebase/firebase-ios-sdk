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

/// Sends HTTP requests for Firebase SDKs.
public final class FirebaseHTTPClient: Sendable {
  /// The client that Firebase SDKs share. It sends every request on one ephemeral `URLSession`
  /// that requires TLS 1.2 or later and is never invalidated.
  public static let shared = FirebaseHTTPClient(transport: URLSessionTransport())

  private let transport: any HTTPTransport
  private let backgroundTaskApplication: @Sendable () -> (any BackgroundTaskApplication)?
  private let appAllowsArbitraryLoads: Bool

  /// Creates a client that sends requests through `transport`.
  public convenience init(transport: any HTTPTransport) {
    self.init(
      transport: transport,
      backgroundTaskApplication: { SystemBackgroundTaskApplication.current() },
      appAllowsArbitraryLoads: AppTransportSecurity.allowsArbitraryLoads
    )
  }

  init(transport: any HTTPTransport,
       backgroundTaskApplication: @escaping @Sendable () -> (any BackgroundTaskApplication)?,
       appAllowsArbitraryLoads: Bool) {
    self.transport = transport
    self.backgroundTaskApplication = backgroundTaskApplication
    self.appAllowsArbitraryLoads = appAllowsArbitraryLoads
  }

  /// Sends `request` and returns the response body and the response, whatever the status code.
  /// Callers turn unsuccessful status codes into errors with `HTTPStatusError`.
  ///
  /// If `request` has no `User-Agent` header, the client sends `FirebaseUserAgent.standard`.
  ///
  /// - Throws: A `URLError` for transport failures and for requests that `policy` doesn't allow,
  ///   or `CancellationError` if the calling task is cancelled.
  public func data(for request: URLRequest,
                   policy: HTTPRequestPolicy = HTTPRequestPolicy()) async throws
    -> (Data, HTTPURLResponse) {
    if let url = request.url,
       !Self.allowsScheme(of: url, policy: policy,
                          appAllowsArbitraryLoads: appAllowsArbitraryLoads) {
      throw URLError(.appTransportSecurityRequiresSecureConnection, userInfo: [
        NSURLErrorFailingURLErrorKey: url,
        NSURLErrorFailingURLStringErrorKey: url.absoluteString,
      ])
    }
    var request = request
    if request.value(forHTTPHeaderField: "User-Agent") == nil {
      request.setValue(FirebaseUserAgent.standard, forHTTPHeaderField: "User-Agent")
    }
    let backgroundTask = policy.holdsBackgroundTask
      ? backgroundTaskApplication().map {
        BackgroundTaskAssertion(application: $0, name: "FirebaseHTTPClient")
      }
      : nil
    defer { backgroundTask?.end() }
    return try await transport.data(for: request, policy: policy)
  }

  /// Whether the scheme of `url` is allowed.
  ///
  /// App Transport Security already blocks insecure requests unless the app allows arbitrary
  /// loads. In that case, only `https` is allowed unless `policy` allows more.
  static func allowsScheme(of url: URL, policy: HTTPRequestPolicy,
                           appAllowsArbitraryLoads: Bool) -> Bool {
    guard appAllowsArbitraryLoads else {
      return true
    }
    let scheme = url.scheme?.lowercased()
    if scheme == "https" {
      return true
    }
    if policy.allowsInsecureHTTP, scheme == "http" {
      return true
    }
    return policy.allowsLoopbackHTTP && isLoopback(host: url.host)
  }

  private static func isLoopback(host: String?) -> Bool {
    guard let host else {
      return false
    }
    return host.caseInsensitiveCompare("localhost") == .orderedSame || host == "127.0.0.1" ||
      host == "::1"
  }
}

enum AppTransportSecurity {
  /// Whether the app's Info.plist sets `NSAllowsArbitraryLoads`.
  static let allowsArbitraryLoads: Bool = {
    let settings = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
      as? [String: Any]
    switch settings?["NSAllowsArbitraryLoads"] {
    case let value as NSNumber: return value.boolValue
    case let value as NSString: return value.boolValue
    default: return false
    }
  }()
}
