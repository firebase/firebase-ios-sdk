/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/FIRRemoteConfigComponent.h"
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"
@import FirebaseRemoteConfigInterop;

@interface FIRRemoteConfigComponentTest : XCTestCase
@end

@implementation FIRRemoteConfigComponentTest

- (void)tearDown {
  [super tearDown];

  // Clear out any apps that were called with `configure`.
  [FIRApp resetApps];
  [FIRRemoteConfigComponent clearAllComponentInstances];
}

- (void)testRCInstanceCreationAndCaching {
  // Create the provider to vend Remote Config instances.
  FIRRemoteConfigComponent *provider = [self providerForTest];

  // Create a Remote Config instance from the provider.
  NSString *sharedNamespace = @"some_namespace";
  FIRRemoteConfig *config = [provider remoteConfigForNamespace:sharedNamespace];
  XCTAssertNotNil(config);

  // Fetch an instance with the same namespace - should be the same instance.
  FIRRemoteConfig *sameConfig = [provider remoteConfigForNamespace:sharedNamespace];
  XCTAssertNotNil(sameConfig);
  XCTAssertEqual(config, sameConfig);
}

- (void)testRCSeparateInstancesForDifferentNamespaces {
  // Create the provider to vend Remote Config instances.
  FIRRemoteConfigComponent *provider = [self providerForTest];

  // Create a Remote Config instance from the provider.
  FIRRemoteConfig *config = [provider remoteConfigForNamespace:@"namespace1"];
  XCTAssertNotNil(config);

  // Fetch another instance with a different namespace.
  FIRRemoteConfig *config2 = [provider remoteConfigForNamespace:@"namespace2"];
  XCTAssertNotNil(config2);
  XCTAssertNotEqual(config, config2);
}

- (void)testRCSeparateInstancesForDifferentApps {
  FIRRemoteConfigComponent *provider = [self providerForTest];

  // Create a Remote Config instance from the provider.
  NSString *sharedNamespace = @"some_namespace";
  FIRRemoteConfig *config = [provider remoteConfigForNamespace:sharedNamespace];
  XCTAssertNotNil(config);

  // Use a new app and new povider, ensure the instances with the same namespace are different.
  NSString *secondAppName = [provider.app.name stringByAppendingString:@"2"];
  FIRApp *secondApp = [[FIRApp alloc] initInstanceWithName:secondAppName
                                                   options:[self fakeOptions]];
  FIRRemoteConfigComponent *separateProvider =
      [[FIRRemoteConfigComponent alloc] initWithApp:secondApp];
  FIRRemoteConfig *separateConfig = [separateProvider remoteConfigForNamespace:sharedNamespace];
  XCTAssertNotNil(separateConfig);
  XCTAssertNotEqual(config, separateConfig);
}

- (void)testInitialization {
  // Explicitly instantiate the component here in case the providerForTest ever changes to mock
  // something.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:[self fakeOptions]];
  FIRRemoteConfigComponent *provider = [[FIRRemoteConfigComponent alloc] initWithApp:app];
  XCTAssertNotNil(provider);
  XCTAssertNotNil(provider.app);
}

- (void)testRegistersAsLibrary {
  // Now component has two register, one is provider and another one is Interop
  XCTAssertEqual([FIRRemoteConfigComponent componentsToRegister].count, 2);

  // Configure a test FIRApp for fetching an instance of the FIRRemoteConfigProvider.
  NSString *appName = [self generatedTestAppName];
  [FIRApp configureWithName:appName options:[self fakeOptions]];
  FIRApp *app = [FIRApp appNamed:appName];

  // Attempt to fetch the component and verify it's a valid instance.
  id<FIRRemoteConfigProvider> provider = FIR_COMPONENT(FIRRemoteConfigProvider, app.container);
  id<FIRRemoteConfigInterop> interop = FIR_COMPONENT(FIRRemoteConfigInterop, app.container);
  XCTAssertNotNil(provider);
  XCTAssertNotNil(interop);

  // Ensure that the instance that comes from the container is cached.
  id<FIRRemoteConfigProvider> sameProvider = FIR_COMPONENT(FIRRemoteConfigProvider, app.container);
  id<FIRRemoteConfigInterop> sameInterop = FIR_COMPONENT(FIRRemoteConfigInterop, app.container);
  XCTAssertNotNil(sameProvider);
  XCTAssertNotNil(sameInterop);
  XCTAssertEqual(provider, sameProvider);
  XCTAssertEqual(interop, sameInterop);

  // Dynamic typing, both prototols are referring to the same component instance
  id providerID = provider;
  id interopID = interop;
  XCTAssertEqualObjects(providerID, interopID);
}

