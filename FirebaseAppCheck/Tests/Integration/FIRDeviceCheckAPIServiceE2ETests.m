/*
 * Copyright 2020 Google LLC
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

#import <TargetConditionals.h>

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// See go/firebase-macos-keychain-popups for more details.
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"

#import <FirebaseCore/FirebaseCore.h>

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@interface FIRDeviceCheckAPIServiceE2ETests : XCTestCase
@property(nonatomic) FIRDeviceCheckAPIService *deviceCheckAPIService;
@property(nonatomic) FIRAppCheckAPIService *APIService;
@property(nonatomic) NSURLSession *URLSession;
@end

// TODO(ncooke3): Fix these tests up and get them running on CI.

@implementation FIRDeviceCheckAPIServiceE2ETests

- (void)setUp {
  self.URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  FIROptions *options = [self firebaseTestOptions];
  FIRHeartbeatLogger *heartbeatLogger =
      [[FIRHeartbeatLogger alloc] initWithAppID:options.googleAppID];

  self.APIService = [[FIRAppCheckAPIService alloc] initWithURLSession:self.URLSession
                                                               APIKey:options.APIKey
                                                                appID:options.googleAppID
                                                      heartbeatLogger:heartbeatLogger];
  self.deviceCheckAPIService =
      [[FIRDeviceCheckAPIService alloc] initWithAPIService:self.APIService
                                                 projectID:options.projectID
                                                     appID:options.googleAppID];
}

- (void)tearDown {
  self.deviceCheckAPIService = nil;
  self.APIService = nil;
  self.URLSession = nil;
}

// TODO: Re-enable the test once secret with "GoogleService-Info.plist" is configured.
- (void)temporaryDisabled_testAppCheckTokenSuccess {
  __auto_type appCheckPromise =
      [self.deviceCheckAPIService appCheckTokenWithDeviceToken:[NSData data]];

  XCTAssert(FBLWaitForPromisesWithTimeout(20));

  XCTAssertNil(appCheckPromise.error);
  XCTAssertNotNil(appCheckPromise.value);

  XCTAssertNotNil(appCheckPromise.value.token);
  XCTAssertNotNil(appCheckPromise.value.expirationDate);
}

#pragma mark - Helpers

- (FIROptions *)firebaseTestOptions {
  NSString *plistPath =
      [[NSBundle bundleForClass:[self class]] pathForResource:@"GoogleService-Info"
                                                       ofType:@"plist"];
  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:plistPath];
  return options;
}

@end

#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#endif  // !SWIFT_PACKAGE
