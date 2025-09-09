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

import FirebaseAppCheckInterop

/// Internal helper extension for fetching app check tokens.
///
/// Provides a common means for fetching limited use tokens, and falling back to standard tokens
/// when it's disabled (or in debug mode). This also centrializes the error, since this method is
/// used in multiple places.
extension AppCheckInterop {
  /// Fetch the appcheck token.
  ///
  /// - Parameters:
  ///   - limitedUse: Should the token be a limited-use token, or a standard token.
  ///   - domain: A string dictating where this method is being called from. Used in any thrown
  ///     errors, to avoid hard-to-parse traces.
  func fetchAppCheckToken(limitedUse: Bool,
                          domain: String) async throws -> FIRAppCheckTokenResultInterop {
    if limitedUse {
      if let token = await getLimitedUseTokenAsync() {
        return token
      }

      let errorMessage =
        "The provided App Check token provider doesn't implement getLimitedUseToken(), but requireLimitedUseTokens was enabled."

      #if Debug
        fatalError(errorMessage)
      #else
        throw NSError(
          domain: "\(Constants.baseErrorDomain).\(domain)",
          code: AILog.MessageCode.appCheckTokenFetchFailed.rawValue,
          userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
      #endif
    }

    return await getToken(forcingRefresh: false)
  }

  private func getLimitedUseTokenAsync() async
    -> FIRAppCheckTokenResultInterop? {
    // At the moment, `await` doesn’t get along with Objective-C’s optional protocol methods.
    await withCheckedContinuation { (continuation: CheckedContinuation<
      FIRAppCheckTokenResultInterop?,
      Never
    >) in
      guard
        // `getLimitedUseToken(completion:)` is an optional protocol method. Optional binding
        // is performed to make sure `continuation` is called even if the method’s not implemented.
        let limitedUseTokenClosure = getLimitedUseToken
      else {
        return continuation.resume(returning: nil)
      }

      limitedUseTokenClosure { tokenResult in
        // The placeholder token should be used in the case of App Check error.
        continuation.resume(returning: tokenResult)
      }
    }
  }
}