- (void)testTwoAppsCreateTwoComponents {
  NSString *appName = [self generatedTestAppName];
  [FIRApp configureWithName:appName options:[self fakeOptions]];
  FIRApp *app = [FIRApp appNamed:appName];

  [FIRApp configureWithOptions:[self fakeOptions]];
  FIRApp *defaultApp = [FIRApp defaultApp];
  XCTAssertNotNil(defaultApp);
  XCTAssertNotEqualObjects(app, defaultApp);

  id<FIRRemoteConfigProvider> provider = FIR_COMPONENT(FIRRemoteConfigProvider, app.container);
  id<FIRRemoteConfigInterop> interop = FIR_COMPONENT(FIRRemoteConfigInterop, app.container);
  id<FIRRemoteConfigProvider> defaultAppProvider =
      FIR_COMPONENT(FIRRemoteConfigProvider, defaultApp.container);
  id<FIRRemoteConfigInterop> defaultAppInterop =
      FIR_COMPONENT(FIRRemoteConfigInterop, defaultApp.container);

  id providerID = provider;
  id interopID = interop;
  id defaultAppProviderID = defaultAppProvider;
  id defaultAppInteropID = defaultAppInterop;

  XCTAssertEqualObjects(providerID, interopID);
  XCTAssertEqualObjects(defaultAppProviderID, defaultAppInteropID);
  // Check two apps get their own component to register
  XCTAssertNotEqualObjects(interopID, defaultAppInteropID);
}

- (void)testThrowsWithEmptyGoogleAppID {
  FIROptions *options = [self fakeOptions];
  options.googleAppID = @"";

  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *component = [[FIRRemoteConfigComponent alloc] initWithApp:app];

  // Creating a Remote Config instance should fail since the googleAppID is empty.
  XCTAssertThrows([component remoteConfigForNamespace:@"some_namespace"]);
}

- (void)testThrowsWithNilGoogleAppID {
  FIROptions *options = [self fakeOptions];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  options.googleAppID = nil;
#pragma clang diagnostic pop

  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *component = [[FIRRemoteConfigComponent alloc] initWithApp:app];

  // Creating a Remote Config instance should fail since the googleAppID is nil.
  XCTAssertThrows([component remoteConfigForNamespace:@"some_namespace"]);
}

- (void)testThrowsWithEmptyGCMSenderID {
  FIROptions *options = [self fakeOptions];
  options.GCMSenderID = @"";

  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *component = [[FIRRemoteConfigComponent alloc] initWithApp:app];

  // Creating a Remote Config instance should fail since the GCMSenderID is empty.
  XCTAssertThrows([component remoteConfigForNamespace:@"some_namespace"]);
}

- (void)testThrowsWithNilGCMSenderID {
  FIROptions *options = [self fakeOptions];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  options.GCMSenderID = nil;
#pragma clang diagnostic pop

  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *component = [[FIRRemoteConfigComponent alloc] initWithApp:app];

  // Creating a Remote Config instance should fail since the GCMSenderID is nil.
  XCTAssertThrows([component remoteConfigForNamespace:@"some_namespace"]);
}

- (void)testThrowsWithEmptyProjectID {
  FIROptions *options = [self fakeOptions];
  options.projectID = @"";

  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *component = [[FIRRemoteConfigComponent alloc] initWithApp:app];

  // Creating a Remote Config instance should fail since the projectID is empty.
  XCTAssertThrows([component remoteConfigForNamespace:@"some_namespace"]);
}

- (void)testThrowsWithNilProjectID {
  FIROptions *options = [self fakeOptions];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  options.projectID = nil;
#pragma clang diagnostic pop

  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *component = [[FIRRemoteConfigComponent alloc] initWithApp:app];

  // Creating a Remote Config instance should fail since the projectID is empty.
  XCTAssertThrows([component remoteConfigForNamespace:@"some_namespace"]);
}

#pragma mark - Helpers

- (FIROptions *)fakeOptions {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"correct_gcm_sender_id"];
  options.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
  options.projectID = @"project-id";
  return options;
}

- (NSString *)generatedTestAppName {
  return [RCNTestUtilities generatedTestAppNameForTest:self.name];
}

- (FIRRemoteConfigComponent *)providerForTest {
  // Create the provider to vend Remote Config instances.
  NSString *appName = [self generatedTestAppName];
  FIROptions *options = [[self fakeOptions] copy];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:appName options:options];
  FIRRemoteConfigComponent *provider = [[FIRRemoteConfigComponent alloc] initWithApp:app];
  XCTAssertNotNil(provider);
  XCTAssert(provider.app.options.googleAppID.length != 0);
  XCTAssert(provider.app.options.GCMSenderID.length != 0);
  return provider;
}

@end
