/*
 * Copyright 2025 Google LLC
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

import ArgumentParser
import Foundation

/// A representation of a secret file, which should be decrypted for an integration test.
struct SecretFile: Codable {
  /// A relative path to the encrypted file.
  let encrypted: String

  /// A relative path to where the decrypted file should be output to.
  let destination: String
}

extension SecretFile {
  /// Parses a `SecretFile` from a string.
  ///
  /// The string should be in the format of "encrypted:destination".
  /// If it's not, then a `ValidationError`will be thrown.
  ///
  /// - Parameters:
  ///   - string: A string in the format of "encrypted:destination".
  init(string: String) throws {
    let splits = string.split(separator: ":")
    guard splits.count == 2 else {
      throw ValidationError(
        "Invalid secret file format. Format should be \"encrypted:destination\". Cause: \(string)"
      )
    }
    self.encrypted = String(splits[0])
    self.destination = String(splits[1])
  }

  /// Parses an array of `SecretFile` from a JSON file.
  ///
  /// It's expected that the secrets are encoded in the JSON file in the format of:
  /// ```json
  /// [
  ///   {
  ///     "encrypted": "path-to-encrypted-file",
  ///     "destination": "where-to-output-decrypted-file"
  ///   }
  /// ]
  /// ```
  ///
  /// - Parameters:
  ///   - file: The URL of a JSON file which contains an array of `SecretFile`,
  ///    encoded as JSON.
  static func parseArrayFrom(file: URL) throws -> [SecretFile] {
    do {
      let data = try Data(contentsOf: file)
      return try JSONDecoder().decode([SecretFile].self, from: data)
    } catch {
      throw ValidationError(
        "Failed to load secret files from json file. Cause: \(error.localizedDescription)")
    }
  }
}
