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

  /// An identifier that uniquely identifies generated content.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`GenerationID`](https://developer.apple.com/documentation/foundationmodels/generationid).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GenerationID: Sendable, Hashable {
    /// The underlying identifier value, a UUID string for framework-created identifiers.
    let value: String

    /// Creates a unique generation identifier.
    public init() {
      self.value = UUID().uuidString
    }

    /// Creates an identifier that wraps the given value.
    ///
    /// - Parameter value: The identifier value.
    init(value: String) {
      self.value = value
    }
  }
#endif  // compiler(>=6.4)
