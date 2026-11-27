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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  extension GenerationSchema {
    /// The schema's type name, as shown by ``Transcript/ResponseFormat/name``.
    ///
    /// For example, `"Person"` for a `@Generable struct Person`, `"String"` for `String`, and
    /// `"Array<Int>"` for `[Int]`.
    var transcriptTypeName: String {
      name
    }

    /// The schema's JSON with sorted keys and no whitespace, as used in transcript descriptions.
    ///
    /// - Returns: The compact JSON text, or `"{}"` if the schema can't be encoded.
    var transcriptCompactJSON: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      guard let data = try? encoder.encode(self) else {
        return "{}"
      }
      return String(decoding: data, as: UTF8.self)
    }

    /// Returns a Boolean value that indicates whether two schemas are equivalent.
    ///
    /// `GenerationSchema` isn't `Equatable`, so transcript types that hold schemas compare them
    /// by their serialized form.
    ///
    /// - Parameter other: The schema to compare with.
    /// - Returns: `true` if both schemas produce identical JSON.
    func isTranscriptEquivalent(to other: GenerationSchema) -> Bool {
      isEquivalent(to: other)
    }
  }
#endif  // compiler(>=6.4)
