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

import XCTest

import FirebaseCore
import FirebaseRemoteConfig
import FirebaseRemoteConfigInterop

final class FirebaseRemoteConfig_APIBuildTests: XCTestCase {
  func usage() throws {
    // MARK: - FirebaseRemoteConfig

    // TODO(ncooke3): These global constants should be lowercase.
    let _: String = FirebaseRemoteConfig.NamespaceGoogleMobilePlatform
    let _: String = FirebaseRemoteConfig.RemoteConfigThrottledEndTimeInSecondsKey

    // TODO(ncooke3): This should probably not be initializable.
    FirebaseRemoteConfig.ConfigUpdateListenerRegistration().remove()

    let fetchStatus: FirebaseRemoteConfig.RemoteConfigFetchStatus? = nil
    switch fetchStatus! {
    case .noFetchYet: break
    case .success: break
    case .failure: break
    case .throttled: break
    @unknown default: break
    }

    let fetchAndActivateStatus: FirebaseRemoteConfig.RemoteConfigFetchAndActivateStatus? = nil
    switch fetchAndActivateStatus! {
    case .successFetchedFromRemote: break
    case .successUsingPreFetchedData: break
    case .error: break
    @unknown default: break
    }

    // Used to pass into the initializers for the custom errors below.
    let nsError = NSError(domain: "", code: 0, userInfo: nil)

    // TODO(ncooke3): Global constants should be lowercase.
    let _: String = FirebaseRemoteConfig.RemoteConfigErrorDomain
    let _ = FirebaseRemoteConfig.RemoteConfigError(_nsError: nsError)
    let _: FirebaseRemoteConfig.RemoteConfigError.Code._ErrorType = FirebaseRemoteConfig
      .RemoteConfigError(_nsError: nsError)
    let _: String = FirebaseRemoteConfig.RemoteConfigError.errorDomain
    let code: FirebaseRemoteConfig.RemoteConfigError.Code? = nil
    switch code! {
    case .unknown: break
    case .throttled: break
    case .internalError: break
    @unknown default: break
    }
    _ = FirebaseRemoteConfig.RemoteConfigError.unknown
    _ = FirebaseRemoteConfig.RemoteConfigError.throttled
    _ = FirebaseRemoteConfig.RemoteConfigError.internalError

    // TODO(ncooke3): Global constants should be lowercase.
    let _: String = FirebaseRemoteConfig.RemoteConfigUpdateErrorDomain
    let _ = FirebaseRemoteConfig.RemoteConfigUpdateError(_nsError: nsError)
    let _: FirebaseRemoteConfig.RemoteConfigUpdateError.Code._ErrorType = FirebaseRemoteConfig
      .RemoteConfigUpdateError(_nsError: nsError)
    let _: String = FirebaseRemoteConfig.RemoteConfigUpdateError.errorDomain
    let updateErrorCode: FirebaseRemoteConfig.RemoteConfigUpdateError.Code? = nil
    switch updateErrorCode! {
    case .streamError: break
    case .notFetched: break
    case .messageInvalid: break
    case .unavailable: break
    @unknown default: break
    }
    _ = FirebaseRemoteConfig.RemoteConfigUpdateError.streamError
    _ = FirebaseRemoteConfig.RemoteConfigUpdateError.notFetched
    _ = FirebaseRemoteConfig.RemoteConfigUpdateError.messageInvalid
    _ = FirebaseRemoteConfig.RemoteConfigUpdateError.unavailable

    // TODO(ncooke3): This should probably not be initializable.
    let value = FirebaseRemoteConfig.RemoteConfigValue()
    let _: String? = value.stringValue
    // TODO(ncooke3): Returns an Objective-C reference type.
    let _: NSNumber = value.numberValue
    let _: Data = value.dataValue
    let _: Bool = value.boolValue
    let _: Any? = value.jsonValue

    let source: FirebaseRemoteConfig.RemoteConfigSource = value.source
    switch source {
    case .remote: break
    case .default: break
    case .static: break
    @unknown default: break
    }

    let settings = FirebaseRemoteConfig.RemoteConfigSettings()
    settings.minimumFetchInterval = TimeInterval(100)
    settings.fetchTimeout = TimeInterval(100)

    // TODO(ncooke3): This should probably not be initializable.
    let update = FirebaseRemoteConfig.RemoteConfigUpdate()
    let _: Set<String> = update.updatedKeys

    let _ = FirebaseRemoteConfig.RemoteConfig.remoteConfig()
    let config = FirebaseRemoteConfig.RemoteConfig
      .remoteConfig(app: FirebaseCore.FirebaseApp.app()!)
    let _: Date? = config.lastFetchTime
    let _: FirebaseRemoteConfig.RemoteConfigFetchStatus = config.lastFetchStatus
    let _: FirebaseRemoteConfig.RemoteConfigSettings = config.configSettings

    config.ensureInitialized(completionHandler: { (error: Error?) in })

    config.fetch(completionHandler: { (status: FirebaseRemoteConfig.RemoteConfigFetchStatus,
                                       error: Error?) in })

    config.fetch()

    config.fetch(
      withExpirationDuration: TimeInterval(100),
      completionHandler: { (status: FirebaseRemoteConfig.RemoteConfigFetchStatus, error: Error?) in
      }
    )

    config.fetch(withExpirationDuration: TimeInterval(100))

    config
      .fetchAndActivate(
        completionHandler: { (status: FirebaseRemoteConfig.RemoteConfigFetchAndActivateStatus,
                              error: Error?) in }
      )

    config.fetchAndActivate()

    config.activate(completion: { (success: Bool, error: Error?) in })

    config.activate()

    if #available(iOS 13.0, *) {
      Task {
        let _: Void = try await config.ensureInitialized()
        let _: FirebaseRemoteConfig.RemoteConfigFetchStatus = try await config.fetch()
        let _: FirebaseRemoteConfig.RemoteConfigFetchStatus = try await config
          .fetch(withExpirationDuration: TimeInterval(100))
        let _: FirebaseRemoteConfig.RemoteConfigFetchAndActivateStatus = try await config
          .fetchAndActivate()
        let _: Bool = try await config.activate()
      }
    }

