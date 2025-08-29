// Copyright 2025 Google LLC
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

import FirebaseAILogic
import FirebaseAITestApp
import FirebaseCore
import Testing

@testable import struct FirebaseAILogic.APIConfig

struct InstanceConfig: Equatable, Encodable {
  static let vertexAI_v1beta = InstanceConfig(
    apiConfig: APIConfig(service: .vertexAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let vertexAI_v1beta_global = InstanceConfig(
    location: "global",
    apiConfig: APIConfig(service: .vertexAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let vertexAI_v1beta_global_appCheckLimitedUse = InstanceConfig(
    location: "global",
    useLimitedUseAppCheckTokens: true,
    apiConfig: APIConfig(service: .vertexAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let vertexAI_v1beta_staging = InstanceConfig(
    apiConfig: APIConfig(service: .vertexAI(endpoint: .firebaseProxyStaging), version: .v1beta)
  )
  static let googleAI_v1beta = InstanceConfig(
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let googleAI_v1beta_appCheckLimitedUse = InstanceConfig(
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let googleAI_v1beta_staging = InstanceConfig(
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyStaging), version: .v1beta)
  )
  static let googleAI_v1beta_freeTier = InstanceConfig(
    appName: FirebaseAppNames.spark,
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let googleAI_v1beta_freeTier_bypassProxy = InstanceConfig(
    appName: FirebaseAppNames.spark,
    apiConfig: APIConfig(service: .googleAI(endpoint: .googleAIBypassProxy), version: .v1beta)
  )

  static let allConfigs = [
    vertexAI_v1beta,
    vertexAI_v1beta_global,
    vertexAI_v1beta_global_appCheckLimitedUse,
    googleAI_v1beta,
    googleAI_v1beta_appCheckLimitedUse,
    googleAI_v1beta_freeTier,
    // Note: The following configs are commented out for easy one-off manual testing.
    // vertexAI_v1beta_staging,
    // googleAI_v1beta_staging,
    // googleAI_v1beta_freeTier_bypassProxy,
  ]

  static let vertexAI_v1beta_appCheckNotConfigured = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    apiConfig: APIConfig(service: .vertexAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let vertexAI_v1beta_appCheckNotConfigured_limitedUseTokens = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    useLimitedUseAppCheckTokens: true,
    apiConfig: APIConfig(service: .vertexAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let googleAI_v1beta_appCheckNotConfigured = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let googleAI_v1beta_appCheckNotConfigured_limitedUseTokens = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    useLimitedUseAppCheckTokens: true,
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )

  static let appCheckNotConfiguredConfigs = [
    vertexAI_v1beta_appCheckNotConfigured,
    vertexAI_v1beta_appCheckNotConfigured_limitedUseTokens,
    googleAI_v1beta_appCheckNotConfigured,
    googleAI_v1beta_appCheckNotConfigured_limitedUseTokens,
  ]

  let appName: String?
  let location: String?
  let useLimitedUseAppCheckTokens: Bool
  let apiConfig: APIConfig

  init(appName: String? = nil,
       location: String? = nil,
       useLimitedUseAppCheckTokens: Bool = false,
       apiConfig: APIConfig) {
    self.appName = appName
    self.location = location
    self.useLimitedUseAppCheckTokens = useLimitedUseAppCheckTokens
    self.apiConfig = apiConfig
  }

  var app: FirebaseApp? {
    return appName.map { FirebaseApp.app(name: $0) } ?? FirebaseApp.app()
  }

  var serviceName: String {
    switch apiConfig.service {
    case .vertexAI:
      return "Vertex AI"
    case .googleAI:
      return "Google AI"
    }
  }

  var versionName: String {
    return apiConfig.version.rawValue
  }
}

extension InstanceConfig: CustomTestStringConvertible {
  var testDescription: String {
    let freeTierDesignator = (appName == FirebaseAppNames.spark) ? " - Free Tier" : ""
    let endpointSuffix = switch apiConfig.service.endpoint {
    case .firebaseProxyProd:
      ""
    case .firebaseProxyStaging:
      " - Staging"
    case .googleAIBypassProxy:
      " - Bypass Proxy"
    }
    let locationSuffix = location.map { " - \($0)" } ?? ""
    let appCheckLimitedUseDesignator = useLimitedUseAppCheckTokens ? " - FAC Limited-Use" : ""

    return """
    \(serviceName) (\(versionName))\(freeTierDesignator)\(endpointSuffix)\(locationSuffix)\
    \(appCheckLimitedUseDesignator)
    """
  }
}

extension AILogic {
  static func componentInstance(_ instanceConfig: InstanceConfig) -> AILogic {
    switch instanceConfig.apiConfig.service {
    case .vertexAI:
      let location = instanceConfig.location ?? "us-central1"
      return AILogic.createInstance(
        app: instanceConfig.app,
        location: location,
        apiConfig: instanceConfig.apiConfig,
        useLimitedUseAppCheckTokens: instanceConfig.useLimitedUseAppCheckTokens
      )
    case .googleAI:
      assert(
        instanceConfig.location == nil,
        "The Developer API is global and does not support `location`."
      )
      return AILogic.createInstance(
        app: instanceConfig.app,
        location: nil,
        apiConfig: instanceConfig.apiConfig,
        useLimitedUseAppCheckTokens: instanceConfig.useLimitedUseAppCheckTokens
      )
    }
  }
}
