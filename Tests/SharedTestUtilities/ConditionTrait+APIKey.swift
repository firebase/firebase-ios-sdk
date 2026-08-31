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
package import Testing

/// Resolves the Gemini API key from `GOOGLE_API_KEY` or `GEMINI_API_KEY` environment variables.
package var geminiAPIKey: String? {
  let env = ProcessInfo.processInfo.environment
  if let googleKey = env["GOOGLE_API_KEY"], !googleKey.isEmpty {
    return googleKey
  }
  if let geminiKey = env["GEMINI_API_KEY"], !geminiKey.isEmpty {
    return geminiKey
  }
  return nil
}

/// Indicates whether a Gemini API key is available in the environment.
package var hasGeminiAPIKey: Bool {
  geminiAPIKey != nil
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension Trait where Self == Testing.ConditionTrait {
  /// Requires a Gemini API key (`GOOGLE_API_KEY` or `GEMINI_API_KEY`) to be set in the environment.
  package static var requireAPIKey: Self {
    .enabled(
      if: hasGeminiAPIKey,
      "Requires GOOGLE_API_KEY or GEMINI_API_KEY environment variable"
    )
  }

  /// Requires that no Gemini API key is set in the environment.
  package static var requireNoAPIKey: Self {
    .enabled(
      if: !hasGeminiAPIKey,
      "Runs only when no API key is set"
    )
  }
}
