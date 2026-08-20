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

import Foundation

/// Constants associated with the Firebase AI SDK.
enum Constants {
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

  /// The default MIME type for arbitrary binary data of an unknown format.
  static let unknownDataMIMEType = "application/octet-stream"

  /// The default URI used when a file's actual URI is missing or unknown.
  ///
  /// This uses `"about:blank"` as a safe fallback that successfully parses into a valid `URL`
  /// object without pointing to active web content. In cases where `URL(string:)` is
  /// force-unwrapped by developers, this will not crash.
  static let unknownFileURI = "about:blank"

  /// The default name used when a function call's name is missing or unknown.
  static let unknownFunctionName = "unknown_function"
}
