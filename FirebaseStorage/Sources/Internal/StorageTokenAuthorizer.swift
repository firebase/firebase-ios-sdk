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

import Foundation

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
@_implementationOnly import FirebaseCoreExtension

#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

internal class StorageTokenAuthorizer: NSObject, GTMSessionFetcherAuthorizer {
  func authorizeRequest(_ request: NSMutableURLRequest?,
                        completionHandler handler: @escaping (Error?) -> Void) {
    // Set version header on each request
    let versionString = "ios/\(FirebaseVersion())"
    request?.setValue(versionString, forHTTPHeaderField: "x-firebase-storage-version")

    // Set GMP ID on each request
    request?.setValue(googleAppID, forHTTPHeaderField: "x-firebase-gmpid")

    var tokenError: NSError?
    let callbackQueue = fetcherService.callbackQueue ?? DispatchQueue.main
    let fetchTokenGroup = DispatchGroup()
    if let auth = auth {
      fetchTokenGroup.enter()
      auth.getToken(forcingRefresh: false) { token, error in
        if let error = error as? NSError {
          var errorDictionary = error.userInfo
          errorDictionary["ResponseErrorDomain"] = error.domain
          errorDictionary["ResponseErrorCode"] = error.code
          errorDictionary[NSLocalizedDescriptionKey] =
            "User is not authenticated, please authenticate" +
            " using Firebase Authentication and try again."
          tokenError = NSError(domain: "FIRStorageErrorDomain",
                               code: StorageErrorCode.unauthenticated.rawValue,
                               userInfo: errorDictionary)
        } else if let token = token {
          let firebaseToken = "Firebase \(token)"
          request?.setValue(firebaseToken, forHTTPHeaderField: "Authorization")
        }
        fetchTokenGroup.leave()
      }
    }
    if let appCheck = appCheck {
      fetchTokenGroup.enter()
      appCheck.getToken(forcingRefresh: false) { tokenResult in
        request?.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")

        if let error = tokenResult.error {
          FirebaseLogger.log(
            level: .debug,
            service: "[FirebaseStorage]",
            code: "I-STR000001",
            message: "Failed to fetch AppCheck token. Error: \(error)"
          )
        }
        fetchTokenGroup.leave()
      }
    }
    fetchTokenGroup.notify(queue: callbackQueue) {
      handler(tokenError)
    }
  }

  func authorizeRequest(_ request: NSMutableURLRequest?, delegate: Any, didFinish sel: Selector) {
    fatalError("Internal error: Should not call old authorizeRequest")
  }

  // Note that stopAuthorization, isAuthorizingRequest, and userEmail
  // aren't relevant with the Firebase App/Auth implementation of tokens,
  // and thus aren't implemented. Token refresh is handled transparently
  // for us, and we don't allow the auth request to be stopped.
  // Auth is also not required so the world doesn't stop.
  func stopAuthorization() {}

  func stopAuthorization(for request: URLRequest) {}

  func isAuthorizingRequest(_ request: URLRequest) -> Bool {
    return false
  }

  func isAuthorizedRequest(_ request: URLRequest) -> Bool {
    guard let authHeader = request.allHTTPHeaderFields?["Authorization"] else {
      return false
    }
    return authHeader.hasPrefix("Firebase")
  }

  var userEmail: String?

  internal let fetcherService: GTMSessionFetcherService
  private let googleAppID: String
  private let auth: AuthInterop?
  private let appCheck: AppCheckInterop?

  private let serialAuthArgsQueue = DispatchQueue(label: "com.google.firebasestorage.authorizer")

  init(googleAppID: String,
       fetcherService: GTMSessionFetcherService,
       authProvider: AuthInterop?,
       appCheck: AppCheckInterop?) {
    self.googleAppID = googleAppID
    self.fetcherService = fetcherService
    auth = authProvider
    self.appCheck = appCheck
  }
}
