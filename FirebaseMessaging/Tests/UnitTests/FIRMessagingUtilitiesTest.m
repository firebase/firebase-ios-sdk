/*
 * Copyright 2021 Google LLC
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

#import <OCMock/OCMock.h>
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

@interface FIRMessagingUtilitiesTest : XCTestCase

@property(nonatomic, strong) id mainBundleMock;

@end

@implementation FIRMessagingUtilitiesTest

- (void)setUp {
  _mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [super setUp];
}

- (void)tearDown {
  [_mainBundleMock stopMocking];
  [super tearDown];
}

- (void)testAPNSTupleStringReturnsNilIfDeviceTokenNil {
  NSString *tupleString = FIRMessagingAPNSTupleStringForTokenAndServerType(nil, NO);
  XCTAssertNil(tupleString);
}

- (void)testAPNSTupleStringReturnsValidData {
  NSData *deviceToken = [@"FAKE_DEVICE_TOKEN" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *expectedTokenString = FIRMessagingStringForAPNSDeviceToken(deviceToken);
  NSString *tupleString = FIRMessagingAPNSTupleStringForTokenAndServerType(deviceToken, NO);
  NSArray<NSString *> *components = [tupleString componentsSeparatedByString:@"_"];
  XCTAssertTrue(components.count == 2);
  XCTAssertEqualObjects(components.firstObject, @"p");
  XCTAssertEqualObjects(components.lastObject, expectedTokenString);
}

- (void)testAppVersionReturnsExpectedValue {
  NSString *expectedVersion = @"1.2.3";
  NSDictionary *fakeInfoDictionary = @{@"CFBundleShortVersionString" : expectedVersion};
  [[[_mainBundleMock stub] andReturn:fakeInfoDictionary] infoDictionary];
  NSString *appVersion = FIRMessagingCurrentAppVersion();
  XCTAssertEqualObjects(appVersion, expectedVersion);
}

- (void)testAppVersionReturnsEmptyStringWhenNotFound {
  NSDictionary *fakeInfoDictionary = @{};
  [[[_mainBundleMock stub] andReturn:fakeInfoDictionary] infoDictionary];
  NSString *appVersion = FIRMessagingCurrentAppVersion();
  XCTAssertEqualObjects(appVersion, @"");
}

- (void)testAppIdentifierReturnsExpectedValue {
#if TARGET_OS_WATCH
  NSString *bundleIdentifier = @"com.me.myapp.watchkit.watchkitextensions";
  NSString *expectedIdentifier = @"com.me.myapp.watchkit";
#else
  NSString *bundleIdentifier = @"com.me.myapp";
  NSString *expectedIdentifier = @"com.me.myapp";
#endif

  [[[_mainBundleMock stub] andReturn:bundleIdentifier] bundleIdentifier];
  NSString *appIdentifier = FIRMessagingAppIdentifier();
  XCTAssertEqualObjects(appIdentifier, expectedIdentifier);
}

- (void)testAppIdentifierReturnsEmptyStringWhenNotFound {
  [[[_mainBundleMock stub] andReturn:@""] bundleIdentifier];
  NSString *appIdentifier = FIRMessagingAppIdentifier();
  XCTAssertEqualObjects(appIdentifier, @"");
}

- (void)testLocaleHasChanged {
  NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
  XCTAssertTrue(FIRMessagingHasLocaleChanged());
  [[NSUserDefaults standardUserDefaults] setObject:FIRMessagingCurrentLocale()
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  XCTAssertFalse(FIRMessagingHasLocaleChanged());
  [[NSUserDefaults standardUserDefaults] setObject:@"zh-Hant"
                                            forKey:kFIRMessagingInstanceIDUserDefaultsKeyLocale];
  XCTAssertTrue(FIRMessagingHasLocaleChanged());
}

@end
