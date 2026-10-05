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

  /// Resolves the Gemini API key from `GOOGLE_API_KEY` or `GEMINI_API_KEY`.
  package var geminiAPIKey: String? {
    IntegrationTestEnvironment.process.geminiAPIKey
  }

  /// Indicates whether a Gemini API key is available in the environment.
  package var hasGeminiAPIKey: Bool {
    IntegrationTestEnvironment.process.hasGeminiAPIKey
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  extension Trait where Self == Testing.ConditionTrait {
    /// Requires a Gemini API key (`GOOGLE_API_KEY` or `GEMINI_API_KEY`) to be set in the
    /// environment.
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

  /// Resolves the Firebase Project ID from `FIREBASE_PLIST_PATH` (if set) or `FIREBASE_PROJECT_ID`.
  package var firebaseProjectID: String? {
    IntegrationTestEnvironment.process.firebaseProjectID
  }

  /// Resolves the Firebase App ID from `FIREBASE_PLIST_PATH` (if set) or `FIREBASE_APP_ID`.
  package var firebaseAppID: String? {
    IntegrationTestEnvironment.process.firebaseAppID
  }

  /// Resolves the Firebase API key from `FIREBASE_PLIST_PATH` (if set) or `FIREBASE_API_KEY`.
  package var firebaseAPIKey: String? {
    IntegrationTestEnvironment.process.firebaseAPIKey
  }

  /// Resolves the Firebase App Check debug token from standard environment variables:
  /// `AppCheckDebugToken` with fallback to `FIRAAppCheckDebugToken`.
  package var appCheckDebugToken: String? {
    IntegrationTestEnvironment.process.appCheckDebugToken
  }

  /// Indicates whether all required Firebase AI Logic credentials and debug token are available.
  package var hasFirebaseAILogicCredentials: Bool {
    IntegrationTestEnvironment.process.hasFirebaseAILogicCredentials
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  extension Trait where Self == Testing.ConditionTrait {
    /// Requires all Firebase AI Logic credentials and an App Check debug token to be set in the
    /// environment variables.
    package static var requireFirebaseAILogic: Self {
      .enabled(
        if: hasFirebaseAILogicCredentials,
        "Requires FIREBASE_PROJECT_ID, FIREBASE_APP_ID, FIREBASE_API_KEY, and AppCheckDebugToken."
      )
    }
  }
#endif  // canImport(Testing)
