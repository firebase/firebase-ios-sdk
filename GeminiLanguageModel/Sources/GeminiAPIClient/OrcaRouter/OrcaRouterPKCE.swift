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

#if canImport(Glibc)
  import Glibc
#endif

// MARK: - PKCE Primitives

/// Proof Key for Code Exchange primitives.
///
/// OrcaRouter's authorization endpoint takes a `code_challenge` and the exchange endpoint takes the
/// matching `code_verifier`. The verifier binds the authorization code to this process, which is
/// what replaces a client secret: an intercepted code cannot be redeemed by anyone who does not
/// hold the verifier.
///
/// The verifier is generated fresh for every attempt, from a cryptographic random number generator,
/// and never leaves the process until the exchange. It is never placed in a URL, a log, or an error.
package enum OrcaRouterPKCE {
  /// The challenge method this integration always sends.
  ///
  /// Always `S256`, including on a redirect flow: a user of a redirect flow may still choose "show
  /// me a code" on the consent screen, which puts the code in human hands.
  package static let challengeMethod = "S256"

  /// The number of random bytes in a verifier.
  package static let verifierByteCount = 32

  /// The number of random bytes in a `state` value.
  package static let stateByteCount = 16

  /// Encodes bytes as unpadded base64url.
  ///
  /// - Parameter bytes: The raw bytes to encode.
  package static func base64URL(_ bytes: [UInt8]) -> String {
    Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  /// Generates a fresh PKCE verifier.
  ///
  /// - Returns: A high-entropy verifier drawn from the system cryptographic random number
  ///   generator, encoded as unpadded base64url.
  /// - Throws: `OrcaRouterPKCEError.randomnessUnavailable` if the generator cannot be read.
  package static func makeVerifier() throws -> String {
    base64URL(try secureRandomBytes(count: verifierByteCount))
  }

  /// Derives the `code_challenge` for a verifier.
  ///
  /// - Parameter verifier: The verifier to derive a challenge from.
  /// - Returns: `base64url(sha256(verifier))` with no padding.
  package static func challenge(forVerifier verifier: String) -> String {
    base64URL(SHA256Digest.hash(verifier))
  }

  /// Generates a fresh opaque `state` value.
  ///
  /// - Returns: A high-entropy value drawn from the system cryptographic random number generator.
  /// - Throws: `OrcaRouterPKCEError.randomnessUnavailable` if the generator cannot be read.
  package static func makeState() throws -> String {
    base64URL(try secureRandomBytes(count: stateByteCount))
  }

  /// Compares two strings without leaking their difference through timing.
  ///
  /// Used for the `state` comparison, which is the only thing standing between this client and a
  /// code dropped on it by somebody else's page.
  ///
  /// - Parameters:
  ///   - lhs: The first value.
  ///   - rhs: The second value.
  /// - Returns: `true` when the values are equal.
  package static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs.utf8)
    let right = Array(rhs.utf8)
    guard left.count == right.count else { return false }
    var difference: UInt8 = 0
    for index in left.indices {
      difference |= left[index] ^ right[index]
    }
    return difference == 0
  }

  /// Draws cryptographically secure random bytes.
  ///
  /// - Parameter count: The number of bytes to draw.
  /// - Returns: The requested bytes.
  /// - Throws: `OrcaRouterPKCEError.randomnessUnavailable` if the generator fails.
  package static func secureRandomBytes(count: Int) throws -> [UInt8] {
    guard let bytes = SystemRandomNumberGenerator().randomBytes(count: count) else {
      throw OrcaRouterPKCEError.randomnessUnavailable
    }
    return bytes
  }
}

/// Errors raised by the PKCE helpers.
package enum OrcaRouterPKCEError: Error, LocalizedError, Sendable, Equatable {
  /// The system random number generator could not be read.
  case randomnessUnavailable

  package var errorDescription: String? {
    switch self {
    case .randomnessUnavailable:
      return "The system cryptographic random number generator is unavailable."
    }
  }
}

// MARK: - System Randomness

extension SystemRandomNumberGenerator {
  /// Fills a buffer from the platform cryptographic random number generator.
  ///
  /// Swift's standard library generator is backed by the platform facility: `getrandom` on Linux
  /// and the platform security framework on Apple platforms.
  ///
  /// - Parameter count: The number of bytes to draw.
  /// - Returns: The requested bytes, or `nil` if the generator failed.
  func randomBytes(count: Int) -> [UInt8]? {
    var generator = self
    var bytes = [UInt8]()
    bytes.reserveCapacity(count)
    for _ in 0..<count {
      bytes.append(UInt8(truncatingIfNeeded: generator.next() as UInt64))
    }
    return bytes
  }
}
