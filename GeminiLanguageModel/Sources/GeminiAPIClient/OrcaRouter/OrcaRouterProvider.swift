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

package import Foundation

// MARK: - OrcaRouter Provider

/// A first-class OrcaRouter provider definition.
///
/// OrcaRouter is an OpenAI-compatible AI gateway that routes many providers behind one endpoint.
/// This type carries everything needed to reach it: which of the two authentication entries the
/// caller selected, and the two distinct public origins that OrcaRouter serves.
///
/// Authentication and inference deliberately live on different origins:
///
/// - authentication and code exchange: `https://www.orcarouter.ai`
/// - inference and model discovery: `https://api.orcarouter.ai/v1`
///
/// Neither origin is ever derived from the other by rewriting a host name or appending a path
/// component. Each is resolved independently so a self-hosted deployment that splits them keeps
/// working.
package struct OrcaRouterProvider: Sendable, Hashable {
  /// The public authentication origin used when no override is configured.
  package static let defaultAuthBaseURLString = "https://www.orcarouter.ai"

  /// The public inference origin used when no override is configured, including its API version
  /// path component.
  package static let defaultAPIBaseURLString = "https://api.orcarouter.ai/v1"

  /// Environment variable holding a single shared self-hosted base URL.
  package static let sharedBaseURLEnvironmentKey = "ORCA_BASE_URL"

  /// Environment variable overriding the authentication origin.
  package static let authBaseURLEnvironmentKey = "ORCA_AUTH_BASE_URL"

  /// Environment variable overriding the inference origin.
  package static let apiBaseURLEnvironmentKey = "ORCA_API_BASE_URL"

  /// Authorize endpoint path on the authentication origin.
  package static let authorizePath = "/auth"

  /// Code exchange endpoint path on the authentication origin.
  ///
  /// - Important: The relay serves inference at `/v1`; the authentication API does **not**. The
  ///   exchange endpoint is `/api/v1/auth/keys` on the authentication origin.
  ///   `https://api.orcarouter.ai/v1/auth/keys` does not exist.
  package static let exchangePath = "/api/v1/auth/keys"

  /// Device-grant start path on the authentication origin.
  package static let deviceCodePath = "/api/v1/auth/device/code"

  /// Device-grant poll path on the authentication origin.
  package static let deviceTokenPath = "/api/v1/auth/device/token"

  /// Model catalog path on the inference origin.
  package static let modelsPath = "/models"

  /// Chat completion path on the inference origin.
  package static let chatCompletionsPath = "/chat/completions"

  /// Where a user creates or inspects an API key.
  package static let keyManagementURLString = "https://www.orcarouter.ai/console/token"

  /// Where a user revokes every key issued to an application in one click.
  package static let authorizedAppsURLString = "https://www.orcarouter.ai/console/authorized-apps"

  /// OpenID-style discovery document for the authentication origin.
  package static let discoveryURLString =
    "https://www.orcarouter.ai/.well-known/openid-configuration"

  /// The OAuth scope this integration requests.
  package static let scope = "api"

  /// Each of the two ways a user can put an OrcaRouter credential into the SDK.
  ///
  /// The two entries are kept distinct rather than collapsed into one button that sometimes asks
  /// for a key and sometimes opens a browser: support, sign-out, and reauthentication all behave
  /// differently for a credential the user typed and one an authorization produced.
  package enum Authentication: String, Sendable, Hashable, CaseIterable {
    /// The user pastes an existing `sk-orca-…` API key.
    case apiKey = "orcarouter"

    /// The user authorizes in a browser or on another device; the exchange yields a key.
    case account = "orcarouter-oauth"

    /// A stable identifier suitable for configuration and telemetry-free diagnostics.
    package var identifier: String { rawValue }

    /// The label shown wherever both choices can appear.
    package var displayName: String {
      switch self {
      case .apiKey: return "OrcaRouter - API"
      case .account: return "OrcaRouter - Auth"
      }
    }
  }

  /// Which authentication entry this provider instance represents.
  package let authentication: Authentication

  /// The resolved authentication origin.
  package let authBaseURL: URL

  /// The resolved inference origin, including its API version path component.
  package let apiBaseURL: URL

  /// Creates a provider for one of the two authentication entries, resolving both origins from the
  /// environment.
  ///
  /// - Parameters:
  ///   - authentication: The authentication entry the caller selected.
  ///   - environment: The environment to resolve origin overrides from. Defaults to the process
  ///     environment.
  /// - Throws: `OrcaRouterOriginError` if a configured origin is unusable.
  package init(
    authentication: Authentication,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws {
    self.authentication = authentication
    self.authBaseURL = try OrcaRouterOriginPolicy.resolve(
      overrideValue: environment[Self.authBaseURLEnvironmentKey],
      sharedValue: environment[Self.sharedBaseURLEnvironmentKey],
      defaultValue: Self.defaultAuthBaseURLString,
      role: .authentication
    )
    self.apiBaseURL = try OrcaRouterOriginPolicy.resolve(
      overrideValue: environment[Self.apiBaseURLEnvironmentKey],
      sharedValue: environment[Self.sharedBaseURLEnvironmentKey],
      defaultValue: Self.defaultAPIBaseURLString,
      role: .inference
    )
  }

  /// Creates a provider from explicitly supplied origins.
  ///
  /// Explicit values take precedence over anything in the environment; this initializer does not
  /// consult the environment at all.
  ///
  /// - Parameters:
  ///   - authentication: The authentication entry the caller selected.
  ///   - authBaseURL: The authentication origin.
  ///   - apiBaseURL: The inference origin, including its API version path component.
  /// - Throws: `OrcaRouterOriginError` if either origin is unusable.
  package init(
    authentication: Authentication,
    authBaseURL: String,
    apiBaseURL: String
  ) throws {
    self.authentication = authentication
    self.authBaseURL = try OrcaRouterOriginPolicy.validate(
      authBaseURL,
      role: .authentication
    )
    self.apiBaseURL = try OrcaRouterOriginPolicy.validate(
      apiBaseURL,
      role: .inference
    )
  }

  /// The endpoint configuration describing the inference origin, for callers that want the
  /// repository's existing value type.
  package var apiEndpointConfiguration: EndpointConfiguration {
    let components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false)
    let version = (components?.path ?? "")
      .split(separator: "/")
      .last
      .map(String.init) ?? "v1"
    return EndpointConfiguration(
      scheme: components?.scheme ?? "https",
      host: components?.host ?? "",
      port: components?.port,
      apiVersion: version
    )
  }

  /// Builds a URL on the authentication origin.
  ///
  /// - Parameter path: An absolute path beginning with `/`.
  /// - Throws: `URLError(.badURL)` if the components do not form a valid URL.
  package func makeAuthURL(path: String) throws -> URL {
    try OrcaRouterOriginPolicy.makeURL(base: authBaseURL, path: path)
  }

  /// Builds a URL on the inference origin.
  ///
  /// - Parameter path: A path beginning with `/`, appended to the inference base path.
  /// - Throws: `URLError(.badURL)` if the components do not form a valid URL.
  package func makeAPIURL(path: String) throws -> URL {
    try OrcaRouterOriginPolicy.makeURL(base: apiBaseURL, path: path)
  }
}

