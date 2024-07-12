/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import CommonCrypto
import Foundation

/// Hashing related utility functions. The enum type is used as a namespace here instead of having
/// root functions, and no cases should be added to it. Note: this would be named `Hasher` but it
/// collide's with Foundation's `Hasher` type.
enum HashCalculator {}

extension HashCalculator {
  enum HashError: Error {
    /// Real errors aren't thrown, so just give text what happened.
    case failed(String)
  }

  /// Hashes the contents of the directory recursively.
  static func sha256Contents(ofDir dir: URL) throws -> String {
    var hashes: [String] = []
    let allContents = try FileManager.default.recursivelySearch(for: .allFiles, in: dir)
    // Sort the contents to make it deterministic.
    let sortedContents = allContents.sorted { $0.absoluteString < $1.absoluteString }
    for file in sortedContents {
      // Hash the contents of the file.
      let contentsHash = try sha256(file)
      hashes.append(contentsHash)

      // Hash the file name as well.
      let nameHash = try sha256(file.path)
      hashes.append(nameHash)
    }

    if hashes.isEmpty {
      throw HashError.failed("Directory \(dir) does not contain any files.")
    }

    // Calculate the final hash by hashing all the hashes joined together.
    let hash = try sha256(hashes.joined())
    return hash
  }

  /// Calculates the SHA256 hash of the data given.
  static func sha256(_ data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    #if swift(>=5)
      _ = data.withUnsafeBytes {
        CC_SHA256($0.baseAddress, UInt32(data.count), &digest)
      }
    #else
      _ = data.withUnsafeBytes {
        CC_SHA256($0, UInt32(data.count), &digest)
      }
    #endif

    let characters = digest.map { String(format: "%02x", $0) }
    return characters.joined()
  }

  /// Calculates the SHA256 hash of the contents of the file at the given URL.
  static func sha256(_ file: URL) throws -> String {
    guard file.isFileURL else {
      throw HashError.failed("URL given is not a file URL. \(file)")
    }

    guard let data = FileManager.default.contents(atPath: file.path) else {
      throw HashError.failed("Could not get data from \(file.path).")
    }

    return sha256(data)
  }

  /// Calculates the SHA256 hash of the text given.
  static func sha256(_ text: String) throws -> String {
    // If we can't get UTF8 bytes out, return nil.
    guard let data = text.data(using: .utf8) else {
      throw HashError.failed("String used was not UTF8 compliant. \"\(text)\"")
    }

    return sha256(data)
  }
}
