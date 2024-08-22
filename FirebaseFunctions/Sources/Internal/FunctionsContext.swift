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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseMessagingInterop
import Foundation

/// `FunctionsContext` is a helper object that holds metadata for a function call.
struct FunctionsContext {
  let authToken: String?
  let fcmToken: String?
  let appCheckToken: String?
  let limitedUseAppCheckToken: String?
}

struct FunctionsContextProvider {
  private let auth: AuthInterop?
  private let messaging: MessagingInterop?
  private let appCheck: AppCheckInterop?

  init(auth: AuthInterop?, messaging: MessagingInterop?, appCheck: AppCheckInterop?) {
    self.auth = auth
    self.messaging = messaging
    self.appCheck = appCheck
  }

  // TODO: Implement async await version
//  @available(macOS 10.15.0, *)
//  internal func getContext() async throws -> FunctionsContext {
//    return FunctionsContext(authToken: nil, fcmToken: nil, appCheckToken: nil)
//
//  }

  func getContext(options: HTTPSCallableOptions? = nil,
                  _ completion: @escaping ((FunctionsContext, Error?) -> Void)) {
    let dispatchGroup = DispatchGroup()

    var authToken: String?
    var appCheckToken: String?
    var error: Error?
    var limitedUseAppCheckToken: String?

    if let auth {
      dispatchGroup.enter()

      auth.getToken(forcingRefresh: false) { token, authError in
        authToken = token
        error = authError
        dispatchGroup.leave()
      }
    }

    if let appCheck {
      dispatchGroup.enter()

      if options?.requireLimitedUseAppCheckTokens == true {
        appCheck.getLimitedUseToken? { tokenResult in
          // Send only valid token to functions.
          if tokenResult.error == nil {
            limitedUseAppCheckToken = tokenResult.token
          }
          dispatchGroup.leave()
        }
      } else {
        appCheck.getToken(forcingRefresh: false) { tokenResult in
          // Send only valid token to functions.
          if tokenResult.error == nil {
            appCheckToken = tokenResult.token
          }
          dispatchGroup.leave()
        }
      }
    }

    dispatchGroup.notify(queue: .main) {
      let context = FunctionsContext(authToken: authToken,
                                     fcmToken: self.messaging?.fcmToken,
                                     appCheckToken: appCheckToken,
                                     limitedUseAppCheckToken: limitedUseAppCheckToken)
      completion(context, error)
    }
  }
}
