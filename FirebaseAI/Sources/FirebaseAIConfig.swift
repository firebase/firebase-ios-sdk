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

/// Configuration options for ``FirebaseAI``, which persists across all models.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FirebaseAIConfig: Sendable, Hashable, Encodable {
  /// Options for App Check specific behavior within a ``FirebaseAI`` instance.
  let appCheck: AppCheckOptions

  /// Creates a new ``FirebaseAI`` value.
  ///
  /// - Parameters:
  ///   - appCheck: Optionally configure certain behavior with how App Check is used.
  public init(appCheck: AppCheckOptions = AppCheckOptions()) {
    self.appCheck = appCheck
  }
}

/// Configurable options for how App Check is used within a ``FirebaseAI`` instance.
///
/// Can be set when creating a ``FirebaseAIConfig``.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct AppCheckOptions: Sendable, Hashable, Encodable {
  /// Use `limitedUseTokens`, instead of the standard cached tokens, when sending requests
  /// to the backend.
  let requireLimitedUseTokens: Bool

  /// Creates a new ``AppCheckOptions`` value.
  ///
  /// - Parameters:
  ///   - requiredLimitedUseTokens: When sending tokens to the backend, this option enables
  ///     the usage of App Check's `limitedUseTokens` instead of the standard cached tokens.
  ///
  ///     A new `limitedUseToken` will be generated for each request; providing a lower attack
  ///     surface for malicious parties to hijack tokens. When used alongside [replay protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay-protection),
  ///     `limitedUseTokens` are also _consumed_ after each request, ensuring they can't be used
  ///     again.
  ///
  ///     _To prevent breakage, this flag is set to `false` by default._
  ///
  ///     > Important: Replay protection is not currently supported for the FirebaseAI backend.
  ///     > While this feature is being developed, you can still migrate to using `limitedUseTokens`.
  ///     > Because `limitedUseTokens` are backwards compatable, you can still use them without replay
  ///     > protection. Due to their shorter TTL over standard App Check tokens, they still provide a
  ///     > security benefit.
  ///     >
  ///     > Migrating to `limitedUseTokens` ahead of time will also allow you to enable replay
  ///     > protection down the road (when support is added), without breaking your users.
  public init(requiredLimitedUseTokens: Bool = false) {
    requireLimitedUseTokens = requiredLimitedUseTokens
  }
}
