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
import Testing

@testable import GeminiAPIClient

/// Verifies the self-contained SHA-256 against published test vectors.
///
/// The PKCE challenge is a SHA-256 of the verifier, so the correctness of this digest is security
/// relevant rather than cosmetic.
@Suite("SHA-256 Tests")
struct SHA256Tests {
  @Test
  func emptyStringMatchesNISTVector() {
    #expect(
      SHA256Digest.hexDigest("")
        == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
  }

  @Test
  func abcMatchesNISTVector() {
    #expect(
      SHA256Digest.hexDigest("abc")
        == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
  }

  @Test
  func longMessageMatchesNISTVector() {
    // The 448-bit NIST message, the classic multi-block case.
    let message = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    #expect(
      SHA256Digest.hexDigest(message)
        == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
    )
  }

  @Test
  func messageSpanningThreeBlocksMatchesNISTVector() {
    let message =
      "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"
      + "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
    #expect(
      SHA256Digest.hexDigest(message)
        == "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"
    )
  }

  @Test
  func oneMillionAsMatchesNISTVector() {
    let digest = SHA256Digest.hash(Array(repeating: UInt8(ascii: "a"), count: 1_000_000))
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    #expect(hex == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
  }

  @Test
  func digestIsThirtyTwoBytes() {
    #expect(SHA256Digest.hash("anything").count == 32)
  }

  @Test
  func paddingBoundaryLengths() {
    // Exercise the length-56 and length-64 padding boundaries, where the block-splitting logic
    // behaves differently.
    for length in [55, 56, 57, 63, 64, 65, 119, 120] {
      let message = String(repeating: "x", count: length)
      let hex = SHA256Digest.hash(message).map { String(format: "%02x", $0) }.joined()
      #expect(hex.count == 64, "length \(length) produced a malformed digest")
    }
  }
}
