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

// MARK: - SHA-256

/// A self-contained SHA-256 implementation.
///
/// This package declares no external dependencies, so the PKCE challenge is computed here rather
/// than by adding one. The implementation is checked against the published NIST and RFC 7636 test
/// vectors by `SHA256Tests`.
enum SHA256Digest {
  /// The digest size in bytes.
  static let byteCount = 32

  /// The first 32 bits of the fractional parts of the cube roots of the first 64 primes.
  private static let roundConstants: [UInt32] = [
    0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1,
    0x923f_82a4, 0xab1c_5ed5, 0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3,
    0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7, 0xc19b_f174, 0xe49b_69c1, 0xefbe_4786,
    0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc, 0x76f9_88da,
    0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7, 0xc6e0_0bf3, 0xd5a7_9147,
    0x06ca_6351, 0x1429_2967, 0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13,
    0x650a_7354, 0x766a_0abb, 0x81c2_c92e, 0x9272_2c85, 0xa2bf_e8a1, 0xa81a_664b,
    0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585, 0x106a_a070,
    0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a,
    0x5b9c_ca4f, 0x682e_6ff3, 0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208,
    0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7, 0xc671_78f2,
  ]

  /// The initial hash values: the first 32 bits of the fractional parts of the square roots of the
  /// first eight primes.
  private static let initialHash: [UInt32] = [
    0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a,
    0x510e_527f, 0x9b05_688c, 0x1f83_d9ab, 0x5be0_cd19,
  ]

  /// Computes the SHA-256 digest of a byte sequence.
  ///
  /// - Parameter message: The bytes to hash.
  /// - Returns: The 32-byte digest.
  static func hash<Bytes: Collection>(_ message: Bytes) -> [UInt8]
  where Bytes.Element == UInt8 {
    var state = initialHash
    var block = [UInt8](repeating: 0, count: 64)
    var blockLength = 0
    var messageBitLength: UInt64 = 0

    func compress(_ block: [UInt8]) {
      var schedule = [UInt32](repeating: 0, count: 64)
      for index in 0..<16 {
        let offset = index * 4
        schedule[index] =
          (UInt32(block[offset]) << 24)
          | (UInt32(block[offset + 1]) << 16)
          | (UInt32(block[offset + 2]) << 8)
          | UInt32(block[offset + 3])
      }
      for index in 16..<64 {
        let previous = schedule[index - 15]
        let recent = schedule[index - 2]
        let sigma0 =
          rotateRight(previous, by: 7) ^ rotateRight(previous, by: 18) ^ (previous >> 3)
        let sigma1 =
          rotateRight(recent, by: 17) ^ rotateRight(recent, by: 19) ^ (recent >> 10)
        schedule[index] =
          schedule[index - 16] &+ sigma0 &+ schedule[index - 7] &+ sigma1
      }

      var a = state[0], b = state[1], c = state[2], d = state[3]
      var e = state[4], f = state[5], g = state[6], h = state[7]

      for index in 0..<64 {
        let sum1 = rotateRight(e, by: 6) ^ rotateRight(e, by: 11) ^ rotateRight(e, by: 25)
        let choose = (e & f) ^ (~e & g)
        let temp1 = h &+ sum1 &+ choose &+ roundConstants[index] &+ schedule[index]
        let sum0 = rotateRight(a, by: 2) ^ rotateRight(a, by: 13) ^ rotateRight(a, by: 22)
        let majority = (a & b) ^ (a & c) ^ (b & c)
        let temp2 = sum0 &+ majority

        h = g
        g = f
        f = e
        e = d &+ temp1
        d = c
        c = b
        b = a
        a = temp1 &+ temp2
      }

      state[0] = state[0] &+ a
      state[1] = state[1] &+ b
      state[2] = state[2] &+ c
      state[3] = state[3] &+ d
      state[4] = state[4] &+ e
      state[5] = state[5] &+ f
      state[6] = state[6] &+ g
      state[7] = state[7] &+ h
    }

    for byte in message {
      block[blockLength] = byte
      blockLength += 1
      messageBitLength &+= 8
      if blockLength == 64 {
        compress(block)
        blockLength = 0
      }
    }

    // Padding: a single 1 bit, then zeros, then the 64-bit big-endian length.
    block[blockLength] = 0x80
    blockLength += 1
    if blockLength > 56 {
      while blockLength < 64 {
        block[blockLength] = 0
        blockLength += 1
      }
      compress(block)
      blockLength = 0
    }
    while blockLength < 56 {
      block[blockLength] = 0
      blockLength += 1
    }
    for index in 0..<8 {
      block[56 + index] = UInt8(truncatingIfNeeded: messageBitLength >> ((7 - index) * 8))
    }
    compress(block)

    var digest = [UInt8]()
    digest.reserveCapacity(byteCount)
    for word in state {
      digest.append(UInt8(truncatingIfNeeded: word >> 24))
      digest.append(UInt8(truncatingIfNeeded: word >> 16))
      digest.append(UInt8(truncatingIfNeeded: word >> 8))
      digest.append(UInt8(truncatingIfNeeded: word))
    }
    return digest
  }

  /// Computes the SHA-256 digest of a UTF-8 string.
  ///
  /// - Parameter message: The string to hash.
  /// - Returns: The 32-byte digest.
  static func hash(_ message: String) -> [UInt8] {
    hash(Array(message.utf8))
  }

  /// Computes the lowercase hexadecimal rendering of a digest.
  ///
  /// - Parameter message: The string to hash.
  static func hexDigest(_ message: String) -> String {
    hash(message).map { String(format: "%02x", $0) }.joined()
  }

  /// Rotates a 32-bit word right.
  private static func rotateRight(_ value: UInt32, by amount: UInt32) -> UInt32 {
    (value >> amount) | (value << (32 - amount))
  }
}
