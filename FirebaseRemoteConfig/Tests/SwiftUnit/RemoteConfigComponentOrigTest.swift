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

@testable import FirebaseRemoteConfig
import FirebaseRemoteConfigInterop
import XCTest

import FirebaseCore
import FirebaseCoreExtension

class RemoteConfigComponentTests: XCTestCase {
  var app: FirebaseApp?

  override func tearDown() {
    // Clear out any apps that were called with `configure`.
    FirebaseApp.resetApps()
    RemoteConfigComponent.clearAllComponentInstances()
    super.tearDown()
  }

  func testRemoteConfigInstanceCreationAndCaching() {
    // Create the provider to vend Remote Config instances.
    let provider = providerForTest()

    // Create a Remote Config instance from the provider.
    let sharedNamespace = "some_namespace"
    let config = provider.remoteConfig(forNamespace: sharedNamespace)
    XCTAssertNotNil(config)

    // Fetch an instance with the same namespace - should be the same instance.
    let sameConfig = provider.remoteConfig(forNamespace: sharedNamespace)
    XCTAssertNotNil(sameConfig)
    XCTAssertEqual(config, sameConfig)
  }

  func testSeparateInstancesForDifferentNamespaces() {
    // Create the provider to vend Remote Config instances.
    let provider = providerForTest()

    // Create a Remote Config instance from the provider.
    let config = provider.remoteConfig(forNamespace: "namespace1")
    XCTAssertNotNil(config)

    // Fetch another instance with a different namespace.
    let config2 = provider.remoteConfig(forNamespace: "namespace2")
    XCTAssertNotNil(config2)
    XCTAssertNotEqual(config, config2)
  }

  func testSeparateInstancesForDifferentApps() throws {
    let provider = providerForTest()

    // Create a Remote Config instance from the provider.
    let sharedNamespace = "some_namespace"
    let config = provider.remoteConfig(forNamespace: sharedNamespace)
    XCTAssertNotNil(config)

    // Use a new app and new povider, ensure the instances with the same
    // namespace are different.
    let secondAppName = try XCTUnwrap(provider.app?.name.appending("2"))
    let secondApp = FirebaseApp(instanceWithName: secondAppName, options: fakeOptions())

    let separateProvider = RemoteConfigComponent(app: secondApp)
    let separateConfig = separateProvider.remoteConfig(forNamespace: sharedNamespace)
    XCTAssertNotNil(separateConfig)
    XCTAssertNotEqual(config, separateConfig)
  }

  func testInitialization() {
    // Explicitly instantiate the component here in case the `providerForTest`
    // ever changes to mock something.
    let appName = generatedTestAppName()
    let app = FirebaseApp(instanceWithName: appName, options: fakeOptions())
    let provider = RemoteConfigComponent(app: app)
    XCTAssertNotNil(provider)
    XCTAssertNotNil(provider.app)
  }

  func testRegistersAsLibrary() throws {
    // Now component has two register, one is provider and another one is Interop
    XCTAssertEqual(RemoteConfigComponent.componentsToRegister().count, 2)

    // Configure a test app to fetch instances of provider and interop
    let appName = generatedTestAppName()
    FirebaseApp.configure(name: appName, options: fakeOptions())
    let app = try XCTUnwrap(FirebaseApp.app(name: appName))

    // Attempt to fetch the component and verify it's a valid instance.
    let provider = app.container.instance(for: RemoteConfigProvider.self) as AnyObject
    let interop = app.container.instance(for: RemoteConfigInterop.self) as AnyObject
    XCTAssertNotNil(provider)
    XCTAssertNotNil(interop)

    // Ensure that the instance that comes from the container is cached.
    let sameProvider = app.container.instance(for: RemoteConfigProvider.self) as AnyObject
    let sameInterop = app.container.instance(for: RemoteConfigInterop.self) as AnyObject
    XCTAssertNotNil(sameProvider)
    XCTAssertNotNil(sameInterop)
    XCTAssertTrue(provider === sameProvider)
    XCTAssertTrue(interop === sameInterop)

    XCTAssertTrue(provider === interop)
  }

