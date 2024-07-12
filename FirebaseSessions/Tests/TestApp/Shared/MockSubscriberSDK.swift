//
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

import FirebaseSessions
import Foundation

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@objc(FIRMockSubscriberSDKProtocol)
protocol MockSubscriberSDKProtocol {
  func emptyProtocol()
}

///
/// The MockSubscriberSDK pretends to be Firebase Performance because without
/// any Integrated Product SDKs installed, the Sessions SDK will not send events. This
/// is because data collection is handled only in product SDKs.
///
@objc(FIRMockSubscriberSDK) final class MockSubscriberSDK: NSObject, Library, SessionsSubscriber,
  MockSubscriberSDKProtocol {
  static func addDependency() {
    FirebaseApp.registerInternalLibrary(
      MockSubscriberSDK.self,
      withName: "mock-firebase-sessions-subscriber-sdk"
    )
    SessionsDependencies.addDependency(name: SessionsSubscriberName.Performance)
  }

  init(app: FirebaseApp) {
    super.init()

    let sessions = ComponentType<SessionsProvider>.instance(for: SessionsProvider.self,
                                                            in: app.container)
    sessions?.register(subscriber: self)
  }

  // MARK: - Library Conformance

  static func componentsToRegister() -> [Component] {
    return [Component(MockSubscriberSDKProtocol.self,
                      instantiationTiming: .alwaysEager) { container, isCacheable in
        // Sessions SDK only works for the default app
        guard let app = container.app, app.isDefaultApp else { return nil }
        isCacheable.pointee = true
        return self.init(app: app)
      }]
  }

  // MARK: - SessionsSubscriber Conformance

  func onSessionChanged(_ session: FirebaseSessions.SessionDetails) {}

  var isDataCollectionEnabled: Bool {
    return true
  }

  var sessionsSubscriberName: FirebaseSessions.SessionsSubscriberName {
    return FirebaseSessions.SessionsSubscriberName.Performance
  }

  // MARK: - MockSubscriberSDKProtocol Conformance

  func emptyProtocol() {}
}