// MARK: - Origin Policy

/// Enforces which origins OrcaRouter requests may be sent to.
package enum OrcaRouterOriginPolicy {
  /// The role an origin plays, used for diagnostics and for the API-version default.
  package enum Role: Sendable, Hashable {
    case authentication
    case inference
  }

  /// Resolves an origin from an explicit override, a shared self-hosted base, and a public default,
  /// in that order of precedence.
  ///
  /// - Parameters:
  ///   - overrideValue: The role-specific override, if configured.
  ///   - sharedValue: The shared self-hosted base, if configured.
  ///   - defaultValue: The public default used when neither override is configured.
  ///   - role: The role the resulting origin will play.
  /// - Throws: `OrcaRouterOriginError` if the chosen value is unusable.
  package static func resolve(
    overrideValue: String?,
    sharedValue: String?,
    defaultValue: String,
    role: Role
  ) throws -> URL {
    if let overrideValue, !overrideValue.isEmpty {
      return try validate(overrideValue, role: role)
    }
    if let sharedValue, !sharedValue.isEmpty {
      let base = try validate(sharedValue, role: role)
      return role == .inference ? try appendingAPIVersionIfNeeded(to: base) : base
    }
    return try validate(defaultValue, role: role)
  }

  /// Validates a single origin.
  ///
  /// Remote origins must use HTTPS. Plain HTTP is permitted only for loopback development hosts.
  ///
  /// - Parameters:
  ///   - value: The origin string to validate.
  ///   - role: The role the origin will play.
  /// - Throws: `OrcaRouterOriginError` describing why the value was rejected.
  package static func validate(_ value: String, role: Role) throws -> URL {
    guard let components = URLComponents(string: value),
      let scheme = components.scheme?.lowercased(),
      let host = components.host, !host.isEmpty
    else {
      throw OrcaRouterOriginError.malformed(value, role: role)
    }

    guard components.user == nil, components.password == nil else {
      throw OrcaRouterOriginError.userInfoNotAllowed(value, role: role)
    }

    guard components.fragment == nil else {
      throw OrcaRouterOriginError.fragmentNotAllowed(value, role: role)
    }

    switch scheme {
    case "https":
      break
    case "http":
      guard isLoopback(host) else {
        throw OrcaRouterOriginError.insecureScheme(value, role: role)
      }
    default:
      throw OrcaRouterOriginError.unsupportedScheme(scheme, role: role)
    }

    guard let url = components.url else {
      throw OrcaRouterOriginError.malformed(value, role: role)
    }
    return url
  }

  /// Appends the `/v1` API version path component to a shared self-hosted base if it does not
  /// already name one.
  ///
  /// - Parameter base: The shared base origin.
  /// - Throws: `OrcaRouterOriginError.malformed` if the resulting string is not a valid URL.
  package static func appendingAPIVersionIfNeeded(to base: URL) throws -> URL {
    let trimmedPath = base.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if !trimmedPath.isEmpty, trimmedPath.split(separator: "/").last?.hasPrefix("v") == true {
      return base
    }
    let string =
      trimmedPath.isEmpty
      ? "\(base.absoluteString)/v1"
      : "\(base.absoluteString)/v1"
    guard let url = URL(string: string) else {
      throw OrcaRouterOriginError.malformed(base.absoluteString, role: .inference)
    }
    return url
  }

  /// Builds a URL by appending `path` to the base URL's existing path.
  ///
  /// - Parameters:
  ///   - base: The origin, possibly carrying a path prefix such as `/v1`.
  ///   - path: An absolute path beginning with `/`.
  /// - Throws: `URLError(.badURL)` if the components do not form a valid URL.
  package static func makeURL(base: URL, path: String) throws -> URL {
    guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
      throw URLError(.badURL)
    }
    let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let suffix = path.hasPrefix("/") ? path : "/\(path)"
    components.path = basePath.isEmpty ? suffix : "/\(basePath)\(suffix)"
    components.query = nil
    components.fragment = nil
    guard let url = components.url else {
      throw URLError(.badURL)
    }
    return url
  }

  /// Indicates whether a host is a loopback address for which plain HTTP is acceptable.
  ///
  /// - Parameter host: The host name to test.
  package static func isLoopback(_ host: String) -> Bool {
    let lowered = host.lowercased()
    return lowered == "localhost" || lowered == "127.0.0.1" || lowered == "[::1]"
      || lowered == "::1"
  }
}