  func testTwoAppsCreateTwoComponents() throws {
    let appName = generatedTestAppName()
    FirebaseApp.configure(name: appName, options: fakeOptions())
    let app = try XCTUnwrap(FirebaseApp.app(name: appName))

    FirebaseApp.configure(options: fakeOptions())
    let defaultApp = try XCTUnwrap(FirebaseApp.app())
    XCTAssertNotEqual(app, defaultApp)

    let provider = app.container.instance(for: RemoteConfigProvider.self) as AnyObject
    let interop = app.container.instance(for: RemoteConfigInterop.self) as AnyObject
    let defaultProvider = defaultApp.container.instance(for: RemoteConfigProvider.self) as AnyObject
    let defaultAppInterop = defaultApp.container
      .instance(for: RemoteConfigInterop.self) as AnyObject

    XCTAssertTrue(provider === interop)
    XCTAssertTrue(defaultProvider === defaultAppInterop)
    // Check two apps get their own component to register
    XCTAssertFalse(interop === defaultAppInterop)
  }

  // TODO: Consider either using the shared exception catcher or removing
  // exception from implementation (preferred).
  func testThrowsWithEmptyGoogleAppID() {
    let options = fakeOptions()
    options.googleAppID = ""

    // Create the provider to vend Remote Config instances.
    let appName = generatedTestAppName()
    let app = FirebaseApp(instanceWithName: appName, options: options)
    /* component */ _ = RemoteConfigComponent(app: app)

    // Creating a Remote Config instance should fail since the projectID is empty.
//      XCTAssertThrowsError(component.remoteConfig(forNamespace: "some_namespace"))
  }

  // TODO: Consider either using the shared exception catcher or removing
  // exception from implementation (preferred).
  func testThrowsWithNilGCMSenderID() {
    let options = fakeOptions()
    options.gcmSenderID = ""

    // Create the provider to vend Remote Config instances.
    let appName = generatedTestAppName()
    let app = FirebaseApp(instanceWithName: appName, options: options)
    /* component */ _ = RemoteConfigComponent(app: app)

    // Creating a Remote Config instance should fail since the projectID is empty.
//    XCTAssertThrowsError(component.remoteConfig(forNamespace: "some_namespace"))
  }

  // TODO: Consider either using the shared exception catcher or removing
  // exception from implementation (preferred).
  func testThrowsWithEmptyProjectID() {
    let options = fakeOptions()
    options.projectID = ""

    // Create the provider to vend Remote Config instances.
    let appName = generatedTestAppName()
    let app = FirebaseApp(instanceWithName: appName, options: options)
    /* component */ _ = RemoteConfigComponent(app: app)

    // Creating a Remote Config instance should fail since the projectID is empty.
//    XCTAssertThrowsError(component.remoteConfig(forNamespace: "some_namespace"))
  }

  // TODO: Consider either using the shared exception catcher or removing
  // exception from implementation (preferred).
  func testThrowsWithNilProjectID() {
    let options = fakeOptions()
    options.projectID = nil

    // Create the provider to vend Remote Config instances.
    let appName = generatedTestAppName()
    let app = FirebaseApp(instanceWithName: appName, options: options)
    /* component */ _ = RemoteConfigComponent(app: app)

    // Creating a Remote Config instance should fail since the projectID is empty.
//    XCTAssertThrowsError(component.remoteConfig(forNamespace: "some_namespace"))
  }

  // MARK: - Helpers

  // Helper function to create fake options
  func fakeOptions() -> FirebaseOptions {
    let options = FirebaseOptions(googleAppID: "1:123:ios:123abc",
                                  gcmSenderID: "correct_gcm_sender_id")
    options.apiKey = "AIzaSy-ApiKeyWithValidFormat_0123456789"
    options.projectID = "project-id"
    return options
  }

  private func generatedTestAppName() -> String {
    TestUtilities.generatedTestAppName(for: name)
  }

  private func providerForTest() -> RemoteConfigComponent {
    // Create the provider to vend Remote Config instances.
    let appName = generatedTestAppName()
    let options = fakeOptions().copy() as! FirebaseOptions
    // The app is weakly retained by `RemoteConfigComponent` so strongly
    // retain it by the class instance to keep it from deinitializing.
    app = FirebaseApp(instanceWithName: appName, options: options)
    let provider = RemoteConfigComponent(app: app!)
    XCTAssertNotNil(provider)
    XCTAssertFalse(provider.app?.options.googleAppID.isEmpty ?? true)
    XCTAssertFalse(provider.app?.options.gcmSenderID.isEmpty ?? true)
    return provider
  }
}
