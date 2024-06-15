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

enum AuthRecaptchaProvider: String, CaseIterable {
  case password = "EMAIL_PASSWORD_PROVIDER"
  case phone = "PHONE_PROVIDER" // Add phone provider
  
    // Convenience property for mapping values
  var stringValue: String { self.rawValue }
}

enum AuthRecaptchaAction: String {
  case defaultAction = "defaultAction"
  case signInWithPassword = "signInWithPassword"
  case getOobCode = "getOobCode"
  case signUpPassword = "signUpPassword"
  case sendVerificationCode = "sendVerificationCode"
  
    // Convenience property for mapping values
  var stringValue: String { self.rawValue }
}

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthRecaptchaVerifier {
    private(set) weak var auth: Auth?
    private(set) var agentConfig: AuthRecaptchaConfig?
    private(set) var tenantConfigs: [String: AuthRecaptchaConfig] = [:]
    private(set) var recaptchaClient: RCARecaptchaClientProtocol?

    private static let _shared = AuthRecaptchaVerifier()
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
      if let tenantID = auth?.tenantID,
          let tenantConfig = tenantConfigs[tenantID],
         let status = tenantConfig.enablementStatus[provider.stringValue] {
        return status
      } else if let agentConfig = agentConfig,
                let status = agentConfig.enablementStatus[provider.stringValue] {
        return status
      } else {
        return false
      }
    }

    func verify(forceRefresh: Bool, action: AuthRecaptchaAction) async throws -> String {
      try await retrieveRecaptchaConfig(forceRefresh: forceRefresh)
      if recaptchaClient == nil {
        guard let siteKey = siteKey(),
              let RecaptchaClass = NSClassFromString("Recaptcha"),
              let recaptcha = RecaptchaClass as? any RCARecaptchaProtocol.Type else {
          throw AuthErrorUtils.recaptchaSDKNotLinkedError()
        }
        recaptchaClient = try await recaptcha.getClient(withSiteKey: siteKey)
      }
      return try await retrieveRecaptchaToken(withAction: action)
    }

    func retrieveRecaptchaToken(withAction action: AuthRecaptchaAction) async throws -> String {
      let actionString = action.stringValue
      guard let RecaptchaActionClass = NSClassFromString("RecaptchaAction"),
            let actionClass = RecaptchaActionClass as? any RCAActionProtocol.Type else {
        throw AuthErrorUtils.recaptchaSDKNotLinkedError()
      }
      let customAction = actionClass.init(customAction: actionString)
      do {
        let token = try await recaptchaClient?.execute(withAction: customAction)
        AuthLog.logInfo(code: "I-AUT000100", message: "reCAPTCHA token retrieval succeeded.")
        guard let token else {
          AuthLog.logInfo(
            code: "I-AUT000101",
            message: "reCAPTCHA token retrieval returned nil. NO_RECAPTCHA sent as the fake code."
          )
          return "NO_RECAPTCHA"
        }
        return token
      } catch {
        AuthLog.logInfo(code: "I-AUT000102",
                        message: "reCAPTCHA token retrieval failed. NO_RECAPTCHA sent as the fake code.")
        return "NO_RECAPTCHA"
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

      guard let requestConfiguration = auth?.requestConfiguration else {
        throw AuthErrorUtils.error(code: .recaptchaNotEnabled,
                                   message: "No requestConfiguration for Auth instance")
      }
      let request = GetRecaptchaConfigRequest(requestConfiguration: requestConfiguration)
      let response = try await AuthBackend.call(with: request)
      AuthLog.logInfo(code: "I-AUT000103", message: "reCAPTCHA config retrieval succeeded.")
      // Response's site key is of the format projects/<project-id>/keys/<site-key>'
      guard let keys = response.recaptchaKey?.components(separatedBy: "/"),
            keys.count == 4 else {
        throw AuthErrorUtils.error(code: .recaptchaNotEnabled, message: "Invalid siteKey")
      }
      let siteKey = keys[3]
      var enablementStatus: [String: Bool] = [:]
      if let enforcementState = response.enforcementState {
        for state in enforcementState {
          if let providerString = state["provider"],
             let enforcement = state["enforcementState"],
             let provider = AuthRecaptchaProvider(rawValue: providerString) { // Try to get enum from raw value
            switch enforcement {
            case "ENFORCE", "AUDIT":
              enablementStatus[provider.stringValue] = true
            case "OFF":
              enablementStatus[provider.stringValue] = false
            default:
              break // Handle unknown enforcement states if necessary
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