// MARK: - Origin Errors

/// Errors raised while resolving or validating an OrcaRouter origin.
package enum OrcaRouterOriginError: Error, LocalizedError, Sendable, Equatable {
  /// The value was not a usable URL.
  case malformed(String, role: OrcaRouterOriginPolicy.Role)

  /// The value carried a user or password component.
  case userInfoNotAllowed(String, role: OrcaRouterOriginPolicy.Role)

  /// The value carried a fragment.
  case fragmentNotAllowed(String, role: OrcaRouterOriginPolicy.Role)

  /// A remote origin used a scheme other than HTTPS.
  case insecureScheme(String, role: OrcaRouterOriginPolicy.Role)

  /// The scheme is not one this integration can speak.
  case unsupportedScheme(String, role: OrcaRouterOriginPolicy.Role)

  package var errorDescription: String? {
    switch self {
    case .malformed(_, let role):
      return "The OrcaRouter \(role.name) origin is not a valid URL."
    case .userInfoNotAllowed:
      return "The OrcaRouter origin must not contain a user name or password."
    case .fragmentNotAllowed:
      return "The OrcaRouter origin must not contain a fragment."
    case .insecureScheme(_, let role):
      return
        "The OrcaRouter \(role.name) origin must use HTTPS; plain HTTP is allowed only for "
        + "loopback development hosts."
    case .unsupportedScheme(let scheme, let role):
      return "The OrcaRouter \(role.name) origin uses an unsupported scheme: \(scheme)."
    }
  }
}

extension OrcaRouterOriginPolicy.Role {
  /// A short human-readable name used in diagnostics.
  package var name: String {
    switch self {
    case .authentication: return "authentication"
    case .inference: return "inference"
    }
  }
}
