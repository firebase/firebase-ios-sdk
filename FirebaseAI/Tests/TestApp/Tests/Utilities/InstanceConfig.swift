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

@testable import enum FirebaseAILogic.APIConfig
@testable import struct FirebaseAILogic.CloudConfig

struct InstanceConfig: Equatable, Encodable {
  static let vertexAI_v1beta = InstanceConfig(
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    ))
  )
  static let vertexAI_v1beta_appCheckLimitedUse = InstanceConfig(
    useLimitedUseAppCheckTokens: true,
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    ))
  )
  static let vertexAI_v1beta_global = InstanceConfig(
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "global"),
      version: .v1beta
    ))
  )
  static let vertexAI_v1beta_global_appCheckLimitedUse = InstanceConfig(
    useLimitedUseAppCheckTokens: true,
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "global"),
      version: .v1beta
    ))
  )
  static let vertexAI_v1beta_staging = InstanceConfig(
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyStaging, location: "us-central1"),
      version: .v1beta
    ))
  )
  static let vertexAI_v1beta_staging_global_bypassProxy = InstanceConfig(
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .vertexAIStagingBypassProxy, location: "global"),
      version: .v1beta1
    ))
  )
  static let googleAI_v1beta = InstanceConfig(
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    ))
  )
  static let googleAI_v1beta_appCheckLimitedUse = InstanceConfig(
    useLimitedUseAppCheckTokens: true,
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    ))
  )
  static let googleAI_v1beta_staging = InstanceConfig(
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .firebaseProxyStaging),
      version: .v1beta
    ))
  )
  static let googleAI_v1beta_freeTier = InstanceConfig(
    appName: FirebaseAppNames.spark,
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    ))
  )
  static let googleAI_v1beta_freeTier_bypassProxy = InstanceConfig(
    appName: FirebaseAppNames.spark,
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .googleAIBypassProxy),
      version: .v1beta
    ))
  )

  static let foundationModels = InstanceConfig(
    apiConfig: .onDevice
  )

  static let allConfigs = [
    vertexAI_v1beta,
    vertexAI_v1beta_global,
    vertexAI_v1beta_global_appCheckLimitedUse,
    googleAI_v1beta,
    googleAI_v1beta_appCheckLimitedUse,
    // Note: The following configs are commented out for easy one-off manual testing.
    // googleAI_v1beta_freeTier,
    // vertexAI_v1beta_staging,
    // vertexAI_v1beta_staging_global_bypassProxy,
    // googleAI_v1beta_staging,
    // googleAI_v1beta_freeTier_bypassProxy,
  ]

  static let liveConfigs = [
    vertexAI_v1beta,
    vertexAI_v1beta_appCheckLimitedUse,
    googleAI_v1beta,
    googleAI_v1beta_appCheckLimitedUse,
    googleAI_v1beta_freeTier,
  ]

  static let vertexAI_v1beta_appCheckNotConfigured = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    ))
  )
  static let vertexAI_v1beta_appCheckNotConfigured_limitedUseTokens = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    useLimitedUseAppCheckTokens: true,
    apiConfig: .cloud(CloudConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    ))
  )
  static let googleAI_v1beta_appCheckNotConfigured = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    ))
  )
  static let googleAI_v1beta_appCheckNotConfigured_limitedUseTokens = InstanceConfig(
    appName: FirebaseAppNames.appCheckNotConfigured,
    useLimitedUseAppCheckTokens: true,
    apiConfig: .cloud(CloudConfig(
      service: .googleAI(endpoint: .firebaseProxyProd),
      version: .v1beta
    ))
  )

  static let appCheckNotConfiguredConfigs = [
    vertexAI_v1beta_appCheckNotConfigured,
    vertexAI_v1beta_appCheckNotConfigured_limitedUseTokens,
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
    switch apiConfig {
    case let .cloud(config):
      switch config.service {
      case .vertexAI:
        return "Vertex AI"
      case .googleAI:
        return "Google AI"
      }
    case .onDevice:
      return "Foundation Models"
    }
  }

  var versionName: String {
    switch apiConfig {
    case let .cloud(config):
      return config.version.rawValue
    case .onDevice:
      return "unversioned"
    }
  }
}

extension InstanceConfig: CustomTestStringConvertible {
  var testDescription: String {
    let freeTierDesignator = (appName == FirebaseAppNames.spark) ? " - Free Tier" : ""

    let endpointSuffix: String
    let locationSuffix: String

    switch apiConfig {
    case let .cloud(config):
      endpointSuffix = switch config.service.endpoint {
      case .firebaseProxyProd:
        ""
      case .firebaseProxyStaging:
        " - Staging"
      case .googleAIBypassProxy:
        " - Bypass Proxy"
      case .vertexAIStagingBypassProxy:
        " - Staging - Bypass Proxy"
      }

      if case let .vertexAI(_, location: location) = config.service {
        locationSuffix = " - (\(location))"
      } else {
        locationSuffix = ""
      }

    case .onDevice:
      endpointSuffix = " - Local"
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
    switch instanceConfig.apiConfig {
    case let .cloud(config):
      switch config.service {
      case .vertexAI:
        // Assumption: FirebaseAI.createInstance still takes 'APIConfig' which is now the enum.
        // But wait, createInstance likely assumed the old struct.
        // If I changed APIConfig to enum, createInstance signature might be fine if it takes
        // APIConfig.
        // But internally it probably accesses .service.
        // I need to update FirebaseAI.swift as well.
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
    case .onDevice:
      return FirebaseAI.createInstance(
        app: instanceConfig.app,
        apiConfig: instanceConfig.apiConfig,
        useLimitedUseAppCheckTokens: instanceConfig.useLimitedUseAppCheckTokens
      )
    }
  }
}
