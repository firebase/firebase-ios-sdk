// Copyright 2026 Google LLC
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

#import <XCTest/XCTest.h>

#import "FirebaseAppCheck/Sources/DefaultProviderFactory/FIRDefaultProviderFactory.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckAvailability.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRDefaultProviderFactoryTests : XCTestCase
@end

@implementation FIRDefaultProviderFactoryTests

- (FIRApp *)mockApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];
  app.dataCollectionDefaultEnabled = NO;
  return app;
}

- (void)testCreateProvider_Simulator {
#if TARGET_OS_SIMULATOR
  FIRApp *app = [self mockApp];
  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];

  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssert([provider isKindOfClass:[FIRAppCheckDebugProvider class]]);
#endif
}

- (void)testCreateProvider_Device {
#if !TARGET_OS_SIMULATOR
  FIRApp *app = [self mockApp];

  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];
  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssert([provider isKindOfClass:[FIRDeviceCheckProvider class]]);
#endif
}

- (void)testCreateProviderWithApp_PublicAPI {
  // Verifies that the public API doesn't crash and returns a provider.
  FIRApp *app = [self mockApp];

  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];
  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
#if TARGET_OS_SIMULATOR
  XCTAssert([provider isKindOfClass:[FIRAppCheckDebugProvider class]]);
#else
  XCTAssert([provider isKindOfClass:[FIRDeviceCheckProvider class]]);
#endif
}

@end
