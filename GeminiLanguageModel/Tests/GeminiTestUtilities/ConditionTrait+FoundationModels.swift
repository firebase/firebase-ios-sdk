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

#if canImport(Testing)
  import Foundation
  package import Testing

  /// Indicates whether the FoundationModels framework and OS support are available.
  package var isFoundationModelsAvailable: Bool {
    #if canImport(FoundationModels) && compiler(>=6.4) && !os(tvOS)
      if #available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *) {
        return true
      }
    #endif
    return false
  }

  extension Trait where Self == Testing.ConditionTrait {
    /// Requires that `FoundationModels` is available on the current OS and platform.
    package static var requireFoundationModels: Self {
      .enabled(
        if: isFoundationModelsAvailable,
        "Requires FoundationModels framework support."
      )
    }
  }
#endif
