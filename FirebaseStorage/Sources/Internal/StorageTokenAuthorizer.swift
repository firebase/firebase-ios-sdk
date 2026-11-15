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
internal import FirebaseCoreExtension

/// Adds the headers that every authorized Storage request carries.
final class StorageTokenAuthorizer {
  /// Returns `request` with the headers that every Storage request carries: the SDK version, the
  /// app ID, and the Auth and App Check tokens when they're available.
  ///
  /// It gets the tokens again on every call, so call it before every attempt of a request.
  ///
  /// - Throws: A `StorageError.unauthenticated` error if getting the Auth token fails, or if the
  ///   request would send tokens over HTTP to a host that isn't a loopback address.
  func authorize(_ request: URLRequest) async throws -> URLRequest {
    var request = request
    // Set version header on each request
    let versionString = "ios/\(FirebaseVersion())"
    request.setValue(versionString, forHTTPHeaderField: "x-firebase-storage-version")

    // Set GMP ID on each request
    request.setValue(googleAppID, forHTTPHeaderField: "x-firebase-gmpid")

    let scheme = request.url?.scheme?.lowercased()
    let isHttps = scheme == "https"
    let host = request.url?.host?.lowercased() ?? ""
    let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    #if DEBUG
      let shouldAttachTokens = isHttps || isLoopback || allowInsecureTokenAttachment()
    #else
      let shouldAttachTokens = isHttps || isLoopback
    #endif

    // Get both tokens at the same time.
    async let authToken = Self.authToken(from: auth)
    async let appCheckToken = Self.appCheckToken(from: appCheck)

    var tokenError: NSError?
    switch await authToken {
    case let .success(token?):
      request.setValue("Firebase \(token)", forHTTPHeaderField: "Authorization")
    case .success(nil):
      break
    case let .failure(error):
      var errorDictionary = error.userInfo
      errorDictionary["ResponseErrorDomain"] = error.domain
      errorDictionary["ResponseErrorCode"] = error.code
      tokenError = StorageError.unauthenticated(serverError: errorDictionary) as NSError
    }
    if let appCheckToken = await appCheckToken {
      request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
    }

    let tokensWereAttached = request.value(forHTTPHeaderField: "Authorization") != nil ||
      request.value(forHTTPHeaderField: "X-Firebase-AppCheck") != nil

    if tokensWereAttached && !shouldAttachTokens && scheme == "http" {
      // Strip tokens so credentials aren't transmitted over cleartext HTTP
      request.setValue(nil, forHTTPHeaderField: "Authorization")
      request.setValue(nil, forHTTPHeaderField: "X-Firebase-AppCheck")

      FirebaseLogger.log(
        level: .warning,
        service: "[FirebaseStorage]",
        code: "I-STR000002",
        message: "Refusing to send Auth and AppCheck tokens over HTTP to non-loopback host."
      )
      tokenError = StorageError
        .unauthenticated(
          serverError: [
            "message": "Refusing to send Auth and AppCheck tokens over HTTP to non-loopback host.",
          ]
        ) as NSError
    }

    if let tokenError {
      throw tokenError
    }
    return request
  }

  /// Returns the signed-in user's Auth token, `nil` if there's no Auth or no signed-in user, or
  /// the error from Auth.
  private static func authToken(from auth: AuthInterop?) async -> Result<String?, NSError> {
    guard let auth else {
      return .success(nil)
    }
    return await withCheckedContinuation { continuation in
      auth.getToken(forcingRefresh: false) { token, error in
        if let error {
          continuation.resume(returning: .failure(error as NSError))
        } else {
          continuation.resume(returning: .success(token))
        }
      }
    }
  }

  /// Returns the App Check token, or `nil` if there's no App Check. If getting a token fails,
  /// App Check provides a placeholder token, which is still sent.
  private static func appCheckToken(from appCheck: AppCheckInterop?) async -> String? {
    guard let appCheck else {
      return nil
    }
    return await withCheckedContinuation { continuation in
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
  }

  private let googleAppID: String
  private let auth: AuthInterop?
  private let appCheck: AppCheckInterop?
  #if DEBUG
    private let allowInsecureTokenAttachment: () -> Bool
  #endif

  init(googleAppID: String,
       authProvider: AuthInterop?,
       appCheck: AppCheckInterop?,
       allowInsecureTokenAttachment: @escaping () -> Bool = { false }) {
    self.googleAppID = googleAppID
    auth = authProvider
    self.appCheck = appCheck
    #if DEBUG
      self.allowInsecureTokenAttachment = allowInsecureTokenAttachment
    #endif
  }

  /// Creates an authorizer for the requests of `storage`.
  convenience init(storage: Storage) {
    self.init(
      googleAppID: storage.app.options.googleAppID,
      authProvider: storage.auth,
      appCheck: storage.appCheck,
      allowInsecureTokenAttachment: { [weak storage] in
        #if DEBUG
          return storage?.allowInsecureTokenAttachment ?? false
        #else
          return false
        #endif
      }
    )
  }
}
