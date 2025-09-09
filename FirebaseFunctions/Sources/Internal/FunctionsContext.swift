// Copyright 2022 Google LLC
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

@preconcurrency import FirebaseAppCheckInterop
@preconcurrency import FirebaseAuthInterop
@preconcurrency import FirebaseMessagingInterop
import Foundation

/// `FunctionsContext` is a helper object that holds metadata for a function call.
struct FunctionsContext {
  let authToken: String?
  let fcmToken: String?
  let appCheckToken: String?
  let limitedUseAppCheckToken: String?
}

struct FunctionsContextProvider: Sendable {
  private let auth: AuthInterop?
  private let messaging: MessagingInterop?
  private let appCheck: AppCheckInterop?

  init(auth: AuthInterop?, messaging: MessagingInterop?, appCheck: AppCheckInterop?) {
    self.auth = auth
    self.messaging = messaging
    self.appCheck = appCheck
  }

  func context(options: HTTPSCallableOptions?) async throws -> FunctionsContext {
    async let authToken = auth?.getToken(forcingRefresh: false)
    async let appCheckToken = getAppCheckToken(options: options)
    async let limitedUseAppCheckToken = getLimitedUseAppCheckToken(options: options)

    // Only `authToken` is throwing, but the formatter script removes the `try`
    // from `try authToken` and puts it in front of the initializer call.
    return try await FunctionsContext(
      authToken: authToken,
      fcmToken: messaging?.fcmToken,
      appCheckToken: appCheckToken,
      limitedUseAppCheckToken: limitedUseAppCheckToken
    )
  }

  private func getAppCheckToken(options: HTTPSCallableOptions?) async -> String? {
    guard
      options?.requireLimitedUseAppCheckTokens != true,
      let tokenResult = await appCheck?.getToken(forcingRefresh: false)
    else { return nil }
    // The placeholder token should be used in the case of App Check error.
    return tokenResult.token
  }

  private func getLimitedUseAppCheckToken(options: HTTPSCallableOptions?) async -> String? {
    // At the moment, `await` doesn’t get along with Objective-C’s optional protocol methods.
    await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
      guard
        options?.requireLimitedUseAppCheckTokens == true,
        let appCheck,
        // `getLimitedUseToken(completion:)` is an optional protocol method. Optional binding
        // is performed to make sure `continuation` is called even if the method’s not implemented.
        let limitedUseTokenClosure = appCheck.getLimitedUseToken
      else {
        return continuation.resume(returning: nil)
      }

      limitedUseTokenClosure { tokenResult in
        // The placeholder token should be used in the case of App Check error.
        continuation.resume(returning: tokenResult.token)
      }
    }
  }
}
