// Copyright 2026 Google LLC
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
import Foundation

#if SWIFT_PACKAGE
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import AppCheckCore
internal import FirebaseCoreExtension

/// The subset of the App Check Core debug provider used by `AppCheckDebugProvider`.
@objc protocol AppCheckCoreDebugProviding: AppCheckCoreProvider {
  var debugTokenSource: AppCheckCoreDebugTokenSource { get }
  func localDebugToken() -> String
  func currentDebugToken() -> String
}

extension AppCheckCoreDebugProvider: AppCheckCoreDebugProviding {}

/// Implements `FIRAppCheckDebugProvider`, declared in `FIRAppCheckDebugProvider.h`.
@objc @implementation extension AppCheckDebugProvider {
  final let debugProvider: AppCheckCoreDebugProviding
  final let projectID: String?
  final let googleAppID: String

  /// Where the App Check Core debug provider got its debug token from.
  final var debugTokenSource: AppCheckCoreDebugTokenSource {
    debugProvider.debugTokenSource
  }

  private init(debugProvider: AppCheckCoreDebugProviding,
               projectID: NSString?,
               googleAppID: NSString) {
    self.debugProvider = debugProvider
    self.projectID = projectID as String?
    self.googleAppID = googleAppID as String
    super.init()
    logDebugTokenSource()
  }

  /// Creates a provider that wraps a fake App Check Core debug provider. For tests.
  final class func makeForTesting(debugProvider: AppCheckCoreDebugProviding,
                                  projectID: String?,
                                  googleAppID: String) -> AppCheckDebugProvider {
    AppCheckDebugProvider(debugProvider: debugProvider,
                          projectID: projectID as NSString?,
                          googleAppID: googleAppID as NSString)
  }

  @objc(initWithApp:)
  init?(app: FirebaseApp) {
    let missingOptionsFields = AppCheckValidator.tokenExchangeMissingFields(in: app.options)
    if !missingOptionsFields.isEmpty {
      AppCheckLogger.log(
        .error,
        .debugProviderIncompleteFIROptions,
        "Cannot instantiate `FIRAppCheckDebugProvider` for app: \(app.name). The following "
          + "`FirebaseOptions` fields are missing: "
          + missingOptionsFields.joined(separator: ", ")
      )
      return nil
    }

    let configStoreDebugToken =
      DebugTokenConfigStore.debugToken(forGoogleAppID: app.options.googleAppID)
    let debugProvider = AppCheckCoreDebugProvider(serviceName: app.name,
                                                  resourceName: app.resourceName,
                                                  baseURL: nil,
                                                  apiKey: app.options.apiKey ?? "",
                                                  requestHooks: app.appCheckRequestHooks,
                                                  debugToken: configStoreDebugToken)
    self.debugProvider = debugProvider
    projectID = app.options.projectID
    googleAppID = app.options.googleAppID
    super.init()
    logDebugTokenSource()
  }

  func localDebugToken() -> String {
    debugProvider.localDebugToken()
  }

  func currentDebugToken() -> String {
    debugProvider.currentDebugToken()
  }

  @objc(getTokenWithCompletion:)
  func getToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void) {
    let completion = appCheckTokenCompletion(handler)
    debugProvider.getToken { internalToken, error in
      if let error {
        self.logDebugTokenExchangeError(error)
      }
      completion(internalToken, error)
    }
  }

  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?)
    -> Void) {
    let completion = appCheckTokenCompletion(handler)
    debugProvider.getLimitedUseToken { internalToken, error in
      if let error {
        self.logDebugTokenExchangeError(error)
      }
      completion(internalToken, error)
    }
  }
}

extension AppCheckDebugProvider {
  // MARK: - Logging

