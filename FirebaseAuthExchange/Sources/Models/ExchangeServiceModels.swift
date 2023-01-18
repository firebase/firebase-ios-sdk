// Copyright 2022 Google LLC
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

// MARK: - Request Models

/// Request for exchanging a Firebase Installations token for an Auth Exchange access token.
struct ExchangeInstallationAuthTokenRequest: Encodable {
  /// A Firebase Installations auth token as a base64-encoded JWT.
  let installationAuthToken: String
}

/// Request for exchanging a custom auth token for an Auth Exchange access token.
struct ExchangeCustomTokenRequest: Encodable {
  /// A custom base64-encoded JWT signed with the developer's credentials.
  let customToken: String
}

/// Request for exchanging an OpenID Connect (OIDC) token for an Auth Exchange access token.
struct ExchangeOIDCTokenRequest: Encodable {
  /// The display name or identifier of the OIDC provider.
  let providerID: String

  struct ImplicitCredentials: Encodable {
    let idToken: String
  }

  struct AuthCodeCredentials: Encodable {
    let sessionID: String

    let credentialURI: String
  }

  // TODO(andrewheard): Investigate using an enum for credentials to represent oneof semantics.
  let implicitCredentials: ImplicitCredentials?

  let authCodeCredentials: AuthCodeCredentials?

  init(providerID: String, implicitCredentials: ImplicitCredentials) {
    self.providerID = providerID
    self.implicitCredentials = implicitCredentials
    authCodeCredentials = nil
  }

  init(providerID: String, authCodeCredentials: AuthCodeCredentials) {
    self.providerID = providerID
    implicitCredentials = nil
    self.authCodeCredentials = authCodeCredentials
  }
}

// MARK: - Response Models

/// Response that encapsulates an Auth Exchange access token.
///
/// This is the return value for an `ExchangeInstallationAuthTokenRequest` or
/// `ExchangeCustomTokenRequest`.
struct ExchangeTokenResponse: Decodable, Equatable {
  /// A container for a Firebase  access token and the duration of time until it expires.
  struct AuthExchangeToken: Decodable, Equatable {
    /// A signed [JWT](https://tools.ietf.org/html/rfc7519) containing claims that identify a user.
    let accessToken: String

    /// The duration of time until the `accessToken` expires, approximately relative to the time
    /// this response was received.
    let timeToLive: ProtobufDuration

    enum CodingKeys: String, CodingKey {
      case accessToken
      case timeToLive = "ttl"
    }
  }

  /// An Auth Exchange access token that can be used to access Firebase services.
  let token: AuthExchangeToken
}

/// Model of a `google.protobuf.Duration`, which represents a time span.
///
/// A Protocol Buffer
/// [`Duration`](https://developers.google.com/protocol-buffers/docs/reference/google.protobuf#duration)
/// represents a signed, fixed-length span of time represented as a count of seconds and fractions
/// of seconds at nanosecond resolution. It is independent of any calendar and concepts like "day"
/// or "month".
struct ProtobufDuration: Equatable {
  private static let nanosecondsPerSecond = 1e9 // 1 x 10⁹ nanoseconds / second

  /// The number of seconds in the time span.
  let seconds: Int64

  /// The fraction of a second, at nanosecond resolution, in addition to `seconds` in the time span.
  let nanoseconds: Int32

  /// Floating-point representation of the time span in seconds.
  var duration: TimeInterval {
    return TimeInterval(seconds) + Double(nanoseconds) / ProtobufDuration.nanosecondsPerSecond
  }

  /// Creates a new instance from a JSON string representation of a `Duration`.
  ///
  /// - parameter json: a string with the format "`{seconds}.{nanoseconds}s`", with nanoseconds
  ///   expressed as fractional seconds.
  init(json: String) throws {
    (seconds, nanoseconds) = try parseDuration(text: json)
  }
}

extension ProtobufDuration: Decodable {
  init(from decoder: Decoder) throws {
    let durationString = try decoder.singleValueContainer().decode(String.self)
    try self.init(json: durationString)
  }
}
