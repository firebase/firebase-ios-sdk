// Copyright 2023 Google LLC
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

import FirebaseCore
import Foundation

/// Constants associated with the Firebase AI SDK.
enum Constants {
  /// The language of the SDK in the format `gl-<language>/<version>`.
  static let languageTag = "gl-swift/5"

  /// The Firebase SDK version in the format `fire/<version>`.
  static let firebaseVersionTag = "fire/\(FirebaseVersion())"

  #if compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
    /// A tag indicating that the request originated from `GeminiLanguageModel`, through the
    /// Foundation Models framework.
    static let foundationModelsRequestTag = "fma"
  #endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)

  /// The base reverse-DNS name for `NSError` or `CustomNSError` error domains.
  ///
  /// - Important: A suffix must be appended to produce an error domain (e.g.,
  ///   "com.google.firebase.firebaseai.ExampleError").
  static let baseErrorDomain = "com.google.firebase.firebaseai"

  #if DEBUG
    /// The key for an environment variable containing a Google Cloud Access Token.
    ///
    /// This should only be used for SDK development and testing with the Gemini
    /// Enterprise Agent Platform direct backend that bypasses the Firebase proxy.
    ///
    /// The value should is typically obtained from the gcloud CLI by calling
    /// `gcloud auth print-access-token`.
    static let gCloudAccessTokenEnvVarKey = "FIRGCloudAuthAccessToken"
  #endif // DEBUG
}
