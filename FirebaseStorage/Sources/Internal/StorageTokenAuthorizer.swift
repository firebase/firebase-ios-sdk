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

@preconcurrency import FirebaseAppCheckInterop /* TODO: sendable */
import FirebaseAuthInterop
import FirebaseCore
@_implementationOnly import FirebaseCoreExtension

#if COCOAPODS
  @preconcurrency import GTMSessionFetcher
#else
  @preconcurrency import GTMSessionFetcherCore
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class StorageTokenAuthorizer: NSObject, GTMSessionFetcherAuthorizer, Sendable {
  func authorizeRequest(_ request: NSMutableURLRequest?,
                        completionHandler handler: @escaping (Error?) -> Void) {
    if let request = request {
      Task {
        do {
          try await self._authorizeRequest(request)
          handler(nil)
        } catch {
          handler(error)
        }
      }
    }
  }

  private func _authorizeRequest(_ request: NSMutableURLRequest) async throws {
    // Set version header on each request
    let versionString = "ios/\(FirebaseVersion())"
    request.setValue(versionString, forHTTPHeaderField: "x-firebase-storage-version")

    // Set GMP ID on each request
    request.setValue(googleAppID, forHTTPHeaderField: "x-firebase-gmpid")

    if let auth {
      let token: String = try await withCheckedThrowingContinuation { continuation in
        auth.getToken(forcingRefresh: false) { token, error in
          if let error = error as? NSError {
            var errorDictionary = error.userInfo
            errorDictionary["ResponseErrorDomain"] = error.domain
            errorDictionary["ResponseErrorCode"] = error.code
            let wrappedError = StorageError.unauthenticated(serverError: errorDictionary) as Error
            continuation.resume(throwing: wrappedError)
          } else if let token {
            let firebaseToken = "Firebase \(token)"
            continuation.resume(returning: firebaseToken)
          } else {
            let underlyingError: [String: Any]
            if let error = error {
              underlyingError = [NSUnderlyingErrorKey: error]
            } else {
              underlyingError = [:]
            }
            let unknownError = StorageError.unknown(
              message: "Auth token fetch returned no token or error: \(token ?? "nil")",
              serverError: underlyingError
            ) as Error
            continuation.resume(throwing: unknownError)
          }
        }
      }
      request.setValue(token, forHTTPHeaderField: "Authorization")
    }
    if let appCheck {
      let token = await withCheckedContinuation { continuation in
        appCheck.getToken(forcingRefresh: false) { tokenResult in
          if let error = tokenResult.error {
            FirebaseLogger.log(
              level: .debug,
              service: "[FirebaseStorage]",
              code: "I-STR000001",
              message: "Failed to fetch AppCheck token. Error: \(error)"
            )
          }
          continuation.resume(returning: tokenResult.token)
        }
      }
      request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
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

  // Used for protocol conformance only.
  let userEmail: String? = nil

  let callbackQueue: DispatchQueue
  private let googleAppID: String
  private let auth: AuthInterop?
  private let appCheck: AppCheckInterop?

  private let serialAuthArgsQueue = DispatchQueue(label: "com.google.firebasestorage.authorizer")

  init(googleAppID: String,
       callbackQueue: DispatchQueue = DispatchQueue.main,
       authProvider: AuthInterop?,
       appCheck: AppCheckInterop?) {
    self.googleAppID = googleAppID
    self.callbackQueue = callbackQueue
    auth = authProvider
    self.appCheck = appCheck
  }
}
