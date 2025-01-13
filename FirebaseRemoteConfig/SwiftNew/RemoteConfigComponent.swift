// Copyright 2024 Google LLC
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

import FirebaseCore
import FirebaseCoreExtension
import FirebaseRemoteConfigInterop

// TODO(ncooke3): Once Obj-C tests are ported, all `public` access modifers can be removed.

// TODO(ncooke3): Move to another pod.
@objc(AnalyticsInterop) public protocol FIRAnalyticsInterop {
  func getUserProperties(callback: @escaping ([String: Any]) -> Void)
  func logEvent(withOrigin origin: String,
                name: String,
                parameters: [String: Any])
}

/// Provides and creates instances of Remote Config based on the namespace provided. Used in the
/// interop registration process to keep track of RC instances for each `FIRApp` instance.
@objc(FIRRemoteConfigProvider) public protocol RemoteConfigProvider {
  /// Cached instances of Remote Config objects.
  var instances: [String: RemoteConfig] { get set }

  /// Default method for retrieving a Remote Config instance, or creating one if it doesn't exist.
  func remoteConfig(forNamespace remoteConfigNamespace: String) -> RemoteConfig?
}

/// A concrete implementation for FIRRemoteConfigInterop to create Remote Config instances and
/// register with Core's component system.
@objc(FIRRemoteConfigComponent) public final class RemoteConfigComponent: NSObject {
  // Because Component now need to register two protocols (provider and interop), we need a way to
  // return the same component instance for both registered protocol, this singleton pattern allow
  // us
  // to return the same component object for both registration callback.
  static var componentInstances: [String: RemoteConfigComponent] = [:]
  static let componentInstancesLock = NSLock()

  /// The FIRApp that instances will be set up with.
  @objc public weak var app: FirebaseApp?

  /// Cached instances of Remote Config objects.
  public var instances: [String: RemoteConfig]
  let instancesLock = NSLock()

  /// Default initializer.
  @objc public init(app: FirebaseApp) {
    self.app = app
    instances = [:]
    super.init()
  }
}

extension RemoteConfigComponent: RemoteConfigProvider {
  /// Default method for retrieving a Remote Config instance, or creating one if it doesn't exist.
  @objc public func remoteConfig(forNamespace remoteConfigNamespace: String) -> RemoteConfig? {
    guard let app else {
      return nil
    }

    // Validate the required information is available.
    let errorPropertyName = if app.options.googleAppID.isEmpty {
      "googleAppID"
    } else if app.options.gcmSenderID.isEmpty {
      "GCMSenderID"
    } else if (app.options.projectID ?? "").isEmpty {
      "projectID"
    } else { nil as String? }

    if let errorPropertyName {
      // TODO(ncooke): The ObjC unit tests depend on this throwing an exception
      // (which can be caught in ObjC but not as easily in Swift). Once unit
      // tests are ported, move to fatalError and document behavior change in
      // release notes.
//      fatalError("Firebase Remote Config is missing the required \(errorPropertyName) property
//      from the " +
//                 "configured FirebaseApp and will not be able to function properly. " +
//                 "Please fix this issue to ensure that Firebase is correctly configured.")
      NSException.raise(
        NSExceptionName("com.firebase.config"),
        format: "Firebase Remote Config is missing the required %@ property from the " +
          "configured FirebaseApp and will not be able to function properly. " +
          "Please fix this issue to ensure that Firebase is correctly configured.",
        arguments: getVaList([errorPropertyName])
      )
    }

    instancesLock.lock()
    defer { instancesLock.unlock() }
    guard let cachedInstance = instances[remoteConfigNamespace] else {
      let analytics = app.isDefaultApp ? app.container.instance(for: FIRAnalyticsInterop.self) : nil
      let newInstance = RemoteConfig(
        appName: app.name,
        options: app.options,
        namespace: remoteConfigNamespace,
        dbManager: ConfigDBManager.sharedInstance,
        configContent: ConfigContent.sharedInstance,
        analytics: analytics as? FIRAnalyticsInterop
      )
      instances[remoteConfigNamespace] = newInstance
      return newInstance
    }

    return cachedInstance
  }
}

extension RemoteConfigComponent: Library {
  public static func componentsToRegister() -> [Component] {
    let rcProvider = Component(
      RemoteConfigProvider.self,
      instantiationTiming: .alwaysEager
    ) { container, isCacheable in
      // Cache the component so instances of Remote Config are cached.
      isCacheable.pointee = true
      return getComponent(forApp: container.app)
    }
    // Unlike provider needs to setup a hard dependency on remote config, interop allows an optional
    // dependency on RC
    let rcInterop = Component(
      RemoteConfigInterop.self,
      instantiationTiming: .alwaysEager
    ) { container, isCacheable in
      // Cache the component so instances of Remote Config are cached.
      isCacheable.pointee = true
      return getComponent(forApp: container.app)
    }
    return [rcProvider, rcInterop]
  }

  private static func getComponent(forApp app: FirebaseApp?) -> RemoteConfigComponent? {
    componentInstancesLock.withLock {
      guard let app else {
        return nil
      }

      if componentInstances[app.name] == nil {
        componentInstances[app.name] = .init(app: app)
      }

      return componentInstances[app.name]
    }
  }

  /// Clear all the component instances from the singleton which created previously, this is for
  /// testing only
  @objc public static func clearAllComponentInstances() {
    componentInstancesLock.withLock {
      componentInstances.removeAll()
    }
  }
}

extension RemoteConfigComponent: RemoteConfigInterop {
  public func registerRolloutsStateSubscriber(_ subscriber: any FirebaseRemoteConfigInterop
    .RolloutsStateSubscriber,
    for namespace: String) {
    if let instance = remoteConfig(forNamespace: namespace) {
      instance.addRemoteConfigInteropSubscriber(subscriber)
    }
  }
}
