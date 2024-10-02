// Copyright 2023 Google LLC
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

#if os(iOS)

  import Foundation

  #if SWIFT_PACKAGE
    import FirebaseAuthInternal
  #endif
  import RecaptchaInterop

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthRecaptchaConfig {
    let siteKey: String
    let enablementStatus: [String: Bool]

    init(siteKey: String, enablementStatus: [String: Bool]) {
      self.siteKey = siteKey
      self.enablementStatus = enablementStatus
    }
  }

  enum AuthRecaptchaProvider {
    case password
  }

  enum AuthRecaptchaAction {
    case defaultAction
    case signInWithPassword
    case getOobCode
    case signUpPassword
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthRecaptchaVerifier {
    private(set) weak var auth: Auth?
    private(set) var agentConfig: AuthRecaptchaConfig?
    private(set) var tenantConfigs: [String: AuthRecaptchaConfig] = [:]
    private(set) var recaptchaClient: RCARecaptchaClientProtocol?

    private static let _shared = AuthRecaptchaVerifier()
    private let providerToStringMap = [AuthRecaptchaProvider.password: "EMAIL_PASSWORD_PROVIDER"]
    private let actionToStringMap = [AuthRecaptchaAction.signInWithPassword: "signInWithPassword",
                                     AuthRecaptchaAction.getOobCode: "getOobCode",
                                     AuthRecaptchaAction.signUpPassword: "signUpPassword"]
    private let kRecaptchaVersion = "RECAPTCHA_ENTERPRISE"
    private init() {}

    class func shared(auth: Auth?) -> AuthRecaptchaVerifier {
      if _shared.auth != auth {
        _shared.agentConfig = nil
        _shared.tenantConfigs = [:]
        _shared.auth = auth
      }
      return _shared
    }

    func siteKey() -> String? {
      if let tenantID = auth?.tenantID {
        if let config = tenantConfigs[tenantID] {
          return config.siteKey
        }
        return nil
      }
      return agentConfig?.siteKey
    }

    func enablementStatus(forProvider provider: AuthRecaptchaProvider) -> Bool {
      guard let providerString = providerToStringMap[provider] else {
        return false
      }
      if let tenantID = auth?.tenantID {
        guard let tenantConfig = tenantConfigs[tenantID],
              let status = tenantConfig.enablementStatus[providerString] else {
          return false
        }
        return status
      } else {
        guard let agentConfig,
              let status = agentConfig.enablementStatus[providerString] else {
          return false
        }
        return status
      }
    }

    func verify(forceRefresh: Bool, action: AuthRecaptchaAction) async throws -> String {
      try await retrieveRecaptchaConfig(forceRefresh: forceRefresh)
      guard let siteKey = siteKey() else {
        throw AuthErrorUtils.recaptchaSiteKeyMissing()
      }
      let actionString = actionToStringMap[action] ?? ""
      #if !(COCOAPODS || SWIFT_PACKAGE)
        // No recaptcha on internal build system.
        return actionString
      #else
        return try await withCheckedThrowingContinuation { continuation in
          FIRRecaptchaGetToken(siteKey, actionString,
                               "NO_RECAPTCHA") { (token: String, error: Error?,
                                                  linked: Bool, actionCreated: Bool) in
              guard linked else {
                continuation.resume(throwing: AuthErrorUtils.recaptchaSDKNotLinkedError())
                return
              }
              guard actionCreated else {
                continuation.resume(throwing: AuthErrorUtils.recaptchaActionCreationFailed())
                return
              }
              if let error {
                continuation.resume(throwing: error)
                return
              } else {
                if token == "NO_RECAPTCHA" {
                  AuthLog.logInfo(code: "I-AUT000031",
                                  message: "reCAPTCHA token retrieval failed. NO_RECAPTCHA sent as the fake code.")
                } else {
                  AuthLog.logInfo(
                    code: "I-AUT000030",
                    message: "reCAPTCHA token retrieval succeeded."
                  )
                }
                continuation.resume(returning: token)
              }
          }
        }
      #endif // !(COCOAPODS || SWIFT_PACKAGE)
    }

    func retrieveRecaptchaConfig(forceRefresh: Bool) async throws {
      if !forceRefresh {
        if let tenantID = auth?.tenantID {
          if tenantConfigs[tenantID] != nil {
            return
          }
        } else if agentConfig != nil {
          return
        }
      }

      guard let requestConfiguration = auth?.requestConfiguration else {
        throw AuthErrorUtils.error(code: .recaptchaNotEnabled,
                                   message: "No requestConfiguration for Auth instance")
      }
      let request = GetRecaptchaConfigRequest(requestConfiguration: requestConfiguration)
      let response = try await AuthBackend.call(with: request)
      AuthLog.logInfo(code: "I-AUT000029", message: "reCAPTCHA config retrieval succeeded.")
      // Response's site key is of the format projects/<project-id>/keys/<site-key>'
      guard let keys = response.recaptchaKey?.components(separatedBy: "/"),
            keys.count == 4 else {
        throw AuthErrorUtils.error(code: .recaptchaNotEnabled, message: "Invalid siteKey")
      }
      let siteKey = keys[3]
      var enablementStatus: [String: Bool] = [:]
      if let enforcementState = response.enforcementState {
        for state in enforcementState {
          if let provider = state["provider"],
             provider == providerToStringMap[AuthRecaptchaProvider.password] {
            if let enforcement = state["enforcementState"] {
              if enforcement == "ENFORCE" || enforcement == "AUDIT" {
                enablementStatus[provider] = true
              } else if enforcement == "OFF" {
                enablementStatus[provider] = false
              }
            }
          }
        }
      }
      let config = AuthRecaptchaConfig(siteKey: siteKey, enablementStatus: enablementStatus)

      if let tenantID = auth?.tenantID {
        tenantConfigs[tenantID] = config
      } else {
        agentConfig = config
      }
    }

    func injectRecaptchaFields(request: any AuthRPCRequest,
                               provider: AuthRecaptchaProvider,
                               action: AuthRecaptchaAction) async throws {
      try await retrieveRecaptchaConfig(forceRefresh: false)
      if enablementStatus(forProvider: provider) {
        let token = try await verify(forceRefresh: false, action: action)
        request.injectRecaptchaFields(recaptchaResponse: token, recaptchaVersion: kRecaptchaVersion)
      } else {
        request.injectRecaptchaFields(recaptchaResponse: nil, recaptchaVersion: kRecaptchaVersion)
      }
    }
  }
#endif
