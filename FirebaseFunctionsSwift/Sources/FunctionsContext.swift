// FULLY PORTED
//  File.swift
//  
//
//  Created by Ryan Wilson on 2022-01-25.
//

import Foundation

/// FunctionsContext is a helper class for gathering metadata for a function call.
internal class FunctionsContext: NSObject {
  let authToken: String?
  let fcmToken: String?
  let appCheckToken: String?

  init(authToken: String?, fcmToken: String?, appCheckToken: String?) {
    self.authToken = authToken
    self.fcmToken = fcmToken
    self.appCheckToken = appCheckToken
  }
}

internal class FunctionsContextProvider: NSObject {
  private var auth: AuthInterop?
  private var messaging: MessagingInterop?
  private var appCheck :AppCheckInterop?

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

  internal func getContext(_ completion:  @escaping ((FunctionsContext, Error?) -> Void)) {
    let dispatchGroup = DispatchGroup()

    var authToken: String? = nil
    var appCheckToken: String? = nil
    var error: Error? = nil

    if let auth = auth {
      dispatchGroup.enter()

      auth.getToken(forcingRefresh: false) { result in
        switch result {
        case .success(let token):
          authToken = token
        case .failure(let authError):
          error = authError
        }
        dispatchGroup.leave()
      }
    }

    if let appCheck = appCheck {
      dispatchGroup.enter()

      appCheck.getToken(forcingRefresh: false) { result in
        switch result {
        case .success(let token):
          appCheckToken = token
        case .failure(let authError):
          error = authError
        }
      }

      dispatchGroup.leave()
    }

    dispatchGroup.notify(queue: .main) {
      let context = FunctionsContext(authToken: authToken,
                                     fcmToken: self.messaging?.fcmToken,
                                     appCheckToken: appCheckToken)
      completion(context, error)
    }
  }
}
