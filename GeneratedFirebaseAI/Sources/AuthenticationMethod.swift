// Copyright 2025 Google LLC
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
#if os(Linux)
import FoundationNetworking
#endif

@preconcurrency import FirebaseCore

/// How to authenticate with the backend.
///
/// Depending on the backend you're using, certain authentication methods may not be supported.
public enum AuthenticationMethod: Sendable {
  /// API key added to the authentication header.
  ///
  /// Only supported for Google AI and VertexAI Express Mode.
  case apiKey(String)

  /// Bearer access token added to the authentication header.
  ///
  /// Only supported for VertexAI.
  case accessToken(String)

  /// Use Firebase to authenticate with the backend.
  ///
  /// - Parameters:
  ///   - app: The `FirebaseApp` used for initialization.
  ///   - useLimitedUseAppCheckTokens: When sending tokens to the backend, this option enables
  ///     the usage of App Check's limited-use tokens instead of the standard cached tokens. Learn
  ///     more about [limited-use tokens](https://firebase.google.com/docs/ai-logic/app-check),
  ///     including their nuances, when to use them, and best practices for integrating them into
  ///     your app.
  case firebase(
    app: FirebaseApp,
    useLimitedUseAppCheckTokens: Bool = false
  )
}