  private func logDebugTokenSource() {
    switch debugTokenSource {
    case .local:
      logDebugTokenMessage(code: .debugToken, prefix: "")
    case .provided:
      AppCheckLogger.log(
        .notice,
        .debugTokenFromConfigStore,
        "Debug token loaded from ~/\(DebugTokenConfigStore.relativePath)."
      )
    case .environmentVariable:
      break
    @unknown default:
      break
    }
  }

  private func logDebugTokenMessage(code: AppCheckMessageCode, prefix: String) {
    guard let projectID, !projectID.isEmpty, !googleAppID.isEmpty else {
      return
    }
    let debugToken = localDebugToken()
    guard !debugToken.isEmpty else {
      return
    }
    AppCheckLogger.log(
      .warning,
      code,
      "\(prefix)"
        + "To use this token for app debugging, register it with your project.\n\n"
        + "Firebase App Check debug token: \(debugToken)\n\n"
        + "You can do so in the Firebase Console: \n"
        + "https://console.firebase.google.com/project/\(projectID)/appcheck/apps?selectedAppId="
        + "\(googleAppID) \n\n"
        + "Or using the Firebase CLI: \n"
        + "firebase appcheck:debugtokens:create \(debugToken) --project \(projectID) "
        + "--app \(googleAppID)\n\n"
        + "Note: To keep your project secure, please revoke and delete this token using the \n"
        + "Firebase Console or the CLI (`firebase appcheck:debugtokens:delete`) when you finish "
        + "debugging.\n\n"
        + "Warning: This debug token is a secret and should not be shared or uploaded to source "
        + "code.\n\n"
        + "Debug Token Guide: https://firebase.google.com/docs/app-check/ios/debug-provider\n"
        + "Firebase CLI install instructions: https://firebase.google.com/docs/cli\n"
    )
  }

  private func logDebugTokenExchangeError(_ error: Error) {
    if debugTokenSource == .local {
      logDebugTokenMessage(code: .debugTokenExchangeFailed,
                           prefix: "Failed to exchange debug token. ")
      return
    }

    guard let message = debugTokenExchangeFailureMessage(for: error) else {
      return
    }
    let code: AppCheckMessageCode = debugTokenSource == .provided
      ? .configStoreDebugTokenExchangeFailed
      : .debugTokenExchangeFailed
    AppCheckLogger.log(.warning, code, message)
  }

  func debugTokenExchangeFailureMessage(for error: Error) -> String? {
    let error = error as NSError
    if error.domain == AppCheckCoreErrorDomain,
       error.code == AppCheckCoreErrorCode.serverUnreachable.rawValue {
      return nil
    }

    let projectArgument: String
    if let projectID, !projectID.isEmpty {
      projectArgument = " --project \(projectID)"
    } else {
      projectArgument = ""
    }
    let errorDescription = error.localizedFailureReason ?? error.localizedDescription

    switch debugTokenSource {
    case .provided:
      return "Failed to exchange the debug token loaded from "
        + "~/\(DebugTokenConfigStore.relativePath): \(errorDescription)\n\n"
        + "If the token was rejected by the server, run "
        + "`firebase appcheck:debugtokens:create --force\(projectArgument) --app \(googleAppID)` "
        + "to provision a new token, then relaunch the app."
    case .environmentVariable:
      return "Failed to exchange the debug token from the `AppCheckDebugToken` or "
        + "`FIRAAppCheckDebugToken` environment variable: \(errorDescription)\n\n"
        + "Make sure the token is registered for app \(googleAppID), for example with "
        + "`firebase appcheck:debugtokens:create <token>\(projectArgument) --app \(googleAppID)`."
    case .local:
      return nil
    @unknown default:
      return nil
    }
  }
}

/// Implements `FIRAppCheckDebugProviderFactory`, declared in `FIRAppCheckDebugProviderFactory.h`.
@objc @implementation extension AppCheckDebugProviderFactory {
  override init() {
    super.init()
  }

  @objc(createProviderWithApp:)
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    AppCheckDebugProvider(app: app)
  }
}
