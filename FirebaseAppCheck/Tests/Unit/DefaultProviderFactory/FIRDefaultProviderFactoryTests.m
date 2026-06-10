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
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRRecaptchaProvider.h"

#import <OCMock/OCMock.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseAppCheck/Sources/RecaptchaProvider/FIRRecaptchaProvider+Internal.h"

FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY
@interface FIRDefaultProviderFactoryTests : XCTestCase
@end

@implementation FIRDefaultProviderFactoryTests

- (FIRApp *)mockAppWithRecaptchaSiteKey:(nullable NSString *)siteKey {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  if (siteKey) {
    options.recaptchaSiteKey = siteKey;
  }
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];
  app.dataCollectionDefaultEnabled = NO;
  return app;
}

- (void)testCreateProvider_Simulator {
#if TARGET_OS_SIMULATOR
  FIRApp *app = [self mockAppWithRecaptchaSiteKey:nil];
  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];

  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssert([provider isKindOfClass:[FIRAppCheckDebugProvider class]]);
#endif
}

- (void)testCreateProvider_Device_RecaptchaLinked {
#if ((TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION) && !TARGET_OS_SIMULATOR
  FIRApp *app = [self mockAppWithRecaptchaSiteKey:@"site_key"];

  id recaptchaMock = OCMClassMock([FIRRecaptchaProvider class]);
  OCMStub([recaptchaMock isSupported]).andReturn(YES);

  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];
  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssert([provider isKindOfClass:[FIRRecaptchaProvider class]]);

  [recaptchaMock stopMocking];
#endif
}

- (void)testCreateProvider_Device_RecaptchaNotLinked {
#if !TARGET_OS_SIMULATOR
  FIRApp *app = [self mockAppWithRecaptchaSiteKey:nil];

#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  id recaptchaMock = OCMClassMock([FIRRecaptchaProvider class]);
  OCMStub([recaptchaMock isSupported]).andReturn(NO);
#endif

  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];
  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
  XCTAssert([provider isKindOfClass:[FIRDeviceCheckProvider class]]);

#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  [recaptchaMock stopMocking];
#endif
#endif
}

- (void)testCreateProvider_Device_RecaptchaNotLinked_WithSiteKey_Throws {
#if ((TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION) && !TARGET_OS_SIMULATOR
  FIRApp *app = [self mockAppWithRecaptchaSiteKey:@"site_key"];

  id recaptchaMock = OCMClassMock([FIRRecaptchaProvider class]);
  OCMStub([recaptchaMock isSupported]).andReturn(NO);

  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];

  XCTAssertThrows([factory createProviderWithApp:app]);

  [recaptchaMock stopMocking];
#endif
}

- (void)testCreateProviderWithApp_PublicAPI {
  // Verifies that the public API doesn't crash and returns a provider.
  FIRApp *app = [self mockAppWithRecaptchaSiteKey:nil];

#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  id recaptchaMock = OCMClassMock([FIRRecaptchaProvider class]);
  OCMStub([recaptchaMock isSupported]).andReturn(NO);
#endif

  FIRDefaultProviderFactory *factory = [[FIRDefaultProviderFactory alloc] init];
  id<FIRAppCheckProvider> provider = [factory createProviderWithApp:app];

  XCTAssertNotNil(provider);
#if TARGET_OS_SIMULATOR
  XCTAssert([provider isKindOfClass:[FIRAppCheckDebugProvider class]]);
#else
  XCTAssert([provider isKindOfClass:[FIRDeviceCheckProvider class]]);
#endif

#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_VISION
  [recaptchaMock stopMocking];
#endif
}

@end
