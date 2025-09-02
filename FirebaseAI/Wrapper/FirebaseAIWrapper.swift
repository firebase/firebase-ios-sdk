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

import FirebaseCore

@_exported import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias FirebaseAI = AILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension AILogic {
  /// Creates an instance of `AILogic`.
  ///
  /// - Parameters:
  ///   - app: A custom `FirebaseApp` used for initialization; if not specified, uses the default
  ///     ``FirebaseApp``.
  ///   - backend: The backend API for the Firebase AI SDK; if not specified, uses the default
  ///     ``Backend/googleAI()`` (Gemini Developer API).
  ///   - useLimitedUseAppCheckTokens: When sending tokens to the backend, this option enables
  ///     the usage of App Check's limited-use tokens instead of the standard cached tokens. Learn
  ///     more about [limited-use tokens](https://firebase.google.com/docs/ai-logic/app-check),
  ///     including their nuances, when to use them, and best practices for integrating them into
  ///     your app.
  ///
  ///     _This flag is set to `false` by default._
  ///   > Migrating to limited-use tokens sooner minimizes disruption when support for replay
  ///   > protection is added.
  /// - Returns: An `AILogic` instance, configured with the custom `FirebaseApp`.
  static func firebaseAI(app: FirebaseApp? = nil, backend: Backend = .googleAI(),
                         useLimitedUseAppCheckTokens: Bool = false) -> AILogic {
    aiLogic(
      app: app, backend: backend, useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
  }
}