    let _: FirebaseRemoteConfig.RemoteConfigValue = config["key"]
    let _: FirebaseRemoteConfig.RemoteConfigValue = config.configValue(forKey: "key")
    // TODO(ncooke3): Should `nil` be acceptable here in a Swift context?
    let _: FirebaseRemoteConfig.RemoteConfigValue = config.configValue(forKey: nil)
    let _: FirebaseRemoteConfig.RemoteConfigValue = config.configValue(
      forKey: "key",
      source: source
    )
    // TODO(ncooke3): Should `nil` be acceptable here in a Swift context?
    let _: FirebaseRemoteConfig.RemoteConfigValue = config.configValue(forKey: nil, source: source)

    let _: [String] = config.allKeys(from: source)

    let _: Set<String> = config.keys(withPrefix: "")
    // TODO(ncooke3): Should `nil` be acceptable here in a Swift context?
    let _: Set<String> = config.keys(withPrefix: nil)

    let defaults: [String: NSObject]? = [:]
    config.setDefaults(defaults)
    // TODO(ncooke3): Should `nil` be acceptable here in a Swift context?
    config.setDefaults(nil)

    config.setDefaults(fromPlist: "")
    // TODO(ncooke3): Should `nil` be acceptable here in a Swift context?
    config.setDefaults(fromPlist: nil)

    let _: FirebaseRemoteConfig.RemoteConfigValue? = config.defaultValue(forKey: "")
    // TODO(ncooke3): Should `nil` be acceptable here in a Swift context?
    let _: FirebaseRemoteConfig.RemoteConfigValue? = config.defaultValue(forKey: nil)

    let _: FirebaseRemoteConfig.ConfigUpdateListenerRegistration = config
      .addOnConfigUpdateListener(
        remoteConfigUpdateCompletion: { (update: FirebaseRemoteConfig.RemoteConfigUpdate?,
                                         error: Error?) in
        }
      )

    let valueError: FirebaseRemoteConfig
      .RemoteConfigValueCodableError = .unsupportedType("foo")
    switch valueError {
    case .unsupportedType: break
    }

    let error: FirebaseRemoteConfig.RemoteConfigCodableError = .invalidSetDefaultsInput("foo")
    switch error {
    case .invalidSetDefaultsInput: break
    }

    @available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
    struct PropertyWrapperTester {
      @FirebaseRemoteConfig.RemoteConfigProperty(key: "", fallback: "")
      var stringValue: String!
    }

    struct MyDecodableValue: Decodable {}
    let _: MyDecodableValue? = config[decodedValue: ""]

    let _: [String: AnyHashable]? = config[jsonValue: ""]

    let _: MyDecodableValue = try value.decoded()
    let _: MyDecodableValue = try value.decoded(asType: MyDecodableValue.self)

    let _: MyDecodableValue? = try config.decoded()
    let _: MyDecodableValue? = try config.decoded(asType: MyDecodableValue.self)

    struct MyEncodableValue: Encodable {}
    let _: Void = try config.setDefaults(from: MyEncodableValue())
  }
}
