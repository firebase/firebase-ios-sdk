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
    var siteKey: String?
    let enablementStatus: [AuthRecaptchaProvider: AuthRecaptchaEnablementStatus]

    init(siteKey: String? = nil,
         enablementStatus: [AuthRecaptchaProvider: AuthRecaptchaEnablementStatus]) {
      self.siteKey = siteKey
      self.enablementStatus = enablementStatus
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  enum AuthRecaptchaEnablementStatus: String, CaseIterable {
    case enforce = "ENFORCE"
    case audit = "AUDIT"
    case off = "OFF"

    // Convenience property for mapping values
    var stringValue: String { rawValue }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  enum AuthRecaptchaProvider: String, CaseIterable {
    case password = "EMAIL_PASSWORD_PROVIDER"
    case phone = "PHONE_PROVIDER"

    // Convenience property for mapping values
    var stringValue: String { rawValue }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  enum AuthRecaptchaAction: String {
    case defaultAction
    case signInWithPassword
    case getOobCode
    case signUpPassword
    case sendVerificationCode
    case mfaSmsSignIn
    case mfaSmsEnrollment

    // Convenience property for mapping values
    var stringValue: String { rawValue }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthRecaptchaVerifier {
    private(set) weak var auth: Auth?
    private(set) var agentConfig: AuthRecaptchaConfig?
    private(set) var tenantConfigs: [String: AuthRecaptchaConfig] = [:]
    private(set) var recaptchaClient: RCARecaptchaClientProtocol?
    private static var _shared = AuthRecaptchaVerifier()
    private let kRecaptchaVersion = "RECAPTCHA_ENTERPRISE"
    init() {}

    class func shared(auth: Auth?) -> AuthRecaptchaVerifier {
      if _shared.auth != auth {
        _shared.agentConfig = nil
        _shared.tenantConfigs = [:]
        _shared.auth = auth
      }
      return _shared
    }

    /// This function is only for testing.
    class func setShared(_ instance: AuthRecaptchaVerifier, auth: Auth?) {
      _shared = instance
      _ = shared(auth: auth)
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

    func enablementStatus(forProvider provider: AuthRecaptchaProvider)
      -> AuthRecaptchaEnablementStatus {
      if let tenantID = auth?.tenantID,
         let tenantConfig = tenantConfigs[tenantID],
         let status = tenantConfig.enablementStatus[provider] {
        return status
      } else if let agentConfig = agentConfig,
                let status = agentConfig.enablementStatus[provider] {
        return status
      } else {
        return AuthRecaptchaEnablementStatus.off
      }
    }

    func verify(forceRefresh: Bool, action: AuthRecaptchaAction) async throws -> String {
      try await retrieveRecaptchaConfig(forceRefresh: forceRefresh)
      guard let siteKey = siteKey() else {
        throw AuthErrorUtils.recaptchaSiteKeyMissing()
      }
      let actionString = action.stringValue
      #if !(COCOAPODS || SWIFT_PACKAGE)
        // No recaptcha on internal build system.
        return actionString
      #else

        let (token, error, linked, actionCreated) = await recaptchaToken(
          siteKey: siteKey,
          actionString: actionString,
          fakeToken: "NO_RECAPTCHA"
        )

        guard linked else {
          throw AuthErrorUtils.recaptchaSDKNotLinkedError()
        }
        guard actionCreated else {
          throw AuthErrorUtils.recaptchaActionCreationFailed()
        }
        if let error {
          throw error
        }
        if token == "NO_RECAPTCHA" {
          AuthLog.logInfo(code: "I-AUT000031",
                          message: "reCAPTCHA token retrieval failed. NO_RECAPTCHA sent as the fake code.")
        } else {
          AuthLog.logInfo(
            code: "I-AUT000030",
            message: "reCAPTCHA token retrieval succeeded."
          )
        }
        return token
      #endif // !(COCOAPODS || SWIFT_PACKAGE)
    }

    private static var recaptchaClient: (any RCARecaptchaClientProtocol)?

    #if COCOAPODS || SWIFT_PACKAGE // No recaptcha on internal build system.
      private func recaptchaToken(siteKey: String,
                                  actionString: String,
                                  fakeToken: String) async -> (token: String, error: Error?,
                                                               linked: Bool, actionCreated: Bool) {
        if let recaptchaClient {
          return await retrieveToken(
            actionString: actionString,
            fakeToken: fakeToken,
            recaptchaClient: recaptchaClient
          )
        }

        if let recaptcha =
          NSClassFromString("RecaptchaEnterprise.RCARecaptcha") as? RCARecaptchaProtocol.Type {
          do {
            let client = try await recaptcha.fetchClient(withSiteKey: siteKey)
            recaptchaClient = client
            return await retrieveToken(
              actionString: actionString,
              fakeToken: fakeToken,
              recaptchaClient: client
            )
          } catch {
            return ("", error, true, true)
          }
        } else {
          // RecaptchaEnterprise not linked.
          return ("", nil, false, false)
        }
      }
    #endif // (COCOAPODS || SWIFT_PACKAGE)

    private func retrieveToken(actionString: String,
                               fakeToken: String,
                               recaptchaClient: RCARecaptchaClientProtocol) async -> (token: String,
                                                                                      error: Error?,
                                                                                      linked: Bool,
                                                                                      actionCreated: Bool) {
      if let recaptchaAction =
        NSClassFromString("RecaptchaEnterprise.RCAAction") as? RCAActionProtocol.Type {
        let action = recaptchaAction.init(customAction: actionString)
        let token = try? await recaptchaClient.execute(withAction: action)
        return (token ?? "NO_RECAPTCHA", nil, true, true)
      } else {
        // RecaptchaEnterprise not linked.
        return ("", nil, false, false)
      }
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

      guard let auth = auth else {
        throw AuthErrorUtils.error(code: .recaptchaNotEnabled,
                                   message: "No requestConfiguration for Auth instance")
      }
      let request = GetRecaptchaConfigRequest(requestConfiguration: auth.requestConfiguration)
      let response = try await auth.backend.call(with: request)
      AuthLog.logInfo(code: "I-AUT000029", message: "reCAPTCHA config retrieval succeeded.")
      try await parseRecaptchaConfigFromResponse(response: response)
    }

    func parseRecaptchaConfigFromResponse(response: GetRecaptchaConfigResponse) async throws {
      var enablementStatus: [AuthRecaptchaProvider: AuthRecaptchaEnablementStatus] = [:]
      var isRecaptchaEnabled = false
      if let enforcementState = response.enforcementState {
        for state in enforcementState {
          guard let providerString = state["provider"],
                let enforcementString = state["enforcementState"],
                let provider = AuthRecaptchaProvider(rawValue: providerString),
                let enforcement = AuthRecaptchaEnablementStatus(rawValue: enforcementString) else {
            continue // Skip to the next state in the loop
          }
          enablementStatus[provider] = enforcement
          if enforcement != .off {
            isRecaptchaEnabled = true
          }
        }
      }
      var siteKey = ""
      // Response's site key is of the format projects/<project-id>/keys/<site-key>'
      if isRecaptchaEnabled {
        if let recaptchaKey = response.recaptchaKey {
          let keys = recaptchaKey.components(separatedBy: "/")
          if keys.count != 4 {
            throw AuthErrorUtils.error(code: .recaptchaNotEnabled, message: "Invalid siteKey")
          }
          siteKey = keys[3]
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
      if enablementStatus(forProvider: provider) != .off {
        let token = try await verify(forceRefresh: false, action: action)
        request.injectRecaptchaFields(recaptchaResponse: token, recaptchaVersion: kRecaptchaVersion)
      } else {
        request.injectRecaptchaFields(recaptchaResponse: nil, recaptchaVersion: kRecaptchaVersion)
      }
    }
  }
#endif
