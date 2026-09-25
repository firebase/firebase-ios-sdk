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
  static let enterprise_v1beta = InstanceConfig(
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    )
  )
  static let enterprise_v1beta_appCheckLimitedUse = InstanceConfig(
    useLimitedUseAppCheckTokens: true,
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    )
  )
  static let enterprise_v1beta_global = InstanceConfig(
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyProd, location: "global"),
      version: .v1beta
    )
  )
  static let enterprise_v1beta_global_appCheckLimitedUse = InstanceConfig(
    useLimitedUseAppCheckTokens: true,
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyProd, location: "global"),
      version: .v1beta
    )
  )
  static let enterprise_v1beta_staging = InstanceConfig(
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyStaging, location: "us-central1"),
      version: .v1beta
    )
  )
  static let enterprise_v1beta_staging_global_bypassProxy = InstanceConfig(
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .enterpriseStagingBypassProxy, location: "global"),
      version: .v1beta1
    )
  )
  static let googleAI_v1beta = InstanceConfig(
    apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
  )
  static let googleAI_v1beta_appCheckLimitedUse = InstanceConfig(
    useLimitedUseAppCheckTokens: true,
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

  static let defaultConfigs = [
    enterprise_v1beta_global,
    googleAI_v1beta,
    // Note: The following configs are commented out for easy one-off manual testing.
    // enterprise_v1beta,
    // enterprise_v1beta_global_appCheckLimitedUse,
    // enterprise_v1beta_staging,
    // enterprise_v1beta_staging_global_bypassProxy,
    // googleAI_v1beta_appCheckLimitedUse,
    // googleAI_v1beta_staging,
    // googleAI_v1beta_freeTier,
    // googleAI_v1beta_freeTier_bypassProxy,
  ]

  static let liveConfigs = [
    enterprise_v1beta,
    googleAI_v1beta,
    // Note: The following configs are commented out for easy one-off manual testing.
    // enterprise_v1beta_appCheckLimitedUse,
    // googleAI_v1beta_appCheckLimitedUse,
    // googleAI_v1beta_freeTier,
  ]

  static let enterprise_v1beta_appCheckNotConfigured = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    )
  )
  static let enterprise_v1beta_appCheckNotConfigured_limitedUseTokens = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    useLimitedUseAppCheckTokens: true,
    apiConfig: APIConfig(
      service: .enterprise(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    )
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
    enterprise_v1beta_appCheckNotConfigured,
    enterprise_v1beta_appCheckNotConfigured_limitedUseTokens,
    googleAI_v1beta_appCheckNotConfigured,
    googleAI_v1beta_appCheckNotConfigured_limitedUseTokens,
  ]

  let appName: String?
  let useLimitedUseAppCheckTokens: Bool
  let apiConfig: APIConfig

  init(appName: String? = nil, useLimitedUseAppCheckTokens: Bool = false, apiConfig: APIConfig) {
    self.appName = appName
    self.useLimitedUseAppCheckTokens = useLimitedUseAppCheckTokens
    self.apiConfig = apiConfig
  }

  var app: FirebaseApp? {
    return appName.map { FirebaseApp.app(name: $0) } ?? FirebaseApp.app()
  }

  var serviceName: String {
    switch apiConfig.service {
    case .enterprise:
      return "Enterprise"
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
    case .enterpriseStagingBypassProxy:
      " - Staging - Bypass Proxy"
    }
    let locationSuffix: String
    if case let .enterprise(_, location: location) = apiConfig.service {
      locationSuffix = " - (\(location))"
    } else {
      locationSuffix = ""
    }
    let appCheckLimitedUseDesignator = useLimitedUseAppCheckTokens ? " - FAC Limited-Use" : ""

    return """
    \(serviceName) (\(versionName))\(freeTierDesignator)\(endpointSuffix)\(locationSuffix)\
    \(appCheckLimitedUseDesignator)
    """
  }
}

extension FirebaseAI {
  static func componentInstance(_ instanceConfig: InstanceConfig) -> FirebaseAI {
    switch instanceConfig.apiConfig.service {
    case .enterprise:
      return FirebaseAI.createInstance(
        app: instanceConfig.app,
        apiConfig: instanceConfig.apiConfig,
        useLimitedUseAppCheckTokens: instanceConfig.useLimitedUseAppCheckTokens
      )
    case .googleAI:
      return FirebaseAI.createInstance(
        app: instanceConfig.app,
        apiConfig: instanceConfig.apiConfig,
        useLimitedUseAppCheckTokens: instanceConfig.useLimitedUseAppCheckTokens
      )
    }
  }
}
